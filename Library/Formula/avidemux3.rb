require 'formula'

class Avidemux3 < Formula
  homepage 'http://developer.berlios.de/projects/avidemux/'
  url 'http://downloads.sourceforge.net/avidemux/avidemux_2.6.0.tar.gz'
  sha1 'd886d61eab70f7b1972c0ebdeeeb7d2ba8c30cbf'

  head 'git://gitorious.org/avidemux2-6/avidemux2-6.git'

  depends_on 'pkg-config'   => :build
  depends_on 'cmake'        => :build
  depends_on 'yasm'         => :build
  depends_on 'qt'           => :build
  depends_on 'aften'        => :recommended
  depends_on 'faac'         => :recommended
  depends_on 'faad2'        => :recommended
  depends_on 'fribidi'      => :recommended
  depends_on 'gettext'      => :recommended
  depends_on 'libdca'       => :recommended
  depends_on 'libvorbis'    => :recommended
  depends_on 'libvpx'       => :optional
  depends_on 'lame'         => :recommended
  depends_on 'opencore-amr' => :optional
  depends_on 'sqlite'       => :recommended
  depends_on 'two-lame'     => :recommended
  depends_on 'xvid'         => :recommended
  depends_on 'x264'         => :recommended

  option 'with-debug', 'Enable debug build and disable optimization'

  def process(blddir, srcdir, dflag)
    gettext = Formula.factory('gettext')
    mkdir blddir do
      args = std_cmake_args + %W[
          -DCMAKE_PREFIX_PATH=#{gettext.prefix}
          -DAVIDEMUX_SOURCE_DIR=#{buildpath}
        ]
      if build.include? 'with-debug' then
        args << '-DCMAKE_BUILD_TYPE=Debug'
        args << '-DCMAKE_VERBOSE_MAKEFILE=true'
        args << '-DCMAKE_C_FLAGS_DEBUG=-ggdb3' unless ENV.compiler == :clang
        args << '-DCMAKE_CXX_FLAGS_DEBUG=-ggdb3' unless ENV.compiler == :clang
      end
      args << dflag if dflag != ''
      args << srcdir
      system "cmake", *args
      if blddir == 'buildCor' then
        system 'make -j1'             # their internal ffmpeg needs this
        system 'make -j1 install'
      else
        system 'make'
        system 'make install'
      end
    end
  end



  def install
    ENV.remove_from_cflags '-w '                       # allow warnings for now.
    if build.include? 'with-debug'
      ENV.deparallelize                                # helps reading stdout.
      (ENV.compiler == :clang) ? ENV.Og : ENV.O2       # optimize debug properly
    end
    # Avidemux is coded to use the .svn or .git directory to find its revision,
    # but neither vcs copies those during clone from the cache to the stagedir.
    # Modify cmake/admMainChecks.cmake to look in the Homebrew cache.
    if build.head?
      inreplace 'cmake/admMainChecks.cmake',
        'admGetRevision( ${AVIDEMUX_TOP_SOURCE_DIR} ADM_SUBVERSION)',
        "admGetRevision(\"#{cached_download}\" ADM_SUBVERSION)"
    end

    # (build directory, source location, cmake variable)
    process( 'buildCor', '../avidemux_core', '-DSDL=OFF' )
    process( 'buildGui', '../avidemux/qt4',  '-DSDL=OFF' )
    process( 'buildCli', '../avidemux/cli',  '-DSDL=OFF' )
    process( 'buildPlugCor', '../avidemux_plugins', '-DPLUGIN_UI=COMMON' )
    process( 'buildPlugGui', '../avidemux_plugins', '-DPLUGIN_UI=QT4' )
    process( 'buildPlugCli', '../avidemux_plugins', '-DPLUGIN_UI=CLI' )


    # g++ links the core applications against unversioned dylibs
    # from an internal ffmpeg, even though CMake specifies versioned
    # dylibs. CMake then installs the versioned ffmpeg dylibs only.
    # This patch creates the missing symlinks for unversioned libs.
    #   * The lib version numbers are either one or two digits.
    #   * The version numbers change every couple of months.
    #   * So this finds the file first, then makes a symlink.
    #   * The result of this code is a command like this:
    #       ln_sf lib+'libADM6avcodec.53.dylib', lib+'libADM6avcodec.dylib'

    ffpref = 'libADM6'
    ffsuff = '.dylib'
    %w[ avcodec avformat avutil postproc swscale ].each do |fflib|
      ffpat = ffpref+fflib+'.{?,??}'+ffsuff
      ffpat = lib+ffpat
      nonver = ffpref+fflib+ffsuff
      nonver = lib+nonver
      hasver = Dir[ffpat]
      ln_sf hasver.to_s, nonver.to_s
    end
  end

  def caveats
    <<-EOS.undent
      The command line interface is called avidemux_cli.
      The Qt gui is called avidemux, but no formal app is created in /Applications.
      You would start it here in a terminal if you decide to run that.
      All the programs are in your path by default.
    EOS
  end
end
