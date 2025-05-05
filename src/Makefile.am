# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

bin_PROGRAMS = arctica-greeter
noinst_PROGRAMS = logo-generator

arctica_greeter_SOURCES = \
	config.vapi \
	fixes.vapi \
	indicator.vapi \
	pam_freerdp2.vapi \
	pam_x2go.vapi \
	xsync.vapi \
	animate-timer.vala \
	background.vala \
	cached-image.vala \
	cairo-utils.vala \
	email-autocompleter.vala \
	dash-box.vala \
	dash-button.vala \
	dash-entry.vala \
	fadable.vala \
	fadable-box.vala \
	fading-label.vala \
	flat-button.vala \
	greeter-list.vala \
	idle-monitor.vala \
	list-stack.vala \
	main-window.vala \
	menu.vala \
	menubar.vala \
	prompt-box.vala \
	session-list.vala \
	remote-logon-service.vala \
	settings.vala \
	settings-daemon.vala \
	shutdown-dialog.vala \
	toggle-box.vala \
	arctica-greeter.vala \
	user-list.vala \
	user-prompt-box.vala \
	util.vala

logo_generator_SOURCES = logo-generator.vala

arctica_greeter_CFLAGS = \
	$(ARCTICA_GREETER_CFLAGS) \
	$(GTK_CFLAGS) \
	-w \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DLOCALEDIR=\"$(localedir)\" \
	-DVERSION=\"$(VERSION)\" \
	-DPKGDATADIR=\"$(pkgdatadir)\" \
	-DPKGLIBEXECDIR=\"$(pkglibexecdir)\" \
	-DINDICATORDIR=\"$(INDICATORDIR)\"

logo_generator_CFLAGS = $(arctica_greeter_CFLAGS)

arctica_greeter_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	--debug \
	--pkg posix \
	$(NULL)

if HAVE_GTK4
arctica_greeter_VALAFLAGS += \
	--pkg gtk4 \
	--pkg gtk4-x11 \
	$(NULL)
else
arctica_greeter_VALAFLAGS += \
	--pkg gtk+-3.0 \
	--pkg gdk-x11-3.0 \
	$(NULL)
endif

arctica_greeter_VALAFLAGS += \
	--pkg gio-unix-2.0 \
	--pkg x11 \
	--pkg liblightdm-gobject-1 \
	--pkg libcanberra \
	--pkg gio-2.0 \
	--pkg pixman-1 \
	--target-glib 2.32

logo_generator_VALAFLAGS = $(arctica_greeter_VALAFLAGS)

arctica_greeter_LDADD = \
	$(ARCTICA_GREETER_LIBS) \
	$(GTK_LIBS) \
	-lm

logo_generator_LDADD = $(arctica_greeter_LDADD)

DISTCLEANFILES = \
	Makefile.in
