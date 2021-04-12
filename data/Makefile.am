# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

50-arctica-greeter.conf: 50-arctica-greeter.conf.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

50-arctica-greeter-guest-wrapper.conf: 50-arctica-greeter-guest-wrapper.conf.in
	$(AM_V_GEN) sed -e "s|\@GUEST_WRAPPER_BINARY\@|$(GUEST_WRAPPER_BINARY)|" $< > $@

lightdm_confdir = $(datadir)/lightdm/lightdm.conf.d
lightdm_conf_DATA = \
	50-arctica-greeter.conf \
	50-arctica-greeter-guest-wrapper.conf

arctica-greeter-guest-session-startup.desktop: arctica-greeter-guest-session-startup.desktop.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

guestsession_autostartdir = $(datadir)/arctica-greeter/guest-session/skel/.config/autostart
guestsession_autostart_DATA = arctica-greeter-guest-session-startup.desktop

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
	badges/awesome_badge.png \
	badges/budgie_badge.png \
	badges/gnome_badge.png \
	badges/gnustep_badge.png \
	badges/i3_badge.png \
	badges/kde_badge.png \
	badges/lxde_badge.png \
	badges/matchbox_badge.png \
	badges/mate_badge.png \
	badges/openbox_badge.png \
	badges/remote_login_help.png \
	badges/recovery_console_badge.png \
	badges/sugar_badge.png \
	badges/surf_badge.png \
	badges/twm_badge.png \
	badges/ubuntu_badge.png \
	badges/unknown_badge.png \
	badges/xfce_badge.png \
	badges/xmonad_badge.png \
	badges/xsession_badge.png \
	a11y.svg \
	active.png \
	arrow_left.png \
	arrow_right.png \
	dialog_close.png \
	dialog_close_highlight.png \
	dialog_close_press.png \
	hibernate_highlight.png \
	hibernate.png \
	logo.png \
	message.png \
	restart_highlight.png \
	restart.png \
	shadow.png \
	shutdown_highlight.png \
	shutdown.png \
	suspend_highlight.png \
	suspend.png \
	switcher_corner.png \
	switcher_left.png \
	switcher_top.png

logo.png: logo-bare.png
	../src/logo-generator --logo logo-bare.png --text '$(VERSION)' --output logo.png

@GSETTINGS_RULES@
gsettings_SCHEMAS = \
	org.ArcticaProject.arctica-greeter.gschema.xml

dist_man1_MANS = arctica-greeter.1
dist_man8_MANS = arctica-greeter-guest-account-script.8

EXTRA_DIST = \
	$(gsettings_SCHEMAS)

DISTCLEANFILES = \
	50-arctica-greeter.conf \
	50-arctica-greeter-guest-wrapper.conf \
	arctica-greeter.desktop \
	arctica-greeter-guest-session-startup.desktop \
	Makefile.in \
	logo.png
