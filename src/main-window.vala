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

public class MainWindow : Gtk.Window
{
    public MenuBar menubar;

    private List<Monitor> monitors;
    private Monitor? primary_monitor;
    private Monitor active_monitor;
    private string only_on_monitor;
    private bool monitor_setting_ok;
    private Background background;
    private Gtk.Box login_box;
    private Gtk.Box hbox;
    private Gtk.Box content_box;
    private Gtk.Button back_button;
    private ShutdownDialog? shutdown_dialog = null;
    private bool do_resize;

    public ListStack stack;

    public enum Struts {
        LEFT,
        RIGHT,
        TOP,
        BOTTOM,
        LEFT_START,
        LEFT_END,
        RIGHT_START,
        RIGHT_END,
        TOP_START,
        TOP_END,
        BOTTOM_START,
        BOTTOM_END
    }

    public enum MenubarPositions {
        LEFT,
        RIGHT,
        TOP,
        BOTTOM,
    }

    construct
    {
        events |= Gdk.EventMask.POINTER_MOTION_MASK;

        var accel_group = new Gtk.AccelGroup ();
        add_accel_group (accel_group);

        Gtk.StyleContext pContext = get_style_context ();
        Gtk.CssProvider pProvider = new Gtk.CssProvider ();
        string sColour = AGSettings.get_string (AGSettings.KEY_BACKGROUND_COLOR);
        string sCss = "* {background-color: %s;}".printf (sColour);

        try
        {
            pProvider.load_from_data (sCss, -1);
            pContext.add_provider (pProvider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error pError)
        {
            warning ("Panic: Error loading style for main window: %s", pError.message);
        }

        get_accessible ().set_name (_("Login Screen"));
        ArcticaGreeter.add_style_class (this);

        background = new Background ();
        add (background);
        ArcticaGreeter.add_style_class (background);

        login_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        login_box.show ();
        background.add (login_box);

        /* Box for menubar shadow */
        var menubox = new Gtk.EventBox ();
        var shadow_path = Path.build_filename (Config.PKGDATADIR,
                                               "shadow.png", null);
        var shadow_style = "";
        if (FileUtils.test (shadow_path, FileTest.EXISTS))
        {
            shadow_style = "background-image: url('%s');
                            background-repeat: repeat;".printf(shadow_path);
        }

        var greeter = new ArcticaGreeter();
        menubox.set_size_request (-1, greeter.menubar_height);
        menubox.show ();
        login_box.add (menubox);
        ArcticaGreeter.add_style_class (menubox);

        menubar = new MenuBar (background, accel_group);
        menubar.set_hexpand (true);
        menubar.set_vexpand (false);
        menubar.set_halign (Gtk.Align.FILL);
        menubar.set_valign (Gtk.Align.START);
        menubar.show ();
        menubox.add (menubar);
        ArcticaGreeter.add_style_class (menubar);
        ArcticaGreeter.add_style_class (menubox);

        content_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        content_box.expand = true;
        content_box.show ();
        login_box.add (content_box);

        var content_align = AGSettings.get_string(AGSettings.KEY_CONTENT_ALIGN);
        var x_align = Gtk.Align.CENTER;

        if (content_align == "left")
        {
            x_align = Gtk.Align.START;
        }
        else if (content_align == "right")
        {
            x_align = Gtk.Align.END;
        }

        hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        hbox.expand = true;
        hbox.show ();
        hbox.halign = x_align;
        hbox.valign = Gtk.Align.CENTER;

        if (content_align == "center")
        {
            // offset for back button
            hbox.margin_end = greeter.grid_size;
        }

        content_box.add (hbox);
        back_button = new FlatButton ();
        back_button.get_accessible ().set_name (_("Back"));
        Gtk.button_set_focus_on_click (back_button, false);
        var image = new Gtk.Image.from_file (Path.build_filename (Config.PKGDATADIR, "arrow_left.png", null));
        image.show ();
        back_button.set_size_request (greeter.grid_size - (int)(GreeterList.BORDER * greeter.scaling_factor_widgets * 2),
                                      greeter.grid_size - (int)(GreeterList.BORDER * greeter.scaling_factor_widgets * 2));

        try
        {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {background-color: transparent;
                                      %s
                                     }
                                   *.high_contrast {background-color: black;
                                                    border-color: white;
                                                   }".printf(shadow_style), -1);
            var context = back_button.get_style_context();
            context.add_provider (style,
                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading back button style: %s", e.message);
        }

        back_button.add (image);
        back_button.clicked.connect (pop_list);
        back_button.halign = Gtk.Align.CENTER;
        back_button.valign = Gtk.Align.CENTER;
        back_button.hexpand = false;
        back_button.vexpand = false;
        back_button.resize_mode = Gtk.ResizeMode.QUEUE;
        back_button.set_size_request (greeter.grid_size, -1);
        back_button.margin_bottom = greeter.menubar_height;
        hbox.add (back_button);

        stack = new ListStack ();
        stack.show ();
        stack.set_hexpand (false);
        stack.set_vexpand (true);
        stack.set_halign (Gtk.Align.CENTER);
        stack.set_valign (Gtk.Align.FILL);
        hbox.add (stack);

        add_user_list ();

        primary_monitor = null;
        do_resize = false;

        only_on_monitor = AGSettings.get_string(AGSettings.KEY_ONLY_ON_MONITOR);
        monitor_setting_ok = only_on_monitor == "auto";

        if (greeter.test_mode)
        {
            /* Simulate an 800x600 monitor to the left of a 640x480 monitor */
            monitors = new List<Monitor> ();
            monitors.append (new Monitor (0, 0, 800, 600));
            monitors.append (new Monitor (800, 120, 640, 480));
            background.set_monitors (monitors);
            move_to_monitor (monitors.nth_data (0));
            resize (background.width, background.height);
        }
        else
        {
            set_type_hint(Gdk.WindowTypeHint.DOCK);
            var screen = get_screen ();
            screen.monitors_changed.connect (monitors_changed_cb);
            monitors_changed_cb (screen);
        }
    }

    public void push_list (GreeterList widget)
    {
        stack.push (widget);

        if (stack.num_children > 1)
            back_button.show ();
    }

    public void pop_list ()
    {
        if (stack.num_children <= 2)
            back_button.hide ();

        stack.pop ();

        redraw_main_window();
    }

    protected void redraw_main_window ()
    {
        Gtk.Allocation allocation;
        this.get_allocation (out allocation);
        queue_draw_area (allocation.x, allocation.y, allocation.width, allocation.height);
    }


    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);

        var greeter = new ArcticaGreeter();

        if (content_box != null)
        {
            var content_align = AGSettings.get_string(AGSettings.KEY_CONTENT_ALIGN);
            content_box.margin_start = get_grid_offset (get_allocated_width ()) + (content_align == "left" ? greeter.grid_size : 0);
            content_box.margin_end = get_grid_offset (get_allocated_width ()) + (content_align == "right" ? greeter.grid_size : 0);
            content_box.margin_top = get_grid_offset (get_allocated_height ());
            content_box.margin_bottom = get_grid_offset (get_allocated_height ());
        }
    }

