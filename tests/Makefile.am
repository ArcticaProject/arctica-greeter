# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

check_PROGRAMS = arctica-greeter-test

check: arctica-greeter-test
	UBUNTU_MENUPROXY=0 top_srcdir=$(top_srcdir) @VALGRIND@ xvfb-run -s "-extension GLX" -a ./arctica-greeter-test

arctica_greeter_test_SOURCES = \
	test.vala \
	test-list.vala \
	test-main-window.vala \
	menubar.vala \
	arctica-greeter.vala \
	../src/flat-button.vala \
	../src/toggle-box.vala \
	../src/user-list.vala \
	../src/greeter-list.vala \
	../src/remote-logon-service.vala \
	../src/background.vala \
	../src/email-autocompleter.vala \
	../src/config.vapi \
	../src/fixes.vapi \
	../src/cairo-utils.vala \
	../src/animate-timer.vala \
	../src/indicator.vapi \
	../src/fadable.vala \
	../src/fadable-box.vala \
	../src/dash-box.vala \
	../src/user-prompt-box.vala \
	../src/fading-label.vala \
	../src/cached-image.vala \
	../src/dash-entry.vala \
	../src/dash-button.vala \
	../src/prompt-box.vala \
	../src/session-list.vala \
	../src/main-window.vala \
	../src/list-stack.vala \
	../src/settings.vala \
	../src/shutdown-dialog.vala


arctica_greeter_test_CFLAGS = \
	$(ARCTICA_GREETER_CFLAGS) \
	$(GTK_CFLAGS) \
	-w \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DLOCALEDIR=\""$(localedir)"\" \
	-DVERSION=\"$(VERSION)\" \
	-DCONFIG_FILE=\""$(sysconfdir)/lightdm/arctica-greeter.conf"\" \
	-DPKGDATADIR=\""$(pkgdatadir)"\" \
	-DINDICATORDIR=\""$(INDICATORDIR)"\"

arctica_greeter_test_VALAFLAGS = \
	--debug \
	--pkg posix \
	$(NULL)

if HAVE_GTK4
arctica_greeter_test_VALAFLAGS += \
	--pkg gtk4 \
	--pkg gtk4-x11 \
	$(NULL)
else
arctica_greeter_test_VALAFLAGS += \
	--pkg gtk+-3.0 \
	--pkg gdk-x11-3.0 \
	$(NULL)
endif

arctica_greeter_test_VALAFLAGS += \
	--pkg gio-unix-2.0 \
	--pkg x11 \
	--pkg liblightdm-gobject-1 \
	--pkg libcanberra \
	--pkg gio-2.0 \
	--pkg pixman-1 \
	--target-glib 2.32

arctica_greeter_test_LDADD = \
	$(ARCTICA_GREETER_LIBS) \
	$(GTK_LIBS) \
	-lm

CLEANFILES = \
	$(notdir $(arctica_greeter_test_SOURCES:.vala=.c))

DISTCLEANFILES = \
	Makefile.in
