/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
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
 * Authors: Robert Ancell <robert.ancell@canonical.com>
 *          Michael Terry <michael.terry@canonical.com>
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 */

private class IndicatorMenuItem : Gtk.MenuItem
{
    public unowned Indicator.ObjectEntry entry;
    private Gtk.Box hbox;

    public IndicatorMenuItem (Indicator.ObjectEntry entry)
    {
        this.entry = entry;
        this.hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        this.add (this.hbox);
        this.hbox.show ();

        if (entry.label != null)
        {
            entry.label.show.connect (this.visibility_changed_cb);
            entry.label.hide.connect (this.visibility_changed_cb);
            hbox.pack_start (entry.label, false, false, 0);
        }
        if (entry.image != null)
        {
            entry.image.show.connect (visibility_changed_cb);
            entry.image.hide.connect (visibility_changed_cb);
            hbox.pack_start (entry.image, false, false, 0);
        }
        if (entry.accessible_desc != null)
            get_accessible ().set_name (entry.accessible_desc);
        if (entry.menu != null)
            set_submenu (entry.menu);

        if (has_visible_child ())
            show ();
    }

    public bool has_visible_child ()
    {
        return (entry.image != null && entry.image.get_visible ()) ||
               (entry.label != null && entry.label.get_visible ());
    }

    public void visibility_changed_cb (Gtk.Widget widget)
    {
        visible = has_visible_child ();
    }
}

public class MenuBar : Gtk.MenuBar
{
    public Background? background { get; construct; default = null; }
    public Gtk.Window? keyboard_window { get; private set; default = null; }
    public Gtk.AccelGroup? accel_group { get; construct; }

    private const int HEIGHT = 32;

    public MenuBar (Background bg, Gtk.AccelGroup ag)
    {
        Object (background: bg, accel_group: ag);
    }

    public override bool draw (Cairo.Context c)
    {
        if (background != null)
        {
            /* Disable background drawing to see how it changes the visuals. */
            /*
            int x, y;
            background.translate_coordinates (this, 0, 0, out x, out y);
            c.save ();
            c.translate (x, y);
            background.draw_full (c, Background.DrawFlags.NONE);
            c.restore ();
            */
        }

        /* Get the style and dimensions. */
        var style_ctx = this.get_style_context ();

        var w = this.get_allocated_width ();
        var h = this.get_allocated_height ();

        /* Add a group. */
        c.push_group ();

        /* Draw the background normally. */
        style_ctx.render_background (c, 0, 0, w, h);

        /* Draw the frame normally. */
        style_ctx.render_frame (c, 0, 0, w, h);

        /* Go back to the original widget. */
        c.pop_group_to_source ();

        var agsettings = new AGSettings ();
        if (agsettings.high_contrast) {
            /*
             * In case the high contrast mode is enabled, do not add any
             * transparency. While the GTK theme might define one (even though
             * it better should not, given that we are also switching to a
             * high contrast theme), we certainly do not want to make the look
             * fuzzy.
             */
             c.paint ();
        }
        else {
            /*
             * And finally repaint it with additional transparency.
             * Note that most GTK styles already define a transparency for OSD
             * menus. We want to have something more transparent, but also
             * make sure that it is not too transparent, so do not choose a
             * value that is too low here - certainly not your desired final
             * alpha value.
             */
            c.paint_with_alpha (AGSettings.get_double (AGSettings.KEY_MENUBAR_ALPHA));
        }

        foreach (var child in get_children ())
        {
            propagate_draw (child, c);
        }

        return false;
    }

    public static void add_style_class (Gtk.Widget widget)
    {
        /*
         * Add style context class osd, which makes the widget respect the GTK
         * style definitions for this type of elements.
         */
        var ctx = widget.get_style_context ();
        ctx.add_class ("osd");
    }

    /* Due to LP #973922 the keyboard has to be loaded after the main window
     * is shown and given focus. Therefore we don't enable the active state
     * until now.
     */
    public void set_keyboard_state ()
    {
        var greeter = new ArcticaGreeter ();
        if (!greeter.test_mode)
            onscreen_keyboard_item.set_active (AGSettings.get_boolean (AGSettings.KEY_ONSCREEN_KEYBOARD));
    }