    /* Setup the size and position of the window */
    public void setup_window ()
    {
        resize (background.width, background.height);
        move (0, 0);
        move_to_monitor (primary_monitor);
    }

    public void set_struts ()
    {
        var greeter = new ArcticaGreeter();
        /* Substract the 5px shadow from the menubar height, so that indicators' menus render well */
        _set_struts (MenubarPositions.TOP, greeter.menubar_height);
    }

    private void getScreenSize (out int nScreenWidth, out int nScreenHeight)
    {
        Gdk.Display pDisplay = Gdk.Display.get_default ();
        int nMonitors = pDisplay.get_n_monitors ();

        if (nMonitors == 0)
        {
            nScreenWidth = 0;
            nScreenHeight = 0;
            
            return;
        }

        int x0 = int.MAX;
        int y0 = int.MAX;
        int x1 = int.MIN;
        int y1 = int.MIN;

        for (int nMonitor = 0; nMonitor < nMonitors; nMonitor++)
        {
            Gdk.Monitor pMonitor = pDisplay.get_monitor (nMonitor);
            Gdk.Rectangle cRectangle = pMonitor.get_geometry ();

            x0 = int.min (x0, cRectangle.x);
            y0 = int.min (y0, cRectangle.y);
            x1 = int.max (x1, cRectangle.x + cRectangle.width);
            y1 = int.max (y1, cRectangle.y + cRectangle.height);
        }

        nScreenWidth = x1 - x0;
        nScreenHeight = y1 - y0;
    }

