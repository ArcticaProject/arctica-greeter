/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
 * Copyright (C) 2015,2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 * Copyright (C) 2022 Mihai Moldovan <ionic@ionic.de>
 * Copyright (C) 2023 Robert Tari
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Robert Ancell <robert.ancell@canonical.com>
 *          Michael Terry <michael.terry@canonical.com>
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 *          Robert Tari <robert@tari.in>
 */

[SingleInstance]
public class AGSettings : Object
{
    public const string KEY_BACKGROUND = "background";
    public const string KEY_BACKGROUND_COLOR = "background-color";
    public const string KEY_BACKGROUND_MODE = "background-mode";
    public const string KEY_DRAW_USER_BACKGROUNDS = "draw-user-backgrounds";
    public const string KEY_DRAW_GRID = "draw-grid";
    public const string KEY_SHOW_HOSTNAME = "show-hostname";
    public const string KEY_LOGO = "logo";
    public const string KEY_LOGO_ALPHA = "logo-alpha";
    public const string KEY_THEME_NAME = "theme-name";
    public const string KEY_HIGH_CONTRAST_THEME_NAME = "high-contrast-theme-name";
    public const string KEY_ICON_THEME_NAME = "icon-theme-name";
    public const string KEY_CURSOR_THEME_NAME = "cursor-theme-name";
    public const string KEY_CURSOR_THEME_SIZE = "cursor-theme-size";
    public const string KEY_FONT_NAME = "font-name";
    public const string KEY_XFT_ANTIALIAS = "xft-antialias";
    public const string KEY_XFT_DPI = "xft-dpi";
    public const string KEY_XFT_HINTSTYLE = "xft-hintstyle";
    public const string KEY_XFT_RGBA = "xft-rgba";
    public const string KEY_ONSCREEN_KEYBOARD = "onscreen-keyboard";
    public const string KEY_ONSCREEN_KEYBOARD_LAYOUT = "onscreen-keyboard-layout";
    public const string KEY_ONSCREEN_KEYBOARD_THEME = "onscreen-keyboard-theme";
    public const string KEY_HIGH_CONTRAST = "high-contrast";
    public const string KEY_BIG_FONT = "big-font";
    public const string KEY_SCREEN_READER = "screen-reader";
    public const string KEY_PLAY_READY_SOUND = "play-ready-sound";
    public const string KEY_INDICATORS = "indicators";
    public const string KEY_HIDDEN_USERS = "hidden-users";
    public const string KEY_GROUP_FILTER = "group-filter";
    public const string KEY_IDLE_TIMEOUT = "idle-timeout";
    public const string KEY_ACTIVATE_NUMLOCK = "activate-numlock";
    public const string KEY_ONLY_ON_MONITOR = "only-on-monitor";
    public const string KEY_REMOTE_SERVICE_CONFIGURE_URI = "remote-service-configure-uri";
    public const string KEY_TOGGLEBOX_FONT_FGCOLOR = "togglebox-font-fgcolor";
    public const string KEY_TOGGLEBOX_FONT_FGCOLOR_ACTIVE = "togglebox-font-fgcolor-active";
    public const string KEY_TOGGLEBOX_FONT_FGCOLOR_SELECTED = "togglebox-font-fgcolor-selected";
    public const string KEY_TOGGLEBOX_BUTTON_BGCOLOR = "togglebox-button-bgcolor";
    public const string KEY_TOGGLEBOX_BUTTON_BGCOLOR_ACTIVE = "togglebox-button-bgcolor-active";
    public const string KEY_TOGGLEBOX_BUTTON_BGCOLOR_SELECTED = "togglebox-button-bgcolor-selected";
    public const string KEY_TOGGLEBOX_BUTTON_BORDERCOLOR = "togglebox-button-bordercolor";
    public const string KEY_TOGGLEBOX_BUTTON_BORDERCOLOR_ACTIVE = "togglebox-button-bordercolor-active";
    public const string KEY_TOGGLEBOX_BUTTON_BORDERCOLOR_SELECTED = "togglebox-button-bgcolor-selected";
    public const string KEY_FLATBUTTON_BGCOLOR = "flatbutton-bgcolor";
    public const string KEY_FLATBUTTON_BORDERCOLOR = "flatbutton-bordercolor";
    public const string KEY_ENABLE_HIDPI = "enable-hidpi";
    public const string KEY_MENUBAR_ALPHA = "menubar-alpha";
    public const string KEY_HIDE_X11_SESSIONS = "hide-x11-sessions";
    public const string KEY_HIDE_WAYLAND_SESSIONS = "hide-wayland-sessions";
    public const string KEY_SHUTDOWN_DIALOG_TIMEOUT = "shutdown-dialog-timeout";
    public const string KEY_PREFERRED_SESSIONS = "preferred-sessions";

    public static bool get_boolean (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_boolean (key);
    }

    /* LP: 1006497 - utility function to make sure we have the key before trying to read it (which will segfault if the key isn't there) */
    public static bool safe_get_boolean (string key, bool default)
    {
        var gsettings = new Settings (SCHEMA);
        string[] keys = gsettings.list_keys ();
        foreach (var k in keys)
            if (k == key)
                return gsettings.get_boolean (key);

        /* key not in child list */
        return default;
    }

    public static int get_integer (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_int (key);
    }

    public static double get_double (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_double (key);
    }

    public static string get_string (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_string (key);
    }

    public static bool set_boolean (string key, bool value)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.set_boolean (key, value);
    }

    public static string[] get_strv (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_strv (key);
    }

    public static bool set_strv (string key, string[] value)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.set_strv (key, value);
    }

    public AGSettings ()
    {
    }

    construct {
        Gtk.Settings.get_default ().get ("gtk-theme-name", out this.default_theme_name_);
        /*
        debug ("Fetched default theme name in construct: %s", this.default_theme_name_);
        */
    }

    public bool high_contrast {
        get {
            return this.high_contrast_;
        }

        set {
            debug ("Called high contrast setter with value %s", value.to_string ());
            this.high_contrast_ = value;

            /* Also sync back to dconf, so that this state is persistent. */
            set_boolean (AGSettings.KEY_HIGH_CONTRAST, value);

            var greeter = new ArcticaGreeter ();
            greeter.switch_contrast (value);

            var settings = Gtk.Settings.get_default ();
            if (value)
            {
                /*
                debug ("Switching GTK Theme to high contrast theme \"%s\"", AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_THEME_NAME));
                */
                settings.set ("gtk-theme-name", AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_THEME_NAME));
            }
            else
            {
                /*
                debug ("Switching GTK Theme to default theme \"%s\"", this.default_theme_name_);
                */
                settings.set ("gtk-theme-name", this.default_theme_name_);
            }
        }
    }

    public bool big_font {
        get {
            return this.big_font_;
        }

        set {
            this.big_font_ = value;

            /* Also sync back to dconf, so that this state is persistent. */
            set_boolean (AGSettings.KEY_BIG_FONT, value);

            var greeter = new ArcticaGreeter ();
            greeter.switch_font (value);
        }
    }

    private const string SCHEMA = "org.ArcticaProject.arctica-greeter";
    private bool high_contrast_ = AGSettings.get_boolean (AGSettings.KEY_HIGH_CONTRAST);
    private bool big_font_ = AGSettings.get_boolean (AGSettings.KEY_BIG_FONT);
    private string default_theme_name_;
}