    private List<Indicator.Object> indicator_objects;
    private Gtk.CheckMenuItem high_contrast_item;
    private Gtk.CheckMenuItem big_font_item;
    private Pid keyboard_pid = 0;
    private Pid reader_pid = 0;
    private Gtk.CheckMenuItem onscreen_keyboard_item;

    construct
    {
        add_style_class (this);

        /* Add shadow. */
        var shadow_style = new Gtk.CssProvider ();
        shadow_style.load_from_data ("* { box-shadow: 0px 0px 5px 5px #000000; }", -1);
        this.get_style_context ().add_provider (shadow_style,
                                                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        pack_direction = Gtk.PackDirection.RTL;

        if (AGSettings.get_boolean (AGSettings.KEY_SHOW_HOSTNAME))
        {
            var hostname_item = new Gtk.MenuItem.with_label (Posix.utsname ().nodename);
            append (hostname_item);
            hostname_item.show ();

            /*
             * Even though this (menu) item is insensitive, we want its label
             * text to have the sensitive color as to not look out of place
             * and difficult to read.
             *
             * There's a really weird bug that leads to always fetch the
             * sensitive color after the widget (menuitem in this case) has
             * been set to insensitive once - at least in this constructor.
             *
             * I haven't found a way to fix that, or, for that matter, what is
             * actually causing the issue. Even waiting on the main event loop
             * until all events are processed didn't help.
             *
             * We'll work around this issue by fetching the color before
             * setting the widget to insensitive and call it proper.
             */
            var insensitive_override_style = new Gtk.CssProvider ();

            /*
             * First, fetch the associated GtkStyleContext and save the state,
             * we'll override the state later on.
             */
            var hostname_item_ctx = hostname_item.get_style_context ();
            hostname_item_ctx.save ();

            try {
                /* Get the actual color. */
                var sensitive_color = hostname_item_ctx.get_color (Gtk.StateFlags.NORMAL);
                debug ("Directly fetched sensitive color: %s", sensitive_color.to_string ());

                insensitive_override_style.load_from_data ("*:disabled { color: %s; }".printf(sensitive_color.to_string ()), -1);
            }
            catch (Error e)
            {
                debug ("Internal error loading hostname menu item text color: %s", e.message);
            }
            finally {
                /*
                 * Restore the context, which we might have changed through the
                 * previous get_color () call.
                 */
                hostname_item_ctx.restore ();
            }

            try {
                /* And finally override the insensitive color. */
                hostname_item_ctx.add_provider (insensitive_override_style,
                                                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

                /*
                 * Just overriding the color for the Gtk.MenuItem widget
                 * doesn't help, we'll also apply it to the children.
                 *
                 * In theory, we could just use the get_child () method to
                 * fetch the only child we should ever have on that widget,
                 * namely a GtkAccelLabel, but that isn't future-proof enough,
                 * especially if that is ever extended into having a submenu.
                 *
                 * Thus, iterate over all children and override the style for
                 * all of them.
                 */
                if (gtk_is_container (hostname_item)) {
                    var children = hostname_item.get_children ();
                    foreach (Gtk.Widget element in children) {
                        var child_ctx = element.get_style_context ();
                        debug ("Adding override style provider to child widget %s", element.name);
                        child_ctx.add_provider (insensitive_override_style,
                                                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                    }
                }
            }
            catch (Error e)
            {
                debug ("Internal error overriding hostname menu item text color: %s", e.message);
            }

            hostname_item.set_sensitive (false);

            hostname_item.set_right_justified (true);
        }

        /* Prevent dragging the window by the menubar */
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {-GtkWidget-window-dragging: false;}", -1);
            get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading menubar style: %s", e.message);
        }

        setup_indicators ();

        var greeter = new ArcticaGreeter ();
        greeter.starting_session.connect (cleanup);
    }

    private void close_pid (ref Pid pid)
    {
        if (pid > 0)
        {
#if VALA_0_40
            Posix.kill (pid, Posix.Signal.TERM);
#else
            Posix.kill (pid, Posix.SIGTERM);
#endif
            int status;
            Posix.waitpid (pid, out status, 0);
            pid = 0;
        }
    }

    public void cleanup ()
    {
        close_pid (ref keyboard_pid);
        close_pid (ref reader_pid);
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        min = HEIGHT;
        nat = HEIGHT;
    }

    private void greeter_set_env (string key, string val)
    {
        GLib.Environment.set_variable (key, val, true);

        /* And also set it in the DBus activation environment so that any
         * indicator services pick it up. */
        try
        {
            var proxy = new GLib.DBusProxy.for_bus_sync (GLib.BusType.SESSION,
                                                         GLib.DBusProxyFlags.NONE, null,
                                                         "org.freedesktop.DBus",
                                                         "/org/freedesktop/DBus",
                                                         "org.freedesktop.DBus",
                                                         null);

            var builder = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
            builder.add ("{ss}", key, val);

            proxy.call_sync ("UpdateActivationEnvironment", new GLib.Variant ("(a{ss})", builder), GLib.DBusCallFlags.NONE, -1, null);
        }
        catch (Error e)
        {
            warning ("Could not get set environment for indicators: %s", e.message);
            return;
        }
    }

    private Gtk.Widget make_a11y_indicator ()
    {
        var a11y_item = new Gtk.MenuItem ();
        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        hbox.show ();
        a11y_item.add (hbox);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "a11y.svg"));
        image.show ();
        hbox.add (image);
        a11y_item.show ();
        a11y_item.set_submenu (new Gtk.Menu ());
        onscreen_keyboard_item = new Gtk.CheckMenuItem.with_label (_("Onscreen keyboard"));
        onscreen_keyboard_item.toggled.connect (keyboard_toggled_cb);
        onscreen_keyboard_item.show ();
        unowned Gtk.Menu submenu = a11y_item.submenu;
        submenu.append (onscreen_keyboard_item);
        high_contrast_item = new Gtk.CheckMenuItem.with_label (_("High Contrast"));
        high_contrast_item.toggled.connect (high_contrast_toggled_cb);
        high_contrast_item.add_accelerator ("activate", accel_group, Gdk.Key.h, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
        high_contrast_item.show ();
        submenu.append (high_contrast_item);
        var agsettings = new AGSettings ();
        debug ("Initializing high contrast menu item to state %s", agsettings.high_contrast.to_string ());
        high_contrast_item.set_active (agsettings.high_contrast);

/* Hide the Big Font feature until it's available.
        big_font_item = new Gtk.CheckMenuItem.with_label (_("Big Font"));
        big_font_item.toggled.connect (big_font_toggled_cb);
        big_font_item.add_accelerator ("activate", accel_group, Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK, Gtk.AccelFlags.VISIBLE);
        big_font_item.show ();
        submenu.append (big_font_item);
*/

        big_font_item.set_active (agsettings.big_font);
        var item = new Gtk.CheckMenuItem.with_label (_("Screen Reader"));
        item.toggled.connect (screen_reader_toggled_cb);
        item.add_accelerator ("activate", accel_group, Gdk.Key.s, Gdk.ModifierType.SUPER_MASK | Gdk.ModifierType.MOD1_MASK, Gtk.AccelFlags.VISIBLE);
        item.show ();
        submenu.append (item);
        item.set_active (AGSettings.get_boolean (AGSettings.KEY_SCREEN_READER));
        return a11y_item;
    }

    private Indicator.Object? load_indicator_file (string indicator_name)
    {

        string dir = Config.INDICATOR_FILE_DIR;
        string path;
        Indicator.Object io;

        /* To stay backwards compatible, use org.ayatana.indicator as the default prefix */
        if (indicator_name.index_of_char ('.') < 0)
            path = @"$dir/org.ayatana.indicator.$indicator_name";
        else
            path = @"$dir/$indicator_name";

        try
        {
            io = new Indicator.Ng.for_profile (path, "desktop_greeter");
        }
        catch (FileError error)
        {
            /* the calling code handles file-not-found; don't warn here */
            return null;
        }
        catch (Error error)
        {
            warning ("unable to load %s: %s", indicator_name, error.message);
            return null;
        }

        return io;
    }

    private Indicator.Object? load_indicator_library (string indicator_name)
    {
        // Find file, if it exists
        string[] names_to_try = {"lib" + indicator_name + ".so",
                                 indicator_name + ".so",
                                 indicator_name};
        foreach (var filename in names_to_try)
        {
            var full_path = Path.build_filename (Config.INDICATORDIR, filename);
            var io = new Indicator.Object.from_file (full_path);
            if (io != null)
                return io;
        }

        return null;
    }

    private void load_indicator (string indicator_name)
    {
        var greeter = new ArcticaGreeter ();
        if (!greeter.test_mode)
        {
            if (indicator_name == "ug-accessibility")
            {
                var a11y_item = make_a11y_indicator ();
                insert (a11y_item, (int) get_children ().length () - 1);
            }
            else
            {
                var io = load_indicator_file (indicator_name);

                if (io == null)
                    io = load_indicator_library (indicator_name);

                if (io != null)
                {
                    indicator_objects.append (io);
                    io.entry_added.connect (indicator_added_cb);
                    io.entry_removed.connect (indicator_removed_cb);
                    foreach (var entry in io.get_entries ())
                        indicator_added_cb (io, entry);
                }
            }
        }
    }

    private void setup_indicators ()
    {
        /* Set indicators to run with reduced functionality */
        greeter_set_env ("INDICATOR_GREETER_MODE", "1");

        /* Don't allow virtual file systems? */
        greeter_set_env ("GIO_USE_VFS", "local");
        greeter_set_env ("GVFS_DISABLE_FUSE", "1");

        /* Hint to have mate-settings-daemon run in greeter mode */
        greeter_set_env ("RUNNING_UNDER_GDM", "1");

        /* Let indicators know about our unique dbus name */
        try
        {
            var conn = Bus.get_sync (BusType.SESSION);
            greeter_set_env ("ARCTICA_GREETER_DBUS_NAME", conn.get_unique_name ());
        }
        catch (IOError e)
        {
            debug ("Could not set DBUS_NAME: %s", e.message);
        }

        debug ("LANG=%s LANGUAGE=%s", Environment.get_variable ("LANG"), Environment.get_variable ("LANGUAGE"));

        var indicator_list = AGSettings.get_strv(AGSettings.KEY_INDICATORS);

        var update_indicator_list = false;
        for (var i = 0; i < indicator_list.length; i++)
        {
            if (indicator_list[i] == "ug-keyboard")
            {
                indicator_list[i] = "org.ayatana.indicator.keyboard";
                update_indicator_list = true;
            }
        }

        if (update_indicator_list)
            AGSettings.set_strv(AGSettings.KEY_INDICATORS, indicator_list);

        foreach (var indicator in indicator_list)
            load_indicator(indicator);

       indicator_objects.sort((a, b) => {
           int pos_a = a.get_position ();
           int pos_b = b.get_position ();

           if (pos_a < 0)
               pos_a = 1000;
           if (pos_b < 0)
               pos_b = 1000;

           return pos_a - pos_b;
        });

        debug ("LANG=%s LANGUAGE=%s", Environment.get_variable ("LANG"), Environment.get_variable ("LANGUAGE"));
    }

    private void keyboard_toggled_cb (Gtk.CheckMenuItem item)
    {
        /* FIXME: The below would be sufficient if gnome-session were running
         * to notice and run a screen keyboard in /etc/xdg/autostart...  But
         * since we're not running gnome-session, we hardcode onboard here. */
        /* var settings = new Settings ("org.gnome.desktop.a11y.applications");*/
        /*settings.set_boolean ("screen-keyboard-enabled", item.active);*/

        AGSettings.set_boolean (AGSettings.KEY_ONSCREEN_KEYBOARD, item.active);

        if (keyboard_window == null)
        {
            int id = 0;

            try
            {
                string[] argv;
                string cmd;
                int onboard_stdout_fd;
                var layout = AGSettings.get_string (AGSettings.KEY_ONSCREEN_KEYBOARD_LAYOUT);
                var file = File.new_for_path ("/usr/share/onboard/layouts/%s.onboard".printf (layout));
                if (file.query_exists ()) {
                    cmd = "onboard --xid --layout='/usr/share/onboard/layouts/%s.onboard'".printf (layout);
                }
                else {
                    cmd = "onboard --xid";
                }
                Shell.parse_argv (cmd, out argv);
                Process.spawn_async_with_pipes (null,
                                                argv,
                                                null,
                                                SpawnFlags.SEARCH_PATH,
                                                null,
                                                out keyboard_pid,
                                                null,
                                                out onboard_stdout_fd,
                                                null);
                var f = FileStream.fdopen (onboard_stdout_fd, "r");
                var stdout_text = new char[1024];
                if (f.gets (stdout_text) != null)
                    id = int.parse ((string) stdout_text);

            }
            catch (Error e)
            {
                warning ("Error setting up keyboard: %s", e.message);
                return;
            }

            var keyboard_socket = new Gtk.Socket ();
            keyboard_socket.show ();
            keyboard_window = new Gtk.Window ();
            keyboard_window.accept_focus = false;
            keyboard_window.focus_on_map = false;
            keyboard_window.add (keyboard_socket);
            keyboard_socket.add_id (id);

            /* Put keyboard at the bottom of the screen */
            var display = get_display ();
            var monitor = display.get_monitor_at_window (get_window ());
            Gdk.Rectangle geom;
            geom = monitor.get_geometry ();
            keyboard_window.move (geom.x, geom.y + geom.height - 200);
            keyboard_window.resize (geom.width, 200);
        }

        keyboard_window.visible = item.active;
    }

    private void high_contrast_toggled_cb (Gtk.CheckMenuItem item)
    {
        var agsettings = new AGSettings ();
        agsettings.high_contrast = item.active;
    }

    private void big_font_toggled_cb (Gtk.CheckMenuItem item)
    {
        var agsettings = new AGSettings ();
        agsettings.big_font = item.active;
    }

    private void screen_reader_toggled_cb (Gtk.CheckMenuItem item)
    {
        /* FIXME: The below would be sufficient if gnome-session were running
         * to notice and run a screen reader in /etc/xdg/autostart...  But
         * since we're not running gnome-session, we hardcode orca here.
        /*var settings = new Settings ("org.gnome.desktop.a11y.applications");*/
        /*settings.set_boolean ("screen-reader-enabled", item.active);*/

        AGSettings.set_boolean (AGSettings.KEY_SCREEN_READER, item.active);

        /* Hardcoded orca: */
        if (item.active)
        {
            try
            {
                string[] argv;
                Shell.parse_argv ("orca --replace --no-setup --disable splash-window,", out argv);
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out reader_pid);
                // This is a workaround for bug https://launchpad.net/bugs/944159
                // The problem is that orca seems to not notice that it's in a
                // password field on startup.  We just need to kick orca in the
                // pants.  We do this two ways:  a racy way and a non-racy way.
                // We kick it after a second which is ideal if we win the race,
                // because the user gets to hear what widget they are in, and
                // the first character will be masked.  Otherwise, if we lose
                // that race, the first time the user types (see
                // DashEntry.key_press_event), we will kick orca again.  While
                // this is not racy with orca startup, it is racy with whether
                // orca will read the first character or not out loud.  Hence
                // why we do both.  Ideally this would be fixed in orca itself.
                var greeter = new ArcticaGreeter ();
                greeter.orca_needs_kick = true;
                Timeout.add_seconds (1, () => {
                    Signal.emit_by_name ((get_toplevel () as Gtk.Window).get_focus ().get_accessible (), "focus-event", true);
                    return false;
                });
            }
            catch (Error e)
            {
                warning ("Failed to run Orca: %s", e.message);
            }
        }
        else
            close_pid (ref reader_pid);
    }

