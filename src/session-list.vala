/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2012 Canonical Ltd
 * Copyright (C) 2015-2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
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
 * Authors: Michael Terry <michael.terry@canonical.com>
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 */

public class SessionPrompt : PromptBox
{
    public string session { get; construct; }
    public string default_session { get; construct; }

    public SessionPrompt (string id, string? session, string? default_session)
    {
        Object (id: id, session: session, default_session: default_session);
    }

    private ToggleBox box;

    construct
    {
        label = _("Select desktop environment");
        name_label.vexpand = false;

        box = new ToggleBox (default_session, session);

        var greeter = new ArcticaGreeter ();
        if (greeter.test_mode)
        {
            box.add_item ("gnome", "GNOME", SessionList.get_badge ("gnome"));
            box.add_item ("kde", "KDE", SessionList.get_badge ("kde"));
            box.add_item ("ubuntu", "Ubuntu", SessionList.get_badge ("ubuntu"));
        }
        else
        {
            /* Pick the selected session (if any) and add it as first item.
             */
            var dm_sessions = LightDM.get_sessions().copy();
            foreach (var dm_session in dm_sessions)
            {
                if (dm_session.key == session) {
                    debug ("Adding session %s (%s) as first entry", dm_session.key, dm_session.name);
                    box.add_item (dm_session.key, dm_session.name, SessionList.get_badge (dm_session.key));
                    break;
                }
            }
            /* Pick the default session (if different from selected session) and add it as next item.
             */
            if (session != default_session) {
                foreach (var dm_session in dm_sessions)
                {
                    if (dm_session.key == default_session) {
                        debug ("Adding session %s (%s) as second entry", dm_session.key, dm_session.name);
                        box.add_item (dm_session.key, dm_session.name, SessionList.get_badge (dm_session.key));
                        break;
                    }
                }
            }

            dm_sessions.sort_with_data((a, b) => GLib.strcmp (a.name.casefold().collate_key(), b.name.casefold().collate_key()));
            foreach (var dm_session in dm_sessions)
            {
                /* Skip the selected session, we already have added that as first time.
                 */
                if (dm_session.key == session) {
                    continue;
                }

                /* Skip the default session, we already have added that as first or second item
                   (depending on whether there was a selected session).
                 */
                if (dm_session.key == default_session) {
                    continue;
                }

                /* Apply hide x11/wayland filter */
                if (greeter.validate_session(dm_session.key, false) != null) {
                    debug ("Adding session %s (%s)", dm_session.key, dm_session.name);
                    box.add_item (dm_session.key, dm_session.name, SessionList.get_badge (dm_session.key));
                }
            }
        }

        box.notify["selected-key"].connect (selected_cb);
        box.show ();

        attach_item (box);
    }

    private void selected_cb ()
    {
        respond ({ box.selected_key });
    }
}

public class SessionList : GreeterList
{
    public signal void session_clicked (string session);
    public string session { get; construct; }
    public string default_session { get; construct; }

    private SessionPrompt prompt;

    private const int BADGE_SIZE = 22;

    public SessionList (Background bg, MenuBar mb, string? session, string? default_session)
    {
        Object (background: bg, menubar: mb, session: session, default_session: default_session);
    }

    construct
    {
        prompt = add_session_prompt ("session");
    }

    private SessionPrompt add_session_prompt (string id)
    {
        var e = new SessionPrompt (id, session, default_session);
        e.respond.connect ((responses) => { session_clicked (responses[0]); });
        add_entry (e);
        return e;
    }

    protected override void add_manual_entry () {}
    public override void show_authenticated (bool successful = true) {}

