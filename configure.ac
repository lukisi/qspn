AC_PREREQ([2.68])
AC_INIT([qspn],[0.1])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([subdir-objects] [1.11])
AM_SILENT_RULES([yes])

dnl This avoids dumb '-g -O2' autoconf's default, but won't 
dnl prevent user from setting a specific value for CFLAGS
: ${CFLAGS=""}

LT_INIT
AM_PROG_CC_C_O

dnl Check for vala
AM_PROG_VALAC([0.28.0])

AM_MAINTAINER_MODE([enable])

PKG_CHECK_MODULES([GOBJECT], [gobject-2.0 glib-2.0])
PKG_CHECK_MODULES([GEE], [gee-0.8])
PKG_CHECK_MODULES([JSONGLIB], [json-glib-1.0])
PKG_CHECK_MODULES([NTKDCOMMON], [ntkd-common])
PKG_CHECK_MODULES([TASKLETSYSTEM], [tasklet-system])
PKG_CHECK_MODULES([NTKDRPC], [ntkdrpc])
PKG_CHECK_MODULES([PTHTASKLET], [pth-tasklet])

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile test1.script test_split_signal.script test_not_split_signal.script])
AC_OUTPUT