    private uint get_indicator_index (Indicator.Object object)
    {
        uint index = 0;

        foreach (var io in indicator_objects)
        {
            if (io == object)
                return index;
            index++;
        }

        return index;
    }

    private Indicator.Object? get_indicator_object_from_entry (Indicator.ObjectEntry entry)
    {
        foreach (var io in indicator_objects)
        {
            foreach (var e in io.get_entries ())
            {
                if (e == entry)
                    return io;
            }
        }

        return null;
    }

    private void indicator_added_cb (Indicator.Object object, Indicator.ObjectEntry entry)
    {
        var index = get_indicator_index (object);
        var pos = 0;
        foreach (var child in get_children ())
        {
            if (!(child is IndicatorMenuItem))
                break;

            var menuitem = (IndicatorMenuItem) child;
            var child_object = get_indicator_object_from_entry (menuitem.entry);
            var child_index = get_indicator_index (child_object);
            if (child_index > index)
                break;
            pos++;
        }

        debug ("Adding indicator object %p at position %d", entry, pos);

        var menuitem = new IndicatorMenuItem (entry);
        insert (menuitem, pos);
    }

    private void indicator_removed_cb (Indicator.Object object, Indicator.ObjectEntry entry)
    {
        debug ("Removing indicator object %p", entry);

        foreach (var child in get_children ())
        {
            var menuitem = (IndicatorMenuItem) child;
            if (menuitem.entry == entry)
            {
                remove (child);
                return;
            }
        }

        warning ("Indicator object %p not in menubar", entry);
    }
}
