/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
 * Copyright (C) 2015,2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 * Copyright (C) 2022 Mihai Moldovan <ionic@ionic.de>
 * Copyright (C) 2023-2025 Robert Tari
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
    public const string KEY_HIGH_CONTRAST_BACKGROUND_COLOR = "high-contrast-background-color";
    public const string KEY_BACKGROUND_MODE = "background-mode";
    public const string KEY_DRAW_USER_BACKGROUNDS = "draw-user-backgrounds";
    public const string KEY_DRAW_GRID = "draw-grid";
    public const string KEY_SHOW_HOSTNAME = "show-hostname";
    public const string KEY_SHOW_LOGIN_LABELS = "show-login-labels";
    public const string KEY_LOGO = "logo";
    public const string KEY_LOGO_ALPHA = "logo-alpha";
    public const string KEY_THEME_NAME = "theme-name";
    public const string KEY_HIGH_CONTRAST_THEME_NAME = "high-contrast-theme-name";
    public const string KEY_ICON_THEME_NAME = "icon-theme-name";
    public const string KEY_HIGH_CONTRAST_ICON_THEME_NAME = "high-contrast-icon-theme-name";
    public const string KEY_CURSOR_THEME_NAME = "cursor-theme-name";
    public const string KEY_CURSOR_THEME_SIZE = "cursor-theme-size";
    public const string KEY_FONT_NAME = "font-name";
    public const string KEY_WINDOW_MANAGER = "window-manager";
    public const string KEY_XFT_ANTIALIAS = "xft-antialias";
    public const string KEY_XFT_DPI = "xft-dpi";
    public const string KEY_XFT_HINTSTYLE = "xft-hintstyle";
    public const string KEY_XFT_RGBA = "xft-rgba";
    public const string KEY_ONSCREEN_KEYBOARD = "onscreen-keyboard";
    public const string KEY_ONSCREEN_KEYBOARD_LAYOUT = "onscreen-keyboard-layout";
    public const string KEY_ONSCREEN_KEYBOARD_THEME = "onscreen-keyboard-theme";
    public const string KEY_HIGH_CONTRAST_ONSCREEN_KEYBOARD_THEME = "high-contrast-onscreen-keyboard-theme";
    public const string KEY_HIGH_CONTRAST = "high-contrast";
    public const string KEY_SCREEN_READER = "screen-reader";
    public const string KEY_PLAY_READY_SOUND = "play-ready-sound";
    public const string KEY_INDICATORS = "indicators";
    public const string KEY_HIDDEN_USERS = "hidden-users";
    public const string KEY_HIDDEN_GROUPS = "hidden-groups";
    public const string KEY_USER_FILTER= "user-filter";
    public const string KEY_USER_FILTER_ALWAYS = "user-filter-always";
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
    public const string KEY_FONT_SCALING = "font-scaling";
    public const string KEY_WIDGET_SCALING = "widget-scaling";
    public const string KEY_MENUBAR_ALPHA = "menubar-alpha";
    public const string KEY_HIDE_DEFAULT_XSESSION = "hide-default-xsession";
    public const string KEY_HIDE_X11_SESSIONS = "hide-x11-sessions";
    public const string KEY_HIDE_WAYLAND_SESSIONS = "hide-wayland-sessions";
    public const string KEY_INCLUDEONLY_SESSIONS = "includeonly-sessions";
    public const string KEY_EXCLUDED_SESSIONS = "excluded-sessions";
    public const string KEY_SHUTDOWN_DIALOG_TIMEOUT = "shutdown-dialog-timeout";
    public const string KEY_PREFERRED_SESSIONS = "preferred-sessions";
    public const string KEY_GEOCLUE_AGENT = "geoclue-agent";
    public const string KEY_MAGNIFIER = "magnifier";
    public const string KEY_CONTENT_ALIGN = "content-align";
    public const string KEY_MAGNIFIER_POSITION = "magnifier-position";
    public const string KEY_DASHBOX_BGCOLOR = "dash-box-bgcolor";
    public const string KEY_DASHBOX_OPACITY = "dash-box-opacity";
    public const string KEY_PROMPTBOX_COLOR_NORMAL = "prompt-box-color-normal";
    public const string KEY_PROMPTBOX_COLOR_ERROR = "prompt-box-color-error";
    public const string KEY_PROMPTBOX_ERROR_BG_OPACITY = "prompt-box-error-bg-opacity";
    public const string KEY_LOGO_POSITION = "logo-position";
    public const string KEY_LOGO_OFFSET_HORIZONTAL = "logo-offset-horizontal";
    public const string KEY_LOGO_OFFSET_VERTICAL = "logo-offset-vertical";
    public const string KEY_ERROR_BELOW_ENTRY = "error-below-entry";
    public const string KEY_MENUBAR_BGCOLOR = "menubar-bgcolor";
    public const string KEY_BACKGROUND_POSITION = "background-position";

    public static bool get_boolean (string key)
    {
        var gsettings = new Settings (SCHEMA);
        return gsettings.get_boolean (key);
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
        /*
         * This function is currently empty, but we'll keep it around,
         * including this comment, because it's important to know what to do
         * with it if it's needed.
         *
         * Since AGSettings is a SingleInstance class, this function will only
         * be called once, as long as we make sure to create an instance early
         * in the program cycle and keep a reference to it for the rest of its
         * execution.
         *
         * In case you need to execute code once, whenever the first AGSettings
         * instance is created, do it here.
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
            var theme_name = "";
            var icon_theme_name = "";

            if (value)
            {

                /* FIXME: We need to check for wrong theme names here and handle such flaws gracefully */

                theme_name = AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_THEME_NAME);
                icon_theme_name = AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_ICON_THEME_NAME);
                debug ("Switching GTK Theme to high contrast theme \"%s\"", theme_name);
                debug ("Switching icon theme to high contrast theme \"%s\"", icon_theme_name);
            }
            else
            {

                /* FIXME: We need to check for wrong theme names here and handle such flaws gracefully */

                theme_name = AGSettings.get_string (AGSettings.KEY_THEME_NAME);
                icon_theme_name = AGSettings.get_string (AGSettings.KEY_ICON_THEME_NAME);
                debug ("Switching GTK Theme to default theme \"%s\"", theme_name);
                debug ("Switching icon theme to default icon theme \"%s\"", icon_theme_name);
            }
            settings.set ("gtk-theme-name", theme_name);
            settings.set ("gtk-icon-theme-name", icon_theme_name);
        }
    }

    private const string SCHEMA = "org.ArcticaProject.arctica-greeter";
    private bool high_contrast_ = AGSettings.get_boolean (AGSettings.KEY_HIGH_CONTRAST);
}