    private static string? get_badge_name_from_alias_list (string session)
    {
        /*
         * Only list aliases here, if the badge name can be derived from <session>
         * via <session>_badge.(svg|png) then the badge file is found automatically.
         */
        switch (session)
        {
        case "budgie-desktop":
            return "budgie_badge.png";
        case "cairo-dock-fallback":
        case "cairo-dock-unity":
            return "cairo-dock_badge.svg";
        case "cinnamon-wayland":
        case "cinnamon2d":
            return "cinnamon_badge.svg";
        case "fvwm-crystal":
        case "fvwm1":
            return "fvwm_badge.png";
        case "gnome-classic":
        case "gnome-classic-xorg":
        case "gnome-classic-wayland":
        case "gnome-flashback-compiz":
        case "gnome-flashback-metacity":
        case "gnome-shell":
        case "gnome-wayland":
        case "gnome-xorg":
        case "openbox-gnome":
            return "gnome_badge.png";
        case "wmaker-common":
            return "gnustep_badge.png";
        case "IceWM-Experimental":
        case "IceWM-Lite":
        case "IceWM":
        case "icewm-session":
            return "icewm_badge.png";
        case "kde-plasma":
        case "openbox-kde":
        case "plasma":
        case "plasma5":
        case "plasmawayland":
            return "kde_badge.png";
        case "i3-with-shmlog":
            return "i3_badge.png";
        case "default":
        case "lightdm-xsession":
            return "xsession_badge.png";
        case "LXDE":
        case "lubuntu-nexus7":
        case "lxgames":
        case "Lubuntu":
        case "Lubuntu-Netbook":
        case "QLubuntu":
            return "lxde_badge.png";
        case "LXQt":
            return "lxqt_badge.png";
        case "mir-shell":
            return "mirshell_badge.png";
        case "sle-classic":
            return "sleclassic_badge.png";
        case "sugar-session-0.84":
        case "sugar-session-0.86":
        case "sugar-session-0.88":
        case "sugar-session-0.90":
        case "sugar-session-0.96":
        case "sugar-session-0.98":
        case "usr":
            return "sugar_badge.png";
        case "surf-display":
            return "surf_badge.png";
        case "ubuntu-2d":
        case "ubuntu-xorg":
        case "unity":
            return "ubuntu_badge.png";
        case "XBMC":
            return "xbmc_badge.png";
        case "xubuntu":
            return "xfce_badge.png";
        case "xterm":
            return "recovery_console_badge.png";
        case "gnome-xmonad":
            return "xmonad_badge.png";
        case "remote-login":
            return "remote_login_help.png";
        default:
            return null;
        }
    }

    private static HashTable<string, Gdk.Pixbuf> badges; /* cache of badges */
    public static Gdk.Pixbuf? get_badge (string session)
    {
        if (session == "default")
        {
            var sessions = LightDM.get_sessions().copy();
            foreach (var find_session in sessions)
            {
                if (find_session.key == "default")
                {
                    foreach (var real_session in sessions)
                    {
                        if (real_session.name == find_session.name)
                        {
                            session = real_session.key;
                            break;
                        }
                    }
                    break;
                }
            }
        }

        var name = get_badge_name_from_alias_list (session);

        if (name == null)
        {
            var default_name_svg = "%s_badge.svg".printf (session);
            var default_name_png = "%s_badge.png".printf (session);
            var default_name_svg_path = Path.build_filename (Config.PKGDATADIR, default_name_svg, null);
            var default_name_png_path = Path.build_filename (Config.PKGDATADIR, default_name_png, null);
            if (FileUtils.test (default_name_svg_path, FileTest.EXISTS)) {
                name = default_name_svg;
            }
            else if (FileUtils.test (default_name_png_path, FileTest.EXISTS)) {
                name = default_name_png;
            }
        }

        if (name == null)
        {
            /* Not a known name, but let's see if we have a custom badge before
               giving up entirely and using the unknown badget. */
            var maybe_name = "custom_%s_badge.png".printf (session);
            var maybe_path = Path.build_filename (Config.PKGDATADIR, maybe_name, null);
            if (FileUtils.test (maybe_path, FileTest.EXISTS))
                name = maybe_name;
            else
                name = "unknown_badge.png";
        }

        if (badges == null)
            badges = new HashTable<string, Gdk.Pixbuf> (str_hash, str_equal);

        var pixbuf = badges.lookup (name);
        if (pixbuf == null)
        {
            try
            {
                pixbuf = new Gdk.Pixbuf.from_file_at_size (Path.build_filename (Config.PKGDATADIR, name, null),
                                                           BADGE_SIZE * _scale_factor, BADGE_SIZE * _scale_factor);
                badges.insert (name, pixbuf);
            }
            catch (Error e)
            {
                debug ("Error loading badge %s: %s", name, e.message);
            }
        }

        return pixbuf;
    }
}
