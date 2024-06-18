# -*- Mode: m4; indent-tabs-mode: nil; tab-width: 4 -*-

dnl Process this file with autoconf to produce a configure script.

AC_INIT(arctica-greeter, 0.99.8.1)
AC_CONFIG_MACRO_DIR(m4)
AM_INIT_AUTOMAKE(subdir-objects)
AM_PROG_CC_C_O
AM_PROG_VALAC([0.24.0])
AM_CONFIG_HEADER(config.h)
AM_MAINTAINER_MODE
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES(yes)])

GLIB_GSETTINGS

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################


dnl #### removed from PKG_CHECK_MODULES: libido3-0.
PKG_CHECK_MODULES(ARCTICA_GREETER, [
    libayatana-ido3-0.4 >= 0.4.0
    ayatana-indicator3-0.4 >= 0.6.0
    liblightdm-gobject-1 >= 1.12.0
    freetype2
    cairo-ft
    libcanberra
    pixman-1
    x11
    xext
])

dnl GTK version selection.
AC_MSG_CHECKING([whether to enable GTK-4 support])
AC_ARG_ENABLE([gtk4],
              [AS_HELP_STRING([--enable-gtk4],
                              [Build against GTK-4 (experimental)])],
              [enable_gtk4=$enableval],
              [enable_gtk4=no])
AC_MSG_RESULT([$enable_gtk4])
with_gtk4=$enable_gtk4

AS_IF([test "x$enable_gtk4" != 'xno'],
      [PKG_CHECK_MODULES([GTK],
                         [gtk4 gtk4-x11],
                         [gtk4_modules=yes],
                         [gtk4_modules=no])
       AC_MSG_CHECKING([for GTK-4 libraries])
       AC_MSG_RESULT([$gtk4_modules])
       AS_IF([test "x$gtk4_modules" = 'xno'],
             [AC_MSG_ERROR([requested GTK-4, but not found])],
             [with_gtk4=yes
              AM_VALAFLAGS="$AM_VALAFLAGS -D HAVE_GTK_4_0"
              AC_SUBST([AM_VALAFLAGS])])])
AS_IF([test "x$with_gtk4" = 'xno'],
      [PKG_CHECK_MODULES([GTK],
                         [gtk+-3.0 gdk-x11-3.0],
                         [gtk3_modules=yes],
                         [gtk3_modules=no])
       AC_MSG_CHECKING([for GTK+ 3 libraries])
       AC_MSG_RESULT([$gtk3_modules])
       AS_IF([test "x$gtk3_modules" = 'xno'],
             [AC_MSG_ERROR([requested GTK+ 3, but not found])])])
AC_SUBST([GTK_CFLAGS])
AC_SUBST([GTK_LIBS])
AM_CONDITIONAL([HAVE_GTK4], [test "x$with_gtk4" != 'xno'])

AC_DEFINE_UNQUOTED([INDICATOR_FILE_DIR], ["${prefix}/share/ayatana/indicators"], [Indicator files are searched for in this directory])

INDICATORDIR=`$PKG_CONFIG --variable=indicatordir ayatana-indicator3-0.4`
AC_SUBST(INDICATORDIR)
AC_DEFINE_UNQUOTED([INDICATORDIR], ["$INDICATORDIR"], [Indicator plugins files are loaded from this directory])

if $PKG_CONFIG --exists mate-settings-daemon; then
    MSD_BINARY=`$PKG_CONFIG --variable=binary mate-settings-daemon`
    if test -z "$MSD_BINARY"; then
        AC_MSG_NOTICE([Could not find path to mate-settings-daemon binary])
    else
        SD_BINARY="$MSD_BINARY"
    fi

fi

if test -z "$SD_BINARY"; then
    AC_MSG_ERROR([Could not find any supported X11 settings daemon])
else
    AC_DEFINE_UNQUOTED([SD_BINARY], ["$SD_BINARY"], [Path to g-s-d])
fi

dnl customize path/name to/of lightdm-guest-session wrapper binary

#AC_ARG_VAR([GUEST_WRAPPER_BINARY],
#           [AC_HELP_STRING([GUEST_WRAPPER_BINARY=@<:@path-to-lightdm-guest-session@:>@],
#                           [Explicitly set full path to LightDM's lightdm-guest-session wrapper executable @<:@default=${libexecdir}/lightdm/lightdm-guest-session@:>@])]

AC_ARG_VAR([GUEST_WRAPPER_BINARY],
           [Explicitly set full path to LightDM's lightdm-guest-session wrapper executable @<:@default=${libexecdir}/lightdm/lightdm-guest-session@:>@]
)
if test -z "${GUEST_WRAPPER_BINARY}"; then
    GUEST_WRAPPER_BINARY="${libexecdir}/lightdm/lightdm-guest-session"
fi
AC_MSG_NOTICE([Using guest wrapper executable: ${GUEST_WRAPPER_BINARY}])
AC_SUBST(GUEST_WRAPPER_BINARY)

AC_CHECK_PROG(VALGRIND, valgrind, valgrind --trace-children=yes --num-callers=256)
AC_SUBST(VALGRIND)

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL(0.35.0)
GETTEXT_PACKAGE=arctica-greeter
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE, "$GETTEXT_PACKAGE", Gettext package)
AC_SUBST(GETTEXT_PACKAGE)

dnl ###########################################################################
dnl Check for GTK version - 3.20
dnl ###########################################################################

AS_IF([test "x$with_gtk4" != 'xno'],
      [AM_VALAFLAGS="$AM_VALAFLAGS -D HAVE_GTK_3_20_0"
       AC_SUBST([AM_VALAFLAGS])],
      [PKG_CHECK_MODULES([GTK_3_20_0], [gtk+-3.0 >= 3.20.0], [gtk_check_pass=yes], [gtk_check_pass=no])
       AS_IF([test "x$gtk_check_pass" = 'xyes'],
             [AM_VALAFLAGS="$AM_VALAFLAGS -D HAVE_GTK_3_20_0"
              AC_SUBST([AM_VALAFLAGS])])])

dnl ##########################################################################
dnl Remote Logon Dependencies
dnl ##########################################################################

AC_CHECK_HEADERS([security/pam-x2go.h],[],AC_MSG_ERROR([Could not find security/pam-x2go.h]))
AC_CHECK_HEADERS([security/pam-freerdp2.h],[],AC_MSG_ERROR([Could not find security/pam-freerdp2.h]))

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
data/Makefile
po/Makefile.in
src/Makefile
tests/Makefile
])
AC_OUTPUT

echo "

        arctica-greeter $VERSION
        =======================

        prefix:                     ${prefix}
        exec_prefix:                ${exec_prefix}
        libdir:                     ${libdir}
        libexecdir:                 ${libexecdir}
        bindir:                     ${bindir}
        sbindir:                    ${sbindir}
        datadir:                    ${datadir}
        sysconfdir:                 ${sysconfdir}
        localstatedir:              ${localstatedir}

        compiler:                   ${CC}
        cflags:                     ${CFLAGS}
        cppflags:                   ${CPPFLAGS}

        GTK-4 (experimental):       ${with_gtk4}

        GETTEXT_PACKAGE:            ${GETTEXT_PACKAGE}

        INDICATOR_FILE_DIR:         ${prefix}/share/ayatana/indicators
        INDICATORDIR:               ${INDICATORDIR}

        GUEST_WRAPPER_BINARY:       ${GUEST_WRAPPER_BINARY}

"
