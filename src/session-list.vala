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

    private unowned GLib.List<LightDM.Session> sessions_sorted_ci (GLib.List<LightDM.Session> sessions)
    {
        sessions.sort_with_data((a, b) => GLib.strcmp (a.name.casefold(), b.name.casefold()));
        return sessions;
    }

    private ToggleBox box;

    construct
    {
        label = _("Select desktop environment");
        name_label.vexpand = false;

        box = new ToggleBox (default_session, session);

        if (ArcticaGreeter.singleton.test_mode)
        {
            box.add_item ("gnome", "GNOME", SessionList.get_badge ("gnome"));
            box.add_item ("kde", "KDE", SessionList.get_badge ("kde"));
            box.add_item ("ubuntu", "Ubuntu", SessionList.get_badge ("ubuntu"));
        }
        else
        {
            foreach (var session in sessions_sorted_ci( LightDM.get_sessions() ) )
            {
                debug ("Adding session %s (%s)", session.key, session.name);
                box.add_item (session.key, session.name, SessionList.get_badge (session.key));
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

    private static string? get_badge_name (string session)
    {
        switch (session)
        {
        case "awesome":
            return "awesome_badge.png";
        case "budgie-desktop":
            return "budgie_badge.png";
        case "ubuntu":
        case "ubuntu-2d":
        case "unity":
            return "ubuntu_badge.png";
        case "gnome-classic":
        case "gnome-flashback-compiz":
        case "gnome-flashback-metacity":
        case "gnome-shell":
        case "gnome-wayland":
        case "gnome":
        case "openbox-gnome":
            return "gnome_badge.png";
        case "wmaker-common":
            return "gnustep_badge.png";
        case "kde":
        case "kde-plasma":
        case "openbox-kde":
        case "plasma":
            return "kde_badge.png";
        case "i3":
        case "i3-with-shmlog":
            return "i3_badge.png";
        case "lightdm-xsession":
            return "xsession_badge.png";
        case "lxde":
        case "LXDE":
            return "lxde_badge.png";
        case "matchbox":
            return "matchbox_badge.png";
        case "mate":
            return "mate_badge.png";
        case "openbox":
            return "openbox_badge.png";
        case "sugar":
            return "sugar_badge.png";
        case "surf-display":
            return "surf_badge.png";
        case "twm":
            return "twm_badge.png";
        case "xfce":
            return "xfce_badge.png";
        case "xterm":
            return "recovery_console_badge.png";
        case "xmonad":
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
        var name = get_badge_name (session);

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
                pixbuf = new Gdk.Pixbuf.from_file (Path.build_filename (Config.PKGDATADIR, name, null));
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