    private void _set_struts (uint position, long menubar_size)
    {
        if (!get_realized()) {
                return;
        }

        int scale = get_scale_factor();

        if (primary_monitor == null) {
            return;
        }

        Gdk.Atom atom;
        long struts[12] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

        /* Subtract (non-scaled) 5px border + 2px extra spacing (to make indicator menus render nicely below menubar) */
        menubar_size = menubar_size - 7;

        int nScreenWidth = 0;
        int nScreenHeight = 0;
        getScreenSize (out nScreenWidth, out nScreenHeight);

        // Struts dependent on position
        switch (position) {
            case MenubarPositions.TOP:
                struts[Struts.TOP] = (menubar_size + primary_monitor.y) * scale;
                struts[Struts.TOP_START] = primary_monitor.x * scale;
                struts[Struts.TOP_END] = (primary_monitor.x + primary_monitor.width) * scale - 1;
                break;
            case MenubarPositions.LEFT:
                struts[Struts.LEFT] = (primary_monitor.x + menubar_size) * scale;
                struts[Struts.LEFT_START] = primary_monitor.y * scale;
                struts[Struts.LEFT_END] = (primary_monitor.y + primary_monitor.height) * scale - 1;
                break;
            case MenubarPositions.RIGHT:
                struts[Struts.RIGHT] = (menubar_size + nScreenWidth - primary_monitor.x - primary_monitor.width) * scale;
                struts[Struts.RIGHT_START] = primary_monitor.y * scale;
                struts[Struts.RIGHT_END] = (primary_monitor.y + primary_monitor.height) * scale - 1;
                break;
            case MenubarPositions.BOTTOM:
                default:
                struts[Struts.BOTTOM] = (menubar_size + nScreenHeight - primary_monitor.y - primary_monitor.height) * scale;
                struts[Struts.BOTTOM_START] = primary_monitor.x * scale;
                struts[Struts.BOTTOM_END] = (primary_monitor.x + primary_monitor.width) * scale - 1;
                break;
        }

        atom = Gdk.Atom.intern("_NET_WM_STRUT", false);
        Gdk.property_change(get_toplevel().get_window(), atom, Gdk.Atom.intern("CARDINAL", false),
            32, Gdk.PropMode.REPLACE, (uint8[])struts, 4);

        atom = Gdk.Atom.intern("_NET_WM_STRUT_PARTIAL", false);
        Gdk.property_change(get_toplevel().get_window(), atom, Gdk.Atom.intern("CARDINAL", false),
            32, Gdk.PropMode.REPLACE, (uint8[])struts, 12);
    }

    public override void realize ()
    {
        base.realize ();
        Gdk.DrawingContext background_context;
        background_context = get_window().begin_draw_frame(get_window().get_visible_region());

        background.set_surface (background_context.get_cairo_context().get_target());

        get_window().end_draw_frame(background_context);
    }

    private void monitors_changed_cb (Gdk.Screen screen)
    {
        Gdk.Display display;
        display = screen.get_display();

        Gdk.Rectangle geometry;
        Gdk.Monitor primary = display.get_primary_monitor();
        geometry = primary.get_geometry();

        monitors = new List<Monitor> ();
        primary_monitor = null;

        for (var i = 0; i < display.get_n_monitors (); i++)
        {
            Gdk.Monitor monitor = display.get_monitor(i);
            geometry = monitor.get_geometry ();
            debug ("Monitor %d is %dx%d pixels at %d,%d", i, geometry.width, geometry.height, geometry.x, geometry.y);

            if (monitor_is_unique_position (display, i))
            {
                var greeter_monitor = new Monitor (geometry.x, geometry.y, geometry.width, geometry.height);
                var plug_name = monitor.get_model();
                monitors.append (greeter_monitor);

                if (plug_name == only_on_monitor)
                    monitor_setting_ok = true;

                if (plug_name == only_on_monitor || primary_monitor == null || primary == monitor)
                    primary_monitor = greeter_monitor;
            }
        }

        debug ("MainWindow is %dx%d pixels", background.width, background.height);

        background.set_monitors (monitors);

        if(do_resize)
        {
            setup_window ();
        }
        else
        {
            do_resize = true;
        }

        set_struts ();
    }

