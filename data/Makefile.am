# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

50-arctica-greeter.conf: 50-arctica-greeter.conf.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

50-arctica-guest-wrapper.conf: 50-arctica-guest-wrapper.conf.in
	$(AM_V_GEN) sed -e "s|\@libexecdir\@|$(libexecdir)|" $< > $@

lightdm_confdir = $(datadir)/lightdm/lightdm.conf.d
lightdm_conf_DATA = \
	50-arctica-greeter.conf \
	50-arctica-guest-wrapper.conf

arctica-guest-session-startup.desktop: arctica-guest-session-startup.desktop.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

guestsession_autostartdir = $(datadir)/arctica-greeter/guest-session/skel/.config/autostart
guestsession_autostart_DATA = arctica-guest-session-startup.desktop

xgreeterdir = $(datarootdir)/xgreeters
dist_xgreeter_in_files = arctica-greeter.desktop.in
dist_xgreeter_DATA = $(dist_xgreeter_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

backgroundsdir = $(datarootdir)/backgrounds
dist_backgrounds_DATA = \
	arctica-greeter.png

soundsdir = $(datarootdir)/sounds/arctica-greeter
dist_sounds_DATA = \
	sounds/index.theme

soundsstereodir = $(datarootdir)/sounds/arctica-greeter/stereo
dist_soundsstereo_DATA = \
	sounds/stereo/system-ready.ogg

dist_pkgdata_DATA = \
	a11y.svg \
	active.png \
	arrow_left.png \
	arrow_right.png \
	awesome_badge.png \
	budgie_badge.png \
	cof.png \
	dialog_close.png \
	dialog_close_highlight.png \
	dialog_close_press.png \
	gnome_badge.png \
	gnustep_badge.png \
	hibernate_highlight.png \
	hibernate.png \
	i3_badge.png \
	kde_badge.png \
	logo.png \
	lxde_badge.png \
	matchbox_badge.png \
	mate_badge.png \
	message.png \
	openbox_badge.png \
	recovery_console_badge.png \
	remote_login_help.png \
	restart_highlight.png \
	restart.png \
	shadow.png \
	shutdown_highlight.png \
	shutdown.png \
	sugar_badge.png \
	surf_badge.png \
	suspend_highlight.png \
	suspend.png \
	switcher_corner.png \
	switcher_left.png \
	switcher_top.png \
	twm_badge.png \
	ubuntu_badge.png \
	unknown_badge.png \
	xfce_badge.png \
	xmonad_badge.png \
	xsession_badge.png

logo.png: logo-bare.png
	../src/logo-generator --logo logo-bare.png --text '$(VERSION)' --output logo.png

@GSETTINGS_RULES@
gsettings_SCHEMAS = \
	org.ArcticaProject.arctica-greeter.gschema.xml

dist_man1_MANS = arctica-greeter.1

EXTRA_DIST = \
	$(gsettings_SCHEMAS)

DISTCLEANFILES = \
	50-arctica-greeter.conf \
	50-arctica-guest-wrapper.conf \
	arctica-greeter.desktop \
	arctica-guest-session-startup.desktop \
	Makefile.in \
	logo.png
