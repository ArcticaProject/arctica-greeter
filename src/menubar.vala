/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
 * Copyright (C) 2015-2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
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
            var pContext = entry.label.get_style_context ();
            var pProvider = new Gtk.CssProvider ();

            try
            {
                pProvider.load_from_data ("*.high_contrast {color: #000000; font-size: 12pt; text-shadow: none;}", -1);
            }
            catch (Error pError)
            {
                error ("Panic: Failed adding indicator label colour: %s", pError.message);
            }

            pContext.add_provider (pProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
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

public class MenuBar : Gtk.Grid
{
    public Background? background { get; construct; default = null; }
    public Gtk.Window? keyboard_window { get; private set; default = null; }
    public Gtk.AccelGroup? accel_group { get; construct; }

    public MenuBar (Background bg, Gtk.AccelGroup ag)
    {
        Object (background: bg, accel_group: ag);
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
    private Gtk.MenuBar pMenubar;

    construct
    {
        this.pMenubar = new Gtk.MenuBar ();
        this.pMenubar.halign = Gtk.Align.END;
        this.pMenubar.hexpand = true;
        this.pMenubar.pack_direction = Gtk.PackDirection.RTL;
        this.pMenubar.show ();
        this.attach (this.pMenubar, 1, 0, 1, 1);
        this.show ();
        add_style_class (this);
        Gtk.CssProvider pGridProvider = new Gtk.CssProvider ();
        string sBackGround = AGSettings.get_string (AGSettings.KEY_MENUBAR_BGCOLOR);
        Gdk.RGBA pBackGround = Gdk.RGBA ();
        pBackGround.parse (sBackGround);
        int nRed = (int)(pBackGround.red * 255.0);
        int nGreen = (int)(pBackGround.green * 255.0);
        int nBlue = (int)(pBackGround.blue * 255.0);
        double fApha = AGSettings.get_double (AGSettings.KEY_MENUBAR_ALPHA);

        // Assure that printf operates in C.UTF-8 locale for float-to-string conversions.
        Intl.setlocale(LocaleCategory.NUMERIC, "C.UTF-8");

        try
        {
            pGridProvider.load_from_data ("* { background-color: rgba(%i, %i, %i, %f); } *.high_contrast { background-color: #ffffff; color: #000000; text-shadow: none; }".printf (nRed, nGreen, nBlue, fApha), -1);
        }
        catch (Error pError)
        {
            error ("Panic: Failed loading menubar grid colours: %s", pError.message);
        }

        this.get_style_context ().add_provider (pGridProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Gtk.CssProvider pMenubarProvider = new Gtk.CssProvider ();

        try
        {
            pMenubarProvider.load_from_data ("* { background-color: transparent; } *.high_contrast { color: #000000; text-shadow: none; }", -1);
        }
        catch (Error pError)
        {
            error ("Panic: Failed loading menubar colours: %s", pError.message);
        }

        this.pMenubar.get_style_context ().add_provider (pMenubarProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        /* Add shadow. */
        var shadow_style = new Gtk.CssProvider ();

        try
        {
            shadow_style.load_from_data ("* { box-shadow: 0px 0px 5px 5px rgba(%i, %i, %i, %f); }".printf (nRed, nGreen, nBlue, fApha), -1);
        }
        catch (Error pError)
        {
            error ("Panic: Failed adding shadow: %s", pError.message);
        }

        this.get_style_context ().add_provider (shadow_style,
                                                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (AGSettings.get_boolean (AGSettings.KEY_SHOW_HOSTNAME))
        {
            Gtk.Label pLabel = new Gtk.Label (Posix.utsname ().nodename);
            pLabel.vexpand = true;
            pLabel.margin_start = 6;
            pLabel.show ();
            this.attach (pLabel, 0, 0, 1, 1);
        }

        /* Prevent dragging the window by the menubar */
        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {-GtkWidget-window-dragging: false;}", -1);
            this.pMenubar.get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading menubar style: %s", e.message);
        }

        setup_indicators ();
    }

    public void select_first (bool bSearchSensitive)
    {
        this.pMenubar.select_first (bSearchSensitive);
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        var greeter = new ArcticaGreeter ();
        min = (int)Math.round(greeter.menubar_height - 8);
        nat = (int)Math.round(greeter.menubar_height - 8);
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
        foreach (var child in this.pMenubar.get_children ())
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
        this.pMenubar.insert (menuitem, pos);
    }

    private void indicator_removed_cb (Indicator.Object object, Indicator.ObjectEntry entry)
    {
        debug ("Removing indicator object %p", entry);

        foreach (var child in this.pMenubar.get_children ())
        {
            var menuitem = (IndicatorMenuItem) child;
            if (menuitem.entry == entry)
            {
                this.pMenubar.remove (child);
                return;
            }
        }

        warning ("Indicator object %p not in menubar", entry);
    }
}