    /* Check if a monitor has a unique position */
    private bool monitor_is_unique_position (Gdk.Display display, int n)
    {
        Gdk.Rectangle g0;
        Gdk.Monitor mon0;
        mon0 = display.get_monitor(n);
        g0 = mon0.get_geometry ();

        for (var i = n + 1; i < display.get_n_monitors (); i++)
        {
            Gdk.Rectangle g1;
            Gdk.Monitor mon1;
            mon1 = display.get_monitor(i);
            g1 = mon1.get_geometry();

            if (g0.x == g1.x && g0.y == g1.y)
                return false;
        }

        return true;
    }

    public override bool motion_notify_event (Gdk.EventMotion event)
    {
        if (!monitor_setting_ok || only_on_monitor == "auto")
        {
            var x = (int) (event.x + 0.5);
            var y = (int) (event.y + 0.5);

            /* Get motion event relative to this widget */
            if (event.window != get_window ())
            {
                int w_x, w_y;
                get_window ().get_origin (out w_x, out w_y);
                x -= w_x;
                y -= w_y;
                event.window.get_origin (out w_x, out w_y);
                x += w_x;
                y += w_y;
            }

            foreach (var m in monitors)
            {
                if (x >= m.x && x <= m.x + m.width && y >= m.y && y <= m.y + m.height)
                {
                    move_to_monitor (m);
                    break;
                }
            }
        }
        return false;
    }

    private void move_to_monitor (Monitor monitor)
    {
        active_monitor = monitor;
        login_box.set_size_request (monitor.width, monitor.height);
        background.set_active_monitor (monitor);
        background.move (login_box, monitor.x, monitor.y);

        if (shutdown_dialog != null)
        {
            shutdown_dialog.set_active_monitor (monitor);
            background.move (shutdown_dialog, monitor.x, monitor.y);
        }
    }

    private void add_user_list ()
    {
        GreeterList greeter_list;
        greeter_list = new UserList (background, menubar);
        greeter_list.show ();
        ArcticaGreeter.add_style_class (greeter_list);
        push_list (greeter_list);
    }

