require 'formula'

class Autoconf < Formula
  homepage 'http://www.gnu.org/software/autoconf'
  url 'http://ftpmirror.gnu.org/autoconf/autoconf-2.68.tar.gz'
  mirror 'http://ftp.gnu.org/gnu/autoconf/autoconf-2.68.tar.gz'
  sha1 '843f7dfcc6addf129dc2c8b12f7d72d371478f42'

  devel do
    url 'ftp://alpha.gnu.org/gnu/autoconf/autoconf-2.68b.tar.bz2'
    sha1 '8b6ca702e97ac51efa860cf959ca294ac4219856'
  end

  if MacOS.xcode_version.to_f < 4.3 or File.file? "/usr/bin/autoconf"
    keg_only "Xcode (up to and including 4.2) provides (a rather old) Autoconf."
  end

  def patches
    # force autoreconf to look for and use our glibtoolize
    DATA
  end

  def install
    system "./configure", "--prefix=#{prefix}"
    system "make"
    ENV.deparallelize
    system "make check"
    system "make install"
  end
end

__END__
--- a/bin/autoreconf.in
+++ b/bin/autoreconf.in
@@ -112,7 +112,7 @@ my $autoheader = $ENV{'AUTOHEADER'} || '@bindir@/@autoheader-name@';
 my $autom4te   = $ENV{'AUTOM4TE'}   || '@bindir@/@autom4te-name@';
 my $automake   = $ENV{'AUTOMAKE'}   || 'automake';
 my $aclocal    = $ENV{'ACLOCAL'}    || 'aclocal';
-my $libtoolize = $ENV{'LIBTOOLIZE'} || 'libtoolize';
+my $libtoolize = $ENV{'LIBTOOLIZE'} || 'glibtoolize';
 my $autopoint  = $ENV{'AUTOPOINT'}  || 'autopoint';
 my $make       = $ENV{'MAKE'}       || 'make';

--- a/lib/autoconf/fortran.m4
+++ b/lib/autoconf/fortran.m4
@@ -1599,7 +1599,8 @@ do
 	     [],
 	     [ac_cv_fc_check_bounds=$ac_flag; break])])])])
 done
-rm -f conftest$ac_exeext conftest.err conftest.$ac_objext conftest.$ac_ext
+rm -f conftest$ac_exeext conftest.err conftest.$ac_objext conftest.$ac_ext \
+  core *.core core.conftest.*
 FCFLAGS=$ac_fc_check_bounds_FCFLAGS_save
 ])
 if test "x$ac_cv_fc_check_bounds" = xunknown; then
--- a/lib/m4sugar/m4sh.m4
+++ b/lib/m4sugar/m4sh.m4
@@ -1199,6 +1199,10 @@ dnl Eggert wrote the scripts with optimization help from Paolo Bonzini).
   chmod +x "$as_me.lineno"] ||
     AS_ERROR([cannot create $as_me.lineno; rerun with a POSIX shell])
 
+  # If we had to re-execute with $CONFIG_SHELL, we're ensured to have
+  # already done that, so ensure we don't try to do so again and fall
+  # in an infinite loop.  This has already happened in practice.
+  _as_can_reexec=no; export _as_can_reexec
   # Don't try to exec as it changes $[0], causing all sort of problems
   # (the dirname of $[0] is not the place where we might find the
   # original and so on.  Autoconf is especially sensitive to this).
--- a/tests/m4sh.at
+++ b/tests/m4sh.at
@@ -49,6 +49,10 @@ echo foo > sentinel
 ]])
 AT_CHECK_M4SH
 
+# Calling the script simply 'script' could cause problems with
+# Solaris /usr/xpg4/bin/sh in the invocation 'sh script' below.
+mv -f script script2
+
 AT_DATA([fake-shell],
 [[#!/bin/sh
 echo 'Fake shell executed.'
@@ -61,7 +65,7 @@ done
 ]])
 chmod a+x fake-shell
 
-AT_CHECK([CONFIG_SHELL=./fake-shell ./script 1 2 4 8], [0],
+AT_CHECK([CONFIG_SHELL=./fake-shell ./script2 1 2 4 8], [0],
 [Fake shell executed.
 nargs = 4
  :1:
@@ -73,7 +77,7 @@ AT_CHECK([test ! -f sentinel], [0])
 test ! -f sentinel || rm -f sentinel # Cleanup for next test.
 
 AT_CHECK(
-[CONFIG_SHELL=`pwd`/fake-shell sh script a 'b  c' '  d	   e '],
+[CONFIG_SHELL=`pwd`/fake-shell sh script2 a 'b  c' '  d	   e '],
 [0],
 [Fake shell executed.
 nargs = 3
@@ -85,7 +89,7 @@ AT_CHECK([test ! -f sentinel], [0])
 test ! -f sentinel || rm -f sentinel # Cleanup for next test.
 
 AT_CHECK([(PATH=`pwd`:$PATH; export PATH;
-CONFIG_SHELL=fake-shell script '' '&' '!;*' '<($[]@%:@)>,' 'x
+CONFIG_SHELL=fake-shell script2 '' '&' '!;*' '<($[]@%:@)>,' 'x
 y  z
 1 2 3')], [0],
 [Fake shell executed.
@@ -120,7 +124,10 @@ exec sh "@S|@@"
 chmod a+x cfg-sh
 
 AT_CAPTURE_FILE([config.log])
-AT_CHECK([env CONFIG_SHELL=./cfg-sh ./configure], [0], [], [])
+# Export CONFIG_SITE to /dev/null to avoid spurious diffs in expected
+# stdout/stderr.
+AT_CHECK([env CONFIG_SITE=/dev/null CONFIG_SHELL=./cfg-sh ./configure],
+         [0], [], [])
 # ./configure re-executed itself.
 AT_CHECK([test -f cfg-sh-has-run], [0])
 # And did that not to cause extra execution of later commands.
@@ -569,7 +576,7 @@ else
   echo 1
 fi
 cat > foo.sh <<\EOF || AS_EXIT([1])
-#/bin/sh
+#!/bin/sh
 exit 0
 EOF
 # File systems like FAT tend to fake executable permissions on all files.
@@ -579,7 +586,7 @@ st1=$?
 (./foo.sh) >/dev/null 2>&1
 st2=$?
 case $st1:$st2 in
-  1:126 | 0:0 ) echo 2 ;;
+  *[[1-9]]*:*[[1-9]]* | 0:0 ) echo 2 ;;
   *) echo "fail ($st1:$st2)" ;;
 esac
 # Now things better be executable
@@ -1559,9 +1566,10 @@ A_B_C_P__
 
 dnl Check that of the last 6 macros, only 2 needed command substitution.
 dnl This test abuses our knowledge of m4sh internals a bit; oh well.
-AT_CHECK([sed -n '/start here/,$ {
+AT_CHECK([tab='	' # a single ASCII tab character
+sed -n '/start here/,$ {
 /`.*`/p
-}' script | wc -l], [], [[2
+}' script | wc -l | sed "s/[[ $tab]]//g" ], [], [[2
 ]])
 
 AT_CLEANUP
