# -*- Mode: Automake; indent-tabs-mode: t; tab-width: 4 -*-

NULL =

50-arctica-greeter.conf: 50-arctica-greeter.conf.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

50-arctica-greeter-guest-wrapper.conf: 50-arctica-greeter-guest-wrapper.conf.in
	$(AM_V_GEN) sed -e "s|\@GUEST_WRAPPER_BINARY\@|$(GUEST_WRAPPER_BINARY)|" $< > $@

lightdm_confdir = $(datadir)/lightdm/lightdm.conf.d
lightdm_conf_DATA = \
	50-arctica-greeter.conf \
	50-arctica-greeter-guest-wrapper.conf \
	$(NULL)

lightdm_sysconfdir = $(sysconfdir)/lightdm/lightdm.conf.d
lightdm_sysconf_DATA = \
	90-arctica-greeter.conf \
	91-arctica-greeter-guest-session.conf \
	92-arctica-greeter-remote-logon.conf \
	$(NULL)

pkla_policydir = $(localstatedir)/lib/polkit-1/localauthority/10-vendor.d
pkla_policy_DATA = \
	arctica-greeter.pkla \
	$(NULL)

rules_policydir = $(datadir)/polkit-1/rules.d/
rules_policy_DATA = \
	50-org.Arctica-Project.arctica-greeter.rules \
	$(NULL)

arctica-greeter-guest-session-startup.desktop: arctica-greeter-guest-session-startup.desktop.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

guestsession_autostartdir = $(datadir)/arctica-greeter/guest-session/skel/.config/autostart
guestsession_autostart_DATA = arctica-greeter-guest-session-startup.desktop

arctica-greeter.desktop.in: arctica-greeter.desktop.in.in
	$(AM_V_GEN) sed -e "s|\@pkglibexecdir\@|$(pkglibexecdir)|" $< > $@

xgreeterdir = $(datarootdir)/xgreeters
dist_xgreeter_in_files = arctica-greeter.desktop.in
dist_xgreeter_DATA = $(dist_xgreeter_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

backgroundsdir = $(datarootdir)/arctica-greeter/backgrounds
dist_backgrounds_DATA = \
	backgrounds/arctica-greeter.png

soundsdir = $(datarootdir)/sounds/arctica-greeter
dist_sounds_DATA = \
	sounds/index.theme

soundsstereodir = $(datarootdir)/sounds/arctica-greeter/stereo
dist_soundsstereo_DATA = \
	sounds/stereo/system-ready.ogg

dist_pkgdata_DATA = \
	badges/aewm++_badge.png \
	badges/afterstep_badge.png \
	badges/amiwm_badge.png \
	badges/awesome_badge.png \
	badges/blackbox_badge.png \
	badges/budgie_badge.png \
	badges/cairo-dock_badge.png \
	badges/cde_badge.svg \
	badges/chromium_badge.svg \
	badges/cinnamon_badge.svg \
	badges/deepin_badge.png \
	badges/dwm_badge.svg \
	badges/ede_badge.png \
	badges/enlightenment_badge.svg \
	badges/etoile_badge.svg \
	badges/evilwm_badge.png \
	badges/fluxbox_badge.svg \
	badges/fvwm_badge.png \
	badges/fynedesk_badge.svg \
	badges/gnome_badge.png \
	badges/gnome-bluetile_badge.svg \
	badges/gnustep_badge.png \
	badges/herbstluftwm_badge.png \
	badges/i3_badge.png \
	badges/icewm_badge.png \
	badges/kde_badge.png \
	badges/larswm_badge.png \
	badges/lomiri_badge.png \
	badges/lxde_badge.png \
	badges/lxqt_badge.png \
	badges/matchbox_badge.png \
	badges/mate_badge.png \
	badges/mirshell_badge.png \
	badges/mythbuntu_badge.png \
	badges/openbox_badge.png \
	badges/openbsd-cwm_badge.png \
	badges/pademelon_badge.png \
	badges/pantheon_badge.png \
	badges/pekwm_badge.png \
	badges/ratpoison_badge.png \
	badges/razor_badge.png \
	badges/recovery_console_badge.png \
	badges/remote_login_help.png \
	badges/sawfish_badge.png \
	badges/sleclassic_badge.png \
	badges/steamos_badge.svg \
	badges/stumpwm_badge.png \
	badges/subtle_badge.png \
	badges/sugar_badge.png \
	badges/surf_badge.png \
	badges/sway_badge.svg \
	badges/trinity_badge.png \
	badges/twm_badge.png \
	badges/ubuntu_badge.png \
	badges/ubuntustudio_badge.svg \
	badges/unknown_badge.png \
	badges/weston_badge.png \
	badges/wmii_badge.png \
	badges/xbmc_badge.png \
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
	switcher_top.png \
	$(NULL)

logo.png: logo-bare.png
	../src/logo-generator --logo logo-bare.png --text '$(VERSION)' --output logo.png

@GSETTINGS_RULES@
gsettings_SCHEMAS = \
	org.ArcticaProject.arctica-greeter.gschema.xml

dist_man1_MANS = \
	arctica-greeter.1 \
	arctica-greeter-check-hidpi.1 \
	arctica-greeter-enable-tap-to-click.1 \
	arctica-greeter-magnifier.1 \
	arctica-greeter-set-keyboard-layout.1 \
	$(NULL)

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