    public override bool key_press_event (Gdk.EventKey event)
    {
        var top = stack.top ();

        if (stack.top () is UserList)
        {
            var user_list = stack.top () as UserList;
            var shift_mask = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK;
            var control_mask = Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.MOD1_MASK;
            var alt_mask = Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK;
            if (((event.keyval == Gdk.Key.Shift_L || event.keyval == Gdk.Key.Shift_R) && (event.state & shift_mask) == shift_mask) ||
                ((event.keyval == Gdk.Key.Control_L || event.keyval == Gdk.Key.Control_R) && (event.state & control_mask) == control_mask) ||
                ((event.keyval == Gdk.Key.Alt_L || event.keyval == Gdk.Key.Alt_R) && (event.state & alt_mask) == alt_mask))
            {
                debug ("Hidden user key combination detected");
                user_list.show_hidden_users = ! user_list.show_hidden_users;
                return true;
            }
        }
        else if (stack.top () is SessionList) {
            // Session list is open
            switch (event.keyval) {
                case Gdk.Key.Escape:
                case Gdk.Key.Left:
                case Gdk.Key.KP_Left:
                    pop_list();
                    return true;
            }
        }

        var greeter = new ArcticaGreeter ();
        switch (event.keyval)
        {
        case Gdk.Key.Escape:
            if (login_box.sensitive)
                top.cancel_authentication ();
            if (shutdown_dialog != null)
                shutdown_dialog.cancel ();
            return true;
        case Gdk.Key.Page_Up:
        case Gdk.Key.KP_Page_Up:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.START);
            return true;
        case Gdk.Key.Page_Down:
        case Gdk.Key.KP_Page_Down:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.END);
            return true;
        case Gdk.Key.Up:
        case Gdk.Key.KP_Up:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.UP);
            return true;
        case Gdk.Key.Down:
        case Gdk.Key.KP_Down:
            if (login_box.sensitive)
                top.scroll (GreeterList.ScrollTarget.DOWN);
            return true;
        case Gdk.Key.F10:
            if (login_box.sensitive)
                menubar.select_first (false);
            return true;
        case Gdk.Key.PowerOff:
            show_shutdown_dialog (ShutdownDialogType.SHUTDOWN);
            return true;
        case Gdk.Key.Print:
            debug ("Taking screenshot");
            var root = Gdk.get_default_root_window ();
            var screenshot = Gdk.pixbuf_get_from_window (root, 0, 0, root.get_width (), root.get_height ());
            try
            {
                screenshot.save ("Screenshot.png", "png", null);
            }
            catch (Error e)
            {
                warning ("Failed to save screenshot: %s", e.message);
            }
            return true;
        case Gdk.Key.z:
            if (greeter.test_mode && (event.state & Gdk.ModifierType.MOD1_MASK) != 0)
            {
                show_shutdown_dialog (ShutdownDialogType.SHUTDOWN);
                return true;
            }
            break;
        case Gdk.Key.Z:
            if (greeter.test_mode && (event.state & Gdk.ModifierType.MOD1_MASK) != 0)
            {
                show_shutdown_dialog (ShutdownDialogType.RESTART);
                return true;
            }
            break;

        case Gdk.Key.k:

            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
            {
                bool bActive = AGSettings.get_boolean (AGSettings.KEY_ONSCREEN_KEYBOARD);

                try
                {
                    DBusConnection pConnection = Bus.get_sync (BusType.SESSION);
                    Variant pActive = new Variant.boolean (!bActive);
                    Variant pTuple = new Variant("(sva{sv})", "onboard", pActive, null);
                    pConnection.call.begin ("org.ayatana.indicator.a11y", "/org/ayatana/indicator/a11y", "org.gtk.Actions", "SetState", pTuple, null, DBusCallFlags.NONE, -1, null);
                }
                catch (Error pError)
                {
                    warning ("%s", pError.message);
                }

                return true;
            }

            break;

        case Gdk.Key.h:

            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
            {
                AGSettings pSettings = new AGSettings ();
                bool bActive = pSettings.high_contrast;

                try
                {
                    DBusConnection pConnection = Bus.get_sync (BusType.SESSION);
                    Variant pActive = new Variant.boolean (!bActive);
                    Variant pTuple = new Variant("(sva{sv})", "contrast", pActive, null);
                    pConnection.call.begin ("org.ayatana.indicator.a11y", "/org/ayatana/indicator/a11y", "org.gtk.Actions", "SetState", pTuple, null, DBusCallFlags.NONE, -1, null);
                }
                catch (Error pError)
                {
                    warning ("%s", pError.message);
                }

                return true;
            }

            break;

        case Gdk.Key.s:

            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
            {
                bool bActive = AGSettings.get_boolean (AGSettings.KEY_SCREEN_READER);

                try
                {
                    DBusConnection pConnection = Bus.get_sync (BusType.SESSION);
                    Variant pActive = new Variant.boolean (!bActive);
                    Variant pTuple = new Variant("(sva{sv})", "orca", pActive, null);
                    pConnection.call.begin ("org.ayatana.indicator.a11y", "/org/ayatana/indicator/a11y", "org.gtk.Actions", "SetState", pTuple, null, DBusCallFlags.NONE, -1, null);
                }
                catch (Error pError)
                {
                    warning ("%s", pError.message);
                }

                return true;
            }

            break;

        case Gdk.Key.m:

            if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
            {
                bool bActive = AGSettings.get_boolean (AGSettings.KEY_MAGNIFIER);

                try
                {
                    DBusConnection pConnection = Bus.get_sync (BusType.SESSION);
                    Variant pActive = new Variant.boolean (!bActive);
                    Variant pTuple = new Variant("(sva{sv})", "magnifier", pActive, null);
                    pConnection.call.begin ("org.ayatana.indicator.a11y", "/org/ayatana/indicator/a11y", "org.gtk.Actions", "SetState", pTuple, null, DBusCallFlags.NONE, -1, null);
                }
                catch (Error pError)
                {
                    warning ("%s", pError.message);
                }

                return true;
            }

            break;
        }

        return base.key_press_event (event);
    }

    public void show_shutdown_dialog (ShutdownDialogType type)
    {
        if (shutdown_dialog != null)
            shutdown_dialog.destroy ();

        /* Stop input to login box */
        login_box.sensitive = false;

        shutdown_dialog = new ShutdownDialog (type, background);
        shutdown_dialog.closed.connect (close_shutdown_dialog);
        background.add (shutdown_dialog);
        move_to_monitor (active_monitor);
        shutdown_dialog.visible = true;
    }

    public void close_shutdown_dialog ()
    {
        if (shutdown_dialog == null)
            return;

        shutdown_dialog.destroy ();
        shutdown_dialog = null;

        login_box.sensitive = true;
    }
}
