/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
 * Copyright (C) 2015-2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
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
        this.add_events (Gdk.EventMask.SCROLL_MASK);
        this.scroll_event.connect (this.scrolled_cb);

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

    public bool scrolled_cb (Gtk.Widget pWidget, Gdk.EventScroll pEvent)
    {
        Indicator.Object pObject = pWidget.get_data ("indicator-object");
        int nDirection = 0;

        if (pEvent.direction == Gdk.ScrollDirection.UP)
        {
            nDirection = 1;
        }
        else if (pEvent.direction == Gdk.ScrollDirection.DOWN)
        {
            nDirection = -1;
        }

        GLib.Signal.emit_by_name (pObject, "entry-scrolled", 1, nDirection);

        return false;
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

    private List<Indicator.Object> indicator_objects;

    construct
    {
        add_style_class (this);

        /* Add shadow. */
        var shadow_style = new Gtk.CssProvider ();

        try
        {
            shadow_style.load_from_data ("* { box-shadow: 0px 0px 5px 5px #000000; }", -1);
        }
        catch (Error pError)
        {
            error ("Panic: Failed adding shadow: %s", pError.message);
        }

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

            /* The below does not work, so for now we need to stick to "set_right_justified"
            hostname_item.set_hexpand (true);
            hostname_item.set_halign (Gtk.Align.END);*/
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
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        min = HEIGHT;
        nat = HEIGHT;
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

    private void setup_indicators ()
    {
        /* Set indicators to run with reduced functionality */
        AGUtils.greeter_set_env ("INDICATOR_GREETER_MODE", "1");

        /* Don't allow virtual file systems? */
        AGUtils.greeter_set_env ("GIO_USE_VFS", "local");
        AGUtils.greeter_set_env ("GVFS_DISABLE_FUSE", "1");

        /* Hint to have mate-settings-daemon run in greeter mode */
        AGUtils.greeter_set_env ("RUNNING_UNDER_GDM", "1");

        /* Let indicators know about our unique dbus name */
        try
        {
            var conn = Bus.get_sync (BusType.SESSION);
            AGUtils.greeter_set_env ("ARCTICA_GREETER_DBUS_NAME", conn.get_unique_name ());
        }
        catch (IOError e)
        {
            debug ("Could not set DBUS_NAME: %s", e.message);
        }

        debug ("LANG=%s LANGUAGE=%s", Environment.get_variable ("LANG"), Environment.get_variable ("LANGUAGE"));

        var indicator_list = AGSettings.get_strv(AGSettings.KEY_INDICATORS);

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
        menuitem.set_data ("indicator-object", object);
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
