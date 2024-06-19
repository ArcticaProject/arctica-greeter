/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011 Canonical Ltd
 * Copyright (C) 2015-2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 * Copyright (C) 2023-2024 Robert Tari
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
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 *          Robert Tari <robert@tari.in>
 */

public const int grid_size = 40;

[SingleInstance]
public class ArcticaGreeter : Object
{
    public signal void show_message (string text, LightDM.MessageType type);
    public signal void show_prompt (string text, LightDM.PromptType type);
    public signal void authentication_complete ();
    public signal void starting_session ();
    public MainWindow main_window { get; private set; default = null; }
    public Gtk.Window? pKeyboardWindow { get; set; default = null; }
    public Gtk.Window? pMagnifierWindow { get; set; default = null; }
    public bool test_mode { get; construct; default = false; }
    public bool test_highcontrast { get; construct; default = false; }

    // Menubar is smaller, but with shadow, we reserve more space
    public const int MENUBAR_HEIGHT = 40;

    private string state_file;
    private KeyFile state;
    private DBusServer pServer;
    private Cairo.XlibSurface background_surface;
    private SettingsDaemon settings_daemon;

    public bool orca_needs_kick;

    private LightDM.Greeter greeter;

    private Canberra.Context canberra_context;

    private static Timer log_timer;

    private DialogDBusInterface dbus_object;
    private SettingsDaemonDBusInterface  settings_daemon_proxy;
    public signal void xsettings_ready ();
    public signal void greeter_ready ();

    public List<Pid> indicator_service_pids;
    Pid notificationdaemon_pid = 0;
    Pid windowmanager_pid = 0;

    construct
    {
        Bus.own_name (BusType.SESSION, "org.ayatana.greeter", BusNameOwnerFlags.NONE, onBusAcquired);
        greeter = new LightDM.Greeter ();
        greeter.show_message.connect ((text, type) => { show_message (text, type); });

        greeter.show_prompt.connect ((text, type) =>
        {
            show_prompt (text, type);
        });

        greeter.autologin_timer_expired.connect (() => {
            try
            {
                greeter.authenticate_autologin ();
            }
            catch (Error e)
            {
                warning ("Failed to autologin authenticate: %s", e.message);
            }
        });
        greeter.authentication_complete.connect (() => { authentication_complete (); });
        var connected = false;
        try
        {
            connected = greeter.connect_to_daemon_sync ();
        }
        catch (Error e)
        {
            warning ("Failed to connect to LightDM daemon: %s", e.message);
        }
        if (!connected && !test_mode)
            Posix.exit (Posix.EXIT_FAILURE);

        if (!test_mode)
        {
            settings_daemon = new SettingsDaemon ();
            settings_daemon.start ();
        }

        var state_dir = Path.build_filename (Environment.get_user_cache_dir (), "arctica-greeter");
        DirUtils.create_with_parents (state_dir, 0775);

        var xdg_seat = GLib.Environment.get_variable("XDG_SEAT");
        var state_file_name = xdg_seat != null && xdg_seat != "seat0" ? xdg_seat + "-state" : "state";

        state_file = Path.build_filename (state_dir, state_file_name);
        state = new KeyFile ();
        if (FileUtils.test (state_file, FileTest.EXISTS)) {
            try
            {
                state.load_from_file (state_file, KeyFileFlags.NONE);
            }
            catch (Error e)
            {
                if (!(e is FileError.NOENT))
                    warning ("Failed to load state from %s: %s\n", state_file, e.message);
            }
        }
        else {
            debug ("State file does not (yet) exist: %s\n", state_file);
        }
    }

    /*
     * Note that we need a way to specify a parameter for the initial instance
     * creation of the singleton, but also a constructor that takes no
     * parameters for later usage.
     *
     * Making the parameter optional is a good compromise.
     *
     * This parameter is construct-only, initializing it by passing it to the
     * GObject constructor is both the correct way to do it, and it will
     * additionally avoid changing it in later calls of our constructor.
     */
    public ArcticaGreeter (bool test_mode_ = false,
                           bool test_highcontrast_ = false)
    {
        Object (test_mode: test_mode_,
                test_highcontrast: test_highcontrast_
        );
    }

    public DBusServer getDBusServer ()
    {
        return this.pServer;
    }

    private void onBusAcquired (DBusConnection pConnection)
    {
        try
        {
            this.pServer = new DBusServer (pConnection, this);
            pConnection.register_object ("/org/ayatana/greeter", this.pServer);
        }
        catch (IOError pError)
        {
            error ("%s\n", pError.message);
        }
    }

    public void go ()
    {
        /* Render things after xsettings is ready */
        xsettings_ready.connect ( xsettings_ready_cb );

        if (!test_mode) {

            GLib.Bus.watch_name (BusType.SESSION, "org.mate.SettingsDaemon", BusNameWatcherFlags.NONE,
                                 (c, name, owner) =>
                                 {
                                    try {
                                        settings_daemon_proxy = GLib.Bus.get_proxy_sync (
                                            BusType.SESSION, "org.mate.SettingsDaemon", "/org/mate/SettingsDaemon");
                                        settings_daemon_proxy.plugin_activated.connect (
                                            (name) =>
                                            {
                                                if (name == "xsettings") {
                                                    debug ("xsettings is ready");
                                                    xsettings_ready ();
                                                } else {
                                                    debug ("settings-daemon plugin %s loaded", name);
                                                }
                                            }
                                        );
                                    }
                                    catch (Error e)
                                    {
                                        debug ("Failed to get MSD proxy, proceed anyway");
                                        xsettings_ready ();
                                    }
                                },
                                null);
        }
        else
        {
            xsettings_ready ();
        }
    }

    public string? get_state (string key)
    {
        try
        {
            return state.get_value ("greeter", key);
        }
        catch (Error e)
        {
            return null;
        }
    }

    public void set_state (string key, string value)
    {
        if (key == "last-user")
        {
            try
            {
                this.pServer.sendUserChange (value);
            }
            catch (Error pError)
            {
                error ("Panic: %s", pError.message);
            }
        }

        state.set_value ("greeter", key, value);
        var data = state.to_data ();
        try
        {
            FileUtils.set_contents (state_file, data);
        }
        catch (Error e)
        {
            debug ("Failed to write state: %s", e.message);
        }
    }

    public void push_list (GreeterList widget)
    {
        main_window.push_list (widget);
    }

    public void pop_list ()
    {
        main_window.pop_list ();
    }

    public static void add_style_class (Gtk.Widget widget)
    {
        /* Add style context class lightdm-user-list */
        var ctx = widget.get_style_context ();
        ctx.add_class ("lightdm");
    }

    public string? get_default_session ()
    {
        var available_sessions = new List<string> ();
        var hide_default_xsession = AGSettings.get_boolean (AGSettings.KEY_HIDE_DEFAULT_XSESSION);

        /* Debian/Ubuntu style of defining the default xsession.
         */
        if (!hide_default_xsession) {
            var default_session_path_suse = Path.build_filename  ("/usr/share/xsessions/default.desktop", null);
            var default_session_path_deb = Path.build_filename  ("/usr/share/xsessions/lightdm-xsession.desktop", null);
            if (FileUtils.test (default_session_path_suse, FileTest.EXISTS)) {
                /* openSUSE/SLED style of defining the default xsession.
                 */
                available_sessions.append ("default");
            }
            else if (FileUtils.test (default_session_path_deb, FileTest.EXISTS)) {
                /* Debian/Ubuntu style of defining the default xsession.
                 */
                available_sessions.append ("lightdm-xsession");
            }
        }

        var preferred_sessions = AGSettings.get_strv (AGSettings.KEY_PREFERRED_SESSIONS);
        if (preferred_sessions.length > 0) {
            foreach (var preferred_session in preferred_sessions) {
                available_sessions.append (preferred_session);
            }

            var excluded_sessions = AGSettings.get_strv (AGSettings.KEY_EXCLUDED_SESSIONS);
            var includeonly_sessions = AGSettings.get_strv (AGSettings.KEY_INCLUDEONLY_SESSIONS);

            if (!AGSettings.get_boolean (AGSettings.KEY_HIDE_WAYLAND_SESSIONS)) {
                foreach (string session in available_sessions) {
                    if (includeonly_sessions.length > 0) {
                        if (!(session in includeonly_sessions)) {
                            continue;
                        }
                    }
                    else if (session in excluded_sessions) {
                        continue;
                    }
                    var path = Path.build_filename  ("/usr/share/wayland-sessions/", session.concat(".desktop"), null);
                    if (FileUtils.test (path, FileTest.EXISTS)) {
                        debug ("Using %s as default (Wayland) session.", session);
                        return session;
                    }
                }
            }

            if (!AGSettings.get_boolean (AGSettings.KEY_HIDE_X11_SESSIONS)) {
                foreach (string session in available_sessions) {
                    if (includeonly_sessions.length > 0) {
                        if (!(session in includeonly_sessions)) {
                            continue;
                        }
                    }
                    else if (session in excluded_sessions) {
                        continue;
                    }
                    var path = Path.build_filename  ("/usr/share/xsessions/", session.concat(".desktop"), null);
                    if (FileUtils.test (path, FileTest.EXISTS)) {
                        debug ("Using %s as default (X11) session.", session);
                        return session;
                    }
                }
            }

            warning ("Could not find a default session. Falling back to LightDM's system default.");
        }

        warning ("Using default session '%s' as configured as LightDM's system default.", greeter.default_session_hint);
        return greeter.default_session_hint;
    }

    public string validate_session (string? session, bool? fallback = true)
    {
        /* Make sure the given session actually exists. Return it if it does.
         * otherwise, return the default session.
         */
        var excluded_sessions = AGSettings.get_strv (AGSettings.KEY_EXCLUDED_SESSIONS);
        var includeonly_sessions = AGSettings.get_strv (AGSettings.KEY_INCLUDEONLY_SESSIONS);

        if (includeonly_sessions.length > 0)
        {
            if (!(session in includeonly_sessions))
            {
                session = null;
            }
        }
        else if (session in excluded_sessions)
        {
            session = null;
        }

        if (session != null)
        {
            var xsessions_path = Path.build_filename  ("/usr/share/xsessions/", session.concat(".desktop"), null);
            var wsessions_path = Path.build_filename  ("/usr/share/wayland-sessions/", session.concat(".desktop"), null);

            if ((session == "lightdm-xsession") &&
                AGSettings.get_boolean (AGSettings.KEY_HIDE_DEFAULT_XSESSION))
            {
                debug ("default Xsession hidden: '%s'", session);
                session = null;
            }
            else if (AGSettings.get_boolean (AGSettings.KEY_HIDE_WAYLAND_SESSIONS) &&
                FileUtils.test (wsessions_path, FileTest.EXISTS))
            {
                debug ("Wayland session hidden: '%s'", session);
                session = null;
            }
            else if (AGSettings.get_boolean (AGSettings.KEY_HIDE_X11_SESSIONS) &&
                FileUtils.test (xsessions_path, FileTest.EXISTS))
            {
                debug ("X11 session hidden: '%s'", session);
                session = null;
            }
            else if (!FileUtils.test (xsessions_path, FileTest.EXISTS) &&
                     !FileUtils.test (wsessions_path, FileTest.EXISTS))
            {
                debug ("Invalid session: '%s'", session);
                session = null;
            }
        }

        if ((fallback == true) && (session == null))
        {
            var default_session = get_default_session ();
            debug ("Invalid session: '%s'. Using session '%s' instead.", session, default_session);
            return default_session;
        }

        return session;
    }

    public bool start_session (string? session, Background bg)
    {
        /* Explicitly set the right scale before closing window */
        var display = Gdk.Display.get_default();
        var monitor = display.get_primary_monitor();
        var scale = monitor.get_scale_factor ();
        var _session = session;
        background_surface.set_device_scale (scale, scale);

        if (test_mode)
        {
            debug ("Successfully logged in! Quitting...");
            Gtk.main_quit ();
            return true;
        }

        if (!session_is_valid (_session))
        {
            debug ("Session %s is not available, using system default %s instead", _session, default_session_hint());
            _session = default_session_hint();
        }

        var result = false;
        try
        {
            result = LightDM.greeter_start_session_sync (greeter, _session);
        }
        catch (Error e)
        {
            warning ("Failed to start session: %s", e.message);
        }

        if (result)
            starting_session ();

        return result;
    }

    private bool session_is_valid (string? session)
    {
        if (session == null)
            return true;

        foreach (var s in LightDM.get_sessions ())
            if (s.key == session)
                return true;

        return false;
    }

    private bool ready_cb ()
    {
        debug ("starting system-ready sound");

        /* Launch canberra */
        Canberra.Context.create (out canberra_context);

        if (AGSettings.get_boolean (AGSettings.KEY_PLAY_READY_SOUND))
            canberra_context.play (0,
                                   Canberra.PROP_CANBERRA_XDG_THEME_NAME,
                                   "arctica-greeter",
                                   Canberra.PROP_EVENT_ID,
                                   "system-ready");

        /* Synchronize properties in AGSettings once. */
        var agsettings = new AGSettings ();
        if (!test_mode) {
            agsettings.high_contrast = !(!(agsettings.high_contrast));
        } else {
            agsettings.high_contrast = test_highcontrast;
        }

        /*
         * Add timeouts to process the full node hierarchy to handle a11y
         * changes.
         *
         * That's the easiest way to handle a changing node hierarchy.
         *
         * Alternatives would involve connecting a function for every a11y
         * change to the GtkWidget::parent-set event to *every widget* we
         * create, but that would make the code incredibly messy.
         *
         * The value has been determined by a fair dice roll and should make
         * sure that changes are visible almost instantaneously to users.
         */
        Timeout.add_full (GLib.Priority.HIGH_IDLE, 302, () => {
            var agsettings_intimer = new AGSettings ();
            /*
            if (0 == GLib.Random.int_range (0, 10)) {
                debug ("Syncing up high contrast value via timer: %s", agsettings_intimer.high_contrast.to_string ());
            }
            */
            switch_contrast (agsettings_intimer.high_contrast);

            return true;
        });

        return false;
    }

    public void show ()
    {
        debug ("Showing main window");
        if (!test_mode)
            main_window.set_decorated (false);
        main_window.set_keep_below (true);
        main_window.realize ();
        main_window.setup_window ();
        main_window.show ();
        main_window.get_window ().focus (Gdk.CURRENT_TIME);

        try
        {
            /* Initialize OSK and screen reader as configured in gsettings. */
            this.pServer.ToggleOrca (AGSettings.get_boolean(AGSettings.KEY_SCREEN_READER));
            this.pServer.ToggleOnBoard (AGSettings.get_boolean(AGSettings.KEY_ONSCREEN_KEYBOARD));
        }
        catch (Error pError)
        {
            error ("%s\n", pError.message);
        }
    }

    public bool is_authenticated ()
    {
        return greeter.is_authenticated;
    }

    public void authenticate (string? userid = null)
    {
        try
        {
            greeter.authenticate (userid);
        }
        catch (Error e)
        {
            warning ("Failed to authenticate: %s", e.message);
        }
    }

    public void authenticate_as_guest ()
    {
        try
        {
            greeter.authenticate_as_guest ();
        }
        catch (Error e)
        {
            warning ("Failed to authenticate as guest: %s", e.message);
        }
    }

    public void authenticate_remote (string? session, string? userid)
    {
        try
        {
            greeter.authenticate_remote (session, userid);
        }
        catch (Error e)
        {
            warning ("Failed to remote authenticate: %s", e.message);
        }
    }

    public void cancel_authentication ()
    {
        try
        {
            greeter.cancel_authentication ();
        }
        catch (Error e)
        {
            warning ("Failed to cancel authentication: %s", e.message);
        }
    }

    public void respond (string response)
    {
        try
        {
            greeter.respond (response);
        }
        catch (Error e)
        {
            warning ("Failed to respond: %s", e.message);
        }
    }

    public string authentication_user ()
    {
        return greeter.authentication_user;
    }

    public string default_session_hint ()
    {
        return greeter.default_session_hint;
    }

    public string select_user_hint ()
    {
        return greeter.select_user_hint;
    }

    public bool show_manual_login_hint ()
    {
        return greeter.show_manual_login_hint;
    }

    public bool show_remote_login_hint ()
    {
        return greeter.show_remote_login_hint;
    }

    public bool hide_users_hint ()
    {
        return greeter.hide_users_hint;
    }

    public bool has_guest_account_hint ()
    {
        return greeter.has_guest_account_hint;
    }

    private delegate void SwitchClassType (Gtk.Widget widget, string classname, bool enable);

    private delegate void IterateChildrenType (Gtk.Widget widget);

    private void switch_generic (Gtk.Widget widget, string classname, bool enable)
    {
        var style_ctx = widget.get_style_context ();
        if (enable)
        {
            style_ctx.add_class (classname);
        }
        else
        {
            style_ctx.remove_class (classname);
        }
    }

    private void iterate_children_generic (Gtk.Widget widget, SwitchClassType switch_func, string classname, bool enable)
    {
        /*
         * GTK 4 changed its API quite dramatically, got rid of GtkContainer
         * and made each GtkWidget accept children, while also defining a new
         * way to access those.
         */
        IterateChildrenType rec_func = null;
        rec_func = (widget) => {
#if HAVE_GTK_4_0
            Gtk.Widget child = widget.get_first_child ();
            while (null != child)
            {
                rec_func (child);
                child = child.get_next_sibling ();
            }
#else
            if (gtk_is_container (widget))
            {
                ((Gtk.Container)(widget)).@foreach (rec_func);
            }
#endif

            /* Common code to add or remove the CSS class. */
            switch_func (widget, classname, enable);
        };

        /*
         * Actually recursively iterate through this item and all of its
         * children.
         */
        rec_func (widget);
    }

    public void switch_contrast (bool high)
    {
        var time_pre = GLib.get_monotonic_time ();
        iterate_children_generic (main_window, switch_generic, "high_contrast", high);
        var time_post = GLib.get_monotonic_time ();
        var time_diff = time_post - time_pre;
        assert (0 <= time_diff);
        // var time_diff_sec = time_diff / 1000000;
        // var time_diff_msec = time_diff / 1000;
        // var time_diff_usec = time_diff % 1000000;
        // debug ("Time passed: %" + int64.FORMAT + " s, %" + int64.FORMAT + " ms, %" + int64.FORMAT + " us", time_diff_sec, time_diff_msec, time_diff_usec);
    }

    private Gdk.FilterReturn focus_upon_map (Gdk.XEvent gxevent, Gdk.Event event)
    {
        var xevent = (X.Event*)gxevent;
        if (xevent.type == X.EventType.MapNotify)
        {
            var display = Gdk.X11.Display.lookup_for_xdisplay (xevent.xmap.display);
            var xwin = xevent.xmap.window;
            var win = new Gdk.X11.Window.foreign_for_display (display, xwin);
            if (win != null && !xevent.xmap.override_redirect)
            {
                /* Check to see if this window is our onboard window, since we don't want to focus it. */
                X.Window keyboard_xid = 0;
                if (this.pKeyboardWindow != null)
                {
                    Gdk.X11.Window pWindow = (Gdk.X11.Window) this.pKeyboardWindow.get_window ();
                    keyboard_xid = pWindow.get_xid ();
                }

                // Now check to see if this is the magnifier - no focus for it, either
                X.Window nMagnifier = 0;
                if (this.pMagnifierWindow != null)
                {
                    Gdk.X11.Window pWindow = (Gdk.X11.Window) this.pMagnifierWindow.get_window ();
                    nMagnifier = pWindow.get_xid ();
                }

                if (xwin != keyboard_xid && xwin != nMagnifier && win.get_type_hint() != Gdk.WindowTypeHint.NOTIFICATION)
                {
                    win.set_keep_below (true);
                    win.focus (Gdk.CURRENT_TIME);

                    /* Make sure to keep keyboard above */
                    if (this.pKeyboardWindow != null)
                        this.pKeyboardWindow.get_window ().raise ();

                    // And the magnifier on top of everything
                    if (this.pMagnifierWindow != null)
                    {
                        this.pMagnifierWindow.get_window ().raise ();
                    }
                }
            }
        }
        else if (xevent.type == X.EventType.UnmapNotify)
        {
            // Since we aren't keeping track of focus (for example, we don't
            // track the Z stack of windows) like a normal WM would, when we
            // decide here where to return focus after another window unmaps,
            // we don't have much to go on.  X will tell us if we should take
            // focus back.  (I could not find an obvious way to determine this,
            // but checking if the X input focus is RevertTo.None seems
            // reliable.)

            X.Window xwin;
            int revert_to;
            xevent.xunmap.display.get_input_focus (out xwin, out revert_to);

            if (revert_to == X.RevertTo.None)
            {
                main_window.get_window ().focus (Gdk.CURRENT_TIME);

                /* Make sure to keep keyboard above */
                if (this.pKeyboardWindow != null)
                    this.pKeyboardWindow.get_window ().raise ();

                // And the magnifier on top of everything
                if (this.pMagnifierWindow != null)
                {
                    this.pMagnifierWindow.get_window ().raise ();
                }
            }
        }
        return Gdk.FilterReturn.CONTINUE;
    }

    private void start_fake_wm ()
    {
        /* We want new windows (e.g. the shutdown dialog) to gain focus.
           We don't really need anything more than that (don't need alt-tab
           since any dialog should be "modal" or at least dealt with before
           continuing even if not actually marked as modal) */
        var root = Gdk.get_default_root_window ();
        root.set_events (root.get_events () | Gdk.EventMask.SUBSTRUCTURE_MASK);
        root.add_filter (focus_upon_map);
    }

    private void kill_fake_wm ()
    {
        var root = Gdk.get_default_root_window ();
        root.remove_filter (focus_upon_map);
    }

    private static Cairo.XlibSurface? create_root_surface (Gdk.Screen screen)
    {
        var visual = screen.get_system_visual ();
        Gdk.X11.Display pDisplay = (Gdk.X11.Display) screen.get_display ();
        unowned X.Display display = pDisplay.get_xdisplay ();
        Gdk.X11.Screen pScreen = (Gdk.X11.Screen) screen;
        unowned X.Screen xscreen = pScreen.get_xscreen ();

        var pixmap = X.CreatePixmap (display,
                                     ((Gdk.X11.Window) (screen.get_root_window ())).get_xid (),
                                     xscreen.width_of_screen (),
                                     xscreen.height_of_screen (),
                                     visual.get_depth ());

        /* Convert into a Cairo surface */
        Gdk.X11.Visual pVisual = (Gdk.X11.Visual) visual;
        var surface = new Cairo.XlibSurface (display,
                                             pixmap,
                                             pVisual.get_xvisual (),
                                             xscreen.width_of_screen (), xscreen.height_of_screen ());

        return surface;
    }

    private static void log_cb (string? log_domain, LogLevelFlags log_level, string message)
    {
        string prefix;
        switch (log_level & LogLevelFlags.LEVEL_MASK)
        {
        case LogLevelFlags.LEVEL_ERROR:
            prefix = "ERROR:";
            break;
        case LogLevelFlags.LEVEL_CRITICAL:
            prefix = "CRITICAL:";
            break;
        case LogLevelFlags.LEVEL_WARNING:
            prefix = "WARNING:";
            break;
        case LogLevelFlags.LEVEL_MESSAGE:
            prefix = "MESSAGE:";
            break;
        case LogLevelFlags.LEVEL_INFO:
            prefix = "INFO:";
            break;
        case LogLevelFlags.LEVEL_DEBUG:
            prefix = "DEBUG:";
            break;
        default:
            prefix = "LOG:";
            break;
        }

        stderr.printf ("[%+.2fs] %s %s\n", log_timer.elapsed (), prefix, message);
    }

    private void xsettings_ready_cb ()
    {
        /* Prepare to set the background */
        debug ("Creating background surface");
        background_surface = create_root_surface (Gdk.Screen.get_default ());

        main_window = new MainWindow ();

        main_window.destroy.connect(() => {
            stop_real_wm ();
            kill_fake_wm ();
        });
        main_window.delete_event.connect(() =>
        {
            Gtk.main_quit();
            return false;
        });

        if (!test_mode) {
            Bus.own_name (BusType.SESSION, "com.lomiri.LomiriGreeter", BusNameOwnerFlags.NONE);

            dbus_object = new DialogDBusInterface ();
            dbus_object.open_dialog.connect ((type) =>
            {
                ShutdownDialogType dialog_type;
                switch (type)
                {
                default:
                case 1:
                    dialog_type = ShutdownDialogType.SHUTDOWN;
                    break;
                case 2:
                    dialog_type = ShutdownDialogType.RESTART;
                    break;
                }
                main_window.show_shutdown_dialog (dialog_type);
            });
            dbus_object.close_dialog.connect ((type) => { main_window.close_shutdown_dialog (); });
            Bus.own_name (BusType.SESSION, "com.lomiri.Shell", BusNameOwnerFlags.NONE,
                          (c) =>
                          {
                              try
                              {
                                  c.register_object ("/org/gnome/SessionManager/EndSessionDialog", dbus_object);
                              }
                              catch (Error e)
                              {
                                  warning ("Failed to register /org/gnome/SessionManager/EndSessionDialog: %s", e.message);
                              }
                          },
                          null,
                          () => debug ("Failed to acquire name com.lomiri.Shell"));
        }

        start_real_wm ();
        start_fake_wm ();
        Gdk.threads_add_idle (ready_cb);
        greeter_ready ();
    }

    private static void set_keyboard_layout ()
    {

        /* Avoid expensive Python execution where possible */
        if (!FileUtils.test("/etc/default/keyboard", FileTest.EXISTS)) {
            return;
        }

        try {
            Process.spawn_command_line_sync(Path.build_filename (Config.PKGLIBEXECDIR, "arctica-greeter-set-keyboard-layout"), null, null, null);
        }
        catch (Error e){
            warning ("Error while setting the keyboard layout: %s", e.message);
        }
    }

    private static void enable_tap_to_click ()
    {
        try {
            Process.spawn_command_line_sync(Path.build_filename (Config.PKGLIBEXECDIR, "arctica-greeter-enable-tap-to-click"), null, null, null);
        }
        catch (Error e){
            warning ("Error while enabling tap-to-click: %s", e.message);
        }
    }

    private static void activate_numlock ()
    {
        try {
            Process.spawn_command_line_sync("/usr/bin/numlockx on", null, null, null);
        }
        catch (Error e){
            warning ("Error while activating numlock: %s", e.message);
        }
    }

    private static void activate_upower ()
    {
        /* hacky approach, but does what's needed: activate the upower service over DBus */
        try {
            Process.spawn_command_line_sync("/usr/bin/upower --version", null, null, null);
        }
        catch (Error e){
            warning ("Error while triggering UPower activation: %s", e.message);
        }
    }

    private static int check_hidpi ()
    {
        int ret = 1;

        try {
            string output;
            Process.spawn_command_line_sync(Path.build_filename (Config.PKGLIBEXECDIR, "arctica-greeter-check-hidpi"), out output, null, null);
            ret = int.parse (output);
            debug ("Auto-detected scaling factor in check_hidpi(): %d", ret);
        }
        catch (Error e){
            warning ("Error while setting HiDPI support: %s", e.message);
        }

        /*
         * Make sure that the value lies in the range of 0 < x <= 5.
         *
         * GDK only knows integer-based scaling factors and anything above 2
         * is highly unusual. Anything above 5 is most likely an error (at the
         * time of writing this code; we might want to respect this in the
         * future).
         * A scaling factor of 0 doesn't make sense, as is the case with
         * negative values.
         */
        if ((1 > ret) || (5 < ret))
        {
            /* Fallback value for GDK scaling */
            debug ("Scaling factor out of range, defaulting to 1");
            ret = 1;
        }

        return ret;
    }

    public void start_indicators ()
    {
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

        if (!test_mode)
        {
            var indicator_service = "";
            foreach (unowned string indicator in indicator_list)
            {
                Pid indicator_service_pid = 0;

                if ("ug-" in indicator && ! ("." in indicator))
                    continue;

                if ("org.ayatana.indicator." in indicator)
                    indicator_service = "ayatana-indicator-%s".printf(indicator.split_set(".")[3]);
                else if ("ayatana-" in indicator)
                    indicator_service = "ayatana-indicator-%s".printf(indicator.split_set("-")[1]);
                else
                    indicator_service = indicator;

                try {
                    /* Start the indicator service */
                    string[] argv = null;

                    /* FIXME: This path is rather hard-coded here.
                     * If it pops up, we need to handle this in
                     * some path detection fashion similar to
                     * how we find at-spi-bus-launcher on the file
                     * system.
                     */
                    if (FileUtils.test ("/usr/lib/%s/%s-service".printf(indicator_service, indicator_service), FileTest.EXISTS))
                        Shell.parse_argv ("/usr/lib/%s/%s-service".printf(indicator_service, indicator_service), out argv);
                    else if (FileUtils.test ("/usr/libexec/%s/%s-service".printf(indicator_service, indicator_service), FileTest.EXISTS))
                        Shell.parse_argv ("/usr/libexec/%s/%s-service".printf(indicator_service, indicator_service), out argv);
                    if (argv != null)
                    {
                        Process.spawn_async (null,
                                             argv,
                                             null,
                                         SpawnFlags.SEARCH_PATH,
                                         null,
                                         out indicator_service_pid);
                        indicator_service_pids.append(indicator_service_pid);
                        debug ("Successfully started Ayatana Indicator Service '%s' [%d]", indicator_service, indicator_service_pid);
                    }
                    else
                    {
                        warning ("Could not find indicator service executable for Indicator Service '%s'", indicator_service);
                    }
                }
                catch (Error e)
                {
                    warning ("Error starting Indicator Service '%s': %s", indicator_service, e.message);
                }

            }
        }
    }

    public void stop_indicators ()
    {
        foreach (unowned Pid indicator_service_pid in indicator_service_pids)
        {
            if (indicator_service_pid != 0)
            {
#if VALA_0_40
                Posix.kill (indicator_service_pid, Posix.Signal.TERM);
#else
                Posix.kill (indicator_service_pid, Posix.SIGTERM);
#endif

                int status;
                Posix.waitpid (indicator_service_pid, out status, 0);
                if (Process.if_exited (status))
                    debug ("Indicator Service process [%d] exited with return value %d", indicator_service_pid, Process.exit_status (status));
                else
                    debug ("Indicator Service process [%d] terminated with signal %d", indicator_service_pid, Process.term_sig (status));
                indicator_service_pid = 0;
            }
        }
    }

    public void start_notification_daemon ()
    {
        try
        {
            string[] argv = null;

            if (FileUtils.test ("/usr/lib/mate-notification-daemon/mate-notification-daemon", FileTest.EXISTS)) {
                Shell.parse_argv ("/usr/lib/mate-notification-daemon/mate-notification-daemon --replace", out argv);
            }
            else if (FileUtils.test ("/usr/libexec/mate-notification-daemon/mate-notification-daemon", FileTest.EXISTS)) {
                Shell.parse_argv ("/usr/libexec/mate-notification-daemon/mate-notification-daemon --replace", out argv);
            }
            if (argv != null)
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out notificationdaemon_pid);
            debug ("Launched mate-notification-daemon. PID: %d", notificationdaemon_pid);
        }
        catch (Error e)
        {
            warning ("Error starting the mate-notification-daemon registry: %s", e.message);
        }
    }

    public void stop_notification_daemon ()
    {
        if (notificationdaemon_pid != 0)
        {
#if VALA_0_40
            Posix.kill (notificationdaemon_pid, Posix.Signal.KILL);
#else
            Posix.kill (notificationdaemon_pid, Posix.SIGKILL);
#endif
            int status;
            Posix.waitpid (notificationdaemon_pid, out status, 0);
            if (Process.if_exited (status))
                debug ("mate-notification-daemon exited with return value %d", Process.exit_status (status));
            else
                debug ("mate-notification-daemon terminated with signal %d", Process.term_sig (status));
            notificationdaemon_pid = 0;
        }
    }

    public void start_real_wm ()
    {
        string wm = AGSettings.get_string (AGSettings.KEY_WINDOW_MANAGER);
        if ((wm == "metacity") || (wm == "marco"))
        {
            try
            {
                string[] argv;

                Shell.parse_argv (wm, out argv);
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out windowmanager_pid);
                debug ("Launched '%s' WM. PID: %d", wm, windowmanager_pid);
            }
            catch (Error e)
            {
                warning ("Error starting the '%s' Window Manager: %s", wm, e.message);
            }

            Timeout.add (50, () =>
                {
                    try
                    {
                        string[] argv;
                        Pid wm_message_pid = 0;

                        Shell.parse_argv ("%s-message disable-keybindings".printf(wm), out argv);

                        Process.spawn_sync (null,
                                            argv,
                                            null,
                                            SpawnFlags.SEARCH_PATH,
                                            null,
                                            null,
                                            null,
                                            null);
                        debug ("Launched '%s-message disable-keybindings' command", wm);
                        return false;
                    }
                    catch (Error e)
                    {
                        warning ("Error during '%s-message disable-keybindings' command call: %s", wm, e.message);
                        return true;
                    }
                });
        }
    }

    public void stop_real_wm ()
    {
        if (windowmanager_pid != 0)
        {
#if VALA_0_40
            Posix.kill (windowmanager_pid, Posix.Signal.TERM);
#else
            Posix.kill (windowmanager_pid, Posix.SIGTERM);
#endif
            int status;
            Posix.waitpid (windowmanager_pid, out status, 0);
            if (Process.if_exited (status))
                debug ("Window Manager exited with return value %d", Process.exit_status (status));
            else
                debug ("Window Manager terminated with signal %d", Process.term_sig (status));
            windowmanager_pid = 0;
        }
    }

    public static int main (string[] args)
    {
        /* Protect memory from being paged to disk, as we deal with passwords

           According to systemd-dev,

           "mlockall() is generally a bad idea and certainly has no place in a graphical program.
           A program like this uses lots of memory and it is crucial that this memory can be paged
           out to relieve memory pressure."

           With systemd version 239 the ulimit for RLIMIT_MEMLOCK was set to 16 MiB
           and therefore the mlockall call would fail. This is lucky because the subsequent mmap would not fail.

           With systemd version 240 the RLIMIT_MEMLOCK is now set to 64 MiB
           and now the mlockall no longer fails. However, it not possible to mmap in all
           the memory and because that would still exceed the MEMLOCK limit.
           "
           See https://bugzilla.redhat.com/show_bug.cgi?id=1662857 &
           https://github.com/CanonicalLtd/lightdm/issues/55

           RLIMIT_MEMLOCK = 64 MiB means, arctica-greeter will most likely fail with 64 bit and
           will always fail on 32 bit systems.

           Hence we better disable it. */

        /*Posix.mlockall (Posix.MCL_CURRENT | Posix.MCL_FUTURE);*/

        /* Disable the stupid global menubar */
        Environment.unset_variable ("UBUNTU_MENUPROXY");

        /* Initialize i18n */
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Config.GETTEXT_PACKAGE);

        /* Set up the accessibility stack, in case the user needs it for screen reading etc. */
        AGUtils.greeter_set_env ("GTK_MODULES", "atk-bridge");

        /* Fix for https://bugs.launchpad.net/ubuntu/+source/unity-greeter/+bug/1024482
           Slick-greeter sets the mouse cursor on the root window.
           Without GDK_CORE_DEVICE_EVENTS set, the DE is unable to apply its own cursor theme and size.
        */
        AGUtils.greeter_set_env ("GDK_CORE_DEVICE_EVENTS", "1");

        log_timer = new Timer ();
        Log.set_default_handler (log_cb);

        int scaling_factor_hidpi = 1;

        /* HiDPI settings */
        var hidpi = AGSettings.get_string (AGSettings.KEY_ENABLE_HIDPI);
        debug ("HiDPI support: %s", hidpi);
        if (hidpi == "auto")
        {
            /* This detects if the display size "recommends" hidpi and sets scaling_factor to 2. */
            scaling_factor_hidpi = check_hidpi ();
        }
        else if (hidpi == "on")
        {
            /* User configured an exlicit scaling factor via KEY_ENBALE_HIDPI. */
            scaling_factor_hidpi = 2;
        }
        /* Adjust GDK_SCALE to our configured scaling factor (via HiDPI settings). */
        debug ("Setting GDK_SCALE to: %d (scaling all UI elements by this factor)", scaling_factor_hidpi);
        AGUtils.greeter_set_env ("GDK_SCALE", "%d".printf (scaling_factor_hidpi));

        /* Font scaling settings */
        var scaling_factor_fonts = AGSettings.get_double (AGSettings.KEY_FONT_SCALING);
        debug ("Scaling factor for fonts is: %f", scaling_factor_fonts);

        /* Adjust GDK_SCALE / GDK_DPI_SCALE to our configured scaling factors. */
        debug ("Setting GDK_DPI_SCALE to: %f (scaling fonts only by this factor)", scaling_factor_fonts);
        AGUtils.greeter_set_env ("GDK_DPI_SCALE", "%f".printf (scaling_factor_fonts));

        /* Make nm-applet hide items the user does not have permissions to interact with */
        AGUtils.greeter_set_env ("NM_APPLET_HIDE_POLICY_ITEMS", "1");

        /* Set indicators to run with reduced functionality */
        AGUtils.greeter_set_env ("INDICATOR_GREETER_MODE", "1");

        /* Don't allow virtual file systems? */
        AGUtils.greeter_set_env ("GIO_USE_VFS", "local");
        AGUtils.greeter_set_env ("GVFS_DISABLE_FUSE", "1");

        /* Hint to have onboard running in greeter mode */
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

        bool do_show_version = false;
        bool do_test_mode = false;
        bool do_test_highcontrast = false;

        OptionEntry versionOption = { "version", 'v', 0, OptionArg.NONE, ref do_show_version,
                /* Help string for command line --version flag */
                N_("Show release version"), null };
        OptionEntry testOption =  { "test-mode", 0, 0, OptionArg.NONE, ref do_test_mode,
                /* Help string for command line --test-mode flag */
                N_("Run in test mode"), null };
        OptionEntry highcontrastOption =  { "test-highcontrast", 0, 0, OptionArg.NONE, ref do_test_highcontrast,
                /* Help string for command line --test-highcontrast flag */
                N_("Run in test mode with a11y highcontrast theme enabled"), null };
        OptionEntry nullOption = { null };
        OptionEntry[] options = { versionOption, testOption, highcontrastOption, nullOption };

        debug ("Loading command line options");
        var c = new OptionContext (/* Arguments and description for --help text */
                                   _("- Arctica Greeter"));

        c.add_main_entries (options, Config.GETTEXT_PACKAGE);
        c.add_group (Gtk.get_option_group (true));

        /*
         * IMPORTANT: environment variable setup must go above this comment
         *
         * GLib.Environment.set_variable() calls won't take effect (for
         * whatever unknown reason...) if they get issued after the c.parse()
         * method call on our OptionContext object (see a few lines below).
         * Same applies to AGUtils.set_greeter_env().
         *
         * To mitigate this (strange) behaviour, make sure that all env
         * variable setups in main() are located above this comment.
         */
        try
        {
            c.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            stderr.printf (/* Text printed out when an unknown command-line argument provided */
                           _("Run '%s --help' to see a full list of available command line options."), args[0]);
            stderr.printf ("\n");
            return Posix.EXIT_FAILURE;
        }


        if (do_show_version)
        {
            /* Note, not translated so can be easily parsed */
            stderr.printf ("arctica-greeter %s\n", Config.VERSION);
            return Posix.EXIT_SUCCESS;
        }

        if (do_test_mode) {
            debug ("Running in test mode");
            if (do_test_highcontrast) {
                debug ("Switching on highcontrast theme for test mode");
            }
        }

        var gsettings_mate_desktop_interface = new Settings ("org.mate.interface");
        int wsf_orig = 0;

        if (!do_test_mode) {
            /* Set the keyboard layout */
            set_keyboard_layout ();

            /* Set the numlock state */
            if (AGSettings.get_boolean (AGSettings.KEY_ACTIVATE_NUMLOCK)) {
                debug ("Activating numlock");
                activate_numlock ();
            }
        }

        Pid atspi_pid = 0;
        Pid nmapplet_pid = 0;
        Pid geoclueagent_pid = 0;

        if (!do_test_mode)
        {
            wsf_orig = gsettings_mate_desktop_interface.get_int ("window-scaling-factor");
            gsettings_mate_desktop_interface.set_int ("window-scaling-factor", 1);

            try
            {
                string[] argv = null;

                if (FileUtils.test ("/usr/lib/at-spi2-core/at-spi-bus-launcher", FileTest.EXISTS)) {
                    Shell.parse_argv ("/usr/lib/at-spi2-core/at-spi-bus-launcher --launch-immediately", out argv);
                }
                else if  (FileUtils.test ("/usr/libexec/at-spi-bus-launcher", FileTest.EXISTS)) {
                    Shell.parse_argv ("/usr/libexec/at-spi-bus-launcher --launch-immediately", out argv);
                }
                if (argv != null)
                    Process.spawn_async (null,
                                         argv,
                                         null,
                                         SpawnFlags.SEARCH_PATH,
                                         null,
                                         out atspi_pid);
                debug ("Launched at-spi-bus-launcher. PID: %d", atspi_pid);
            }
            catch (Error e)
            {
                warning ("Error starting the at-spi registry: %s", e.message);
            }

            if (AGSettings.get_boolean (AGSettings.KEY_GEOCLUE_AGENT) && (!do_test_mode))
            {

                try
                {
                    string[] argv = null;

                    if (FileUtils.test ("/usr/lib/geoclue-2.0/demos/agent", FileTest.EXISTS)) {
                        Shell.parse_argv ("/usr/lib/geoclue-2.0/demos/agent", out argv);
                    }
                    else if  (FileUtils.test ("/usr/libexec/geoclue-2.0/demos/agent", FileTest.EXISTS)) {
                        Shell.parse_argv ("/usr/libexec/geoclue-2.0/demos/agent", out argv);
                    }
                    if (argv != null)
                        Process.spawn_async (null,
                                             argv,
                                             null,
                                             SpawnFlags.SEARCH_PATH,
                                             null,
                                             out geoclueagent_pid);
                    debug ("Launched GeoClue-2.0 agent. PID: %d", geoclueagent_pid);
                }
                catch (Error e)
                {
                    warning ("Error starting the GeoClue-2.0 agent: %s", e.message);
                }
            }

            /* Enable touchpad tap-to-click */
            enable_tap_to_click ();

        }

        Gtk.init (ref args);
        Ido.init ();

        debug ("Starting arctica-greeter %s UID=%d LANG=%s", Config.VERSION, (int) Posix.getuid (), Environment.get_variable ("LANG"));

        /* Set the cursor to not be the crap default */
        debug ("Setting cursor");
        Gdk.get_default_root_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.LEFT_PTR));

        /* Set GTK+ settings */
        debug ("Setting GTK+ settings");
        var settings = Gtk.Settings.get_default ();

        /*
         * Keep a reference to an AGSettings instance for the whole program
         * run, so that the SingleInstance property is working the way we'd
         * like it to work.
         *
         * We want to do this before creating the actual greeter, since the
         * latter is using AGSettings quite extensively.
         *
         * This might throw a Vala warning: "local variable `agsettings'
         * declared but never used" if we don't use the variable, but this can
         * safely be ignored.
         */
        var agsettings = new AGSettings ();
        string value = "";
        if (agsettings.high_contrast)
        {
            value = AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_THEME_NAME);
        } else {
            value = AGSettings.get_string (AGSettings.KEY_THEME_NAME);
        }
        if (value != ""){
            debug ("Setting GTK theme: %s", value);
            settings.set ("gtk-theme-name", value, null);
        }
        if (agsettings.high_contrast)
        {
            value = AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_ICON_THEME_NAME);
        } else {
            value = AGSettings.get_string (AGSettings.KEY_ICON_THEME_NAME);
        }
        if (value != ""){
            debug ("Setting icon theme: %s", value);
            settings.set ("gtk-icon-theme-name", value, null);
        }
        value = AGSettings.get_string (AGSettings.KEY_CURSOR_THEME_NAME);
        if (value != "") {
            debug ("Setting cursor theme: %s", value);
            settings.set ("gtk-cursor-theme-name", value, null);
        }
        var int_value = AGSettings.get_integer (AGSettings.KEY_CURSOR_THEME_SIZE);
        if (int_value != 0) {
            debug ("Settings cursor theme size: %d", int_value);
            settings.set ("gtk-cursor-theme-size", int_value, null);
        }
        value = AGSettings.get_string (AGSettings.KEY_FONT_NAME);
        if (value != ""){
            settings.set ("gtk-font-name", value, null);
        }
        var double_value = AGSettings.get_double (AGSettings.KEY_XFT_DPI);
        if (double_value != 0.0)
            settings.set ("gtk-xft-dpi", (int) (1024 * double_value), null);
        var boolean_value = AGSettings.get_boolean (AGSettings.KEY_XFT_ANTIALIAS);
        settings.set ("gtk-xft-antialias", boolean_value, null);
        value = AGSettings.get_string (AGSettings.KEY_XFT_HINTSTYLE);
        if (value != "")
            settings.set ("gtk-xft-hintstyle", value, null);
        value = AGSettings.get_string (AGSettings.KEY_XFT_RGBA);
        if (value != "")
            settings.set ("gtk-xft-rgba", value, null);

        debug ("Creating Arctica Greeter");
        var greeter = new ArcticaGreeter (do_test_mode, do_test_highcontrast);
        greeter.go();

        if (!do_test_mode)
        {

            activate_upower();

            greeter.greeter_ready.connect (() => {
                debug ("Showing greeter");
                greeter.show ();
            });

            try
            {
                string[] argv;

                Shell.parse_argv ("nm-applet --indicator", out argv);
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out nmapplet_pid);
                debug ("Launched nm-applet. PID: %d", nmapplet_pid);
            }
            catch (Error e)
            {
                warning ("Error starting the Network Manager Applet: %s", e.message);
            }

        }
        else
            greeter.show ();

        /* Setup a handler for TERM so we quit cleanly */
        GLib.Unix.signal_add(GLib.ProcessSignal.TERM, () => {
            debug("Got a SIGTERM");
            Gtk.main_quit();
            return true;
        });

        debug ("Starting main loop");
        Gtk.main ();

        debug ("Cleaning up");

        if (!do_test_mode)
        {

            greeter.stop_indicators();
            greeter.stop_notification_daemon();
            greeter.settings_daemon.stop();

            if (nmapplet_pid != 0)
            {
#if VALA_0_40
                Posix.kill (nmapplet_pid, Posix.Signal.TERM);
#else
                Posix.kill (nmapplet_pid, Posix.SIGTERM);
#endif
                int status;
                Posix.waitpid (nmapplet_pid, out status, 0);
                if (Process.if_exited (status))
                    debug ("Network Manager Applet exited with return value %d", Process.exit_status (status));
                else
                    debug ("Network Manager Applet terminated with signal %d", Process.term_sig (status));
                nmapplet_pid = 0;
            }

            if (atspi_pid != 0)
            {
#if VALA_0_40
                Posix.kill (atspi_pid, Posix.Signal.KILL);
#else
                Posix.kill (atspi_pid, Posix.SIGKILL);
#endif
                int status;
                Posix.waitpid (atspi_pid, out status, 0);
                if (Process.if_exited (status))
                    debug ("AT-SPI exited with return value %d", Process.exit_status (status));
                else
                    debug ("AT-SPI terminated with signal %d", Process.term_sig (status));
                atspi_pid = 0;
            }

            if (geoclueagent_pid != 0)
            {
#if VALA_0_40
                Posix.kill (geoclueagent_pid, Posix.Signal.KILL);
#else
                Posix.kill (geoclueagent_pid, Posix.SIGKILL);
#endif
                int status;
                Posix.waitpid (geoclueagent_pid, out status, 0);
                if (Process.if_exited (status))
                    debug ("GeoClue-2.0 agent exited with return value %d", Process.exit_status (status));
                else
                    debug ("GeoClue-2.0 agent terminated with signal %d", Process.term_sig (status));
                geoclueagent_pid = 0;
            }
        }

        if (!do_test_mode)
        {
            gsettings_mate_desktop_interface.set_int ("window-scaling-factor", wsf_orig);
        }

        var screen = Gdk.Screen.get_default ();
        Gdk.X11.Display pDisplay = (Gdk.X11.Display) screen.get_display ();
        unowned X.Display xdisplay = pDisplay.get_xdisplay ();

        var window = xdisplay.default_root_window();
        var atom = xdisplay.intern_atom ("AT_SPI_BUS", true);

        if (atom != X.None) {
            xdisplay.delete_property (window, atom);
            Gdk.flush();
        }

        debug ("Exiting");

        return Posix.EXIT_SUCCESS;
    }
}

[DBus (name="org.gnome.SessionManager.EndSessionDialog")]
public class DialogDBusInterface : Object
{
    public signal void open_dialog (uint32 type);
    public signal void close_dialog ();

    public void open (uint32 type, uint32 timestamp, uint32 seconds_to_stay_open, ObjectPath[] inhibitor_object_paths) throws GLib.DBusError, GLib.IOError
    {
        open_dialog (type);
    }

    public void close () throws GLib.DBusError, GLib.IOError
    {
        close_dialog ();
    }
}

[DBus (name="org.mate.SettingsDaemon")]
private interface SettingsDaemonDBusInterface : Object
{
    public signal void plugin_activated (string name);
    public signal void plugin_deactivated (string name);
}

[DBus (name = "org.ayatana.greeter")]
public class DBusServer : Object
{
    private DBusConnection pConnection;
    private ArcticaGreeter pGreeter;
    private Pid nOrca = 0;
    private Pid nOnBoard = 0;
    private Pid nMagnifier = 0;
    private Gtk.Socket pKeyboardSocket = null;
    private Gtk.Socket pMagnifierSocket = null;
    private bool high_contrast_osk = AGSettings.get_boolean(AGSettings.KEY_HIGH_CONTRAST);

    private void closePid (ref Pid nPid, int nMultiplier)
    {
        if (nPid > 0)
        {

            /* Make sure we operate on the complete process group here
             * (POSIX specs: prepend a '-' to the PID to affect the complete
             * process group).
             *
             * Otherwise a follow-up onboard process (group) will refuse to start
             * immediately after having killed the previous process (group).
             */
            Posix.kill (nPid * nMultiplier, Posix.Signal.TERM);
            int nStatus;
            Posix.waitpid (nPid * nMultiplier, out nStatus, 0);
            nPid = 0;
        }
    }

    private void cleanup ()
    {
        closePid (ref nOnBoard, -1);
        closePid (ref nOrca, 1);
        closePid (ref nMagnifier, 1);
    }

    public DBusServer (DBusConnection pConnection, ArcticaGreeter pGreeter)
    {
        this.pConnection = pConnection;
        this.pGreeter = pGreeter;
        this.pGreeter.starting_session.connect (cleanup);
    }

    public void sendUserChange (string sUser) throws GLib.DBusError, GLib.IOError
    {
        Variant pUser = new Variant ("(s)", sUser);

        try
        {
            this.pConnection.emit_signal (null, "/org/ayatana/greeter", "org.ayatana.greeter", "UserChanged", pUser);
        }
        catch (Error pError)
        {
            error ("Panic: Could not send user change signal: %s", pError.message);
        }
    }

    public string GetUser () throws GLib.DBusError, GLib.IOError
    {
        var sUser = this.pGreeter.get_state ("last-user");

        return (sUser != null) ? sUser : "*other";
    }

    public void SetLayout (string sLanguage, string sVariant) throws GLib.DBusError, GLib.IOError
    {
        string sCommand = "setxkbmap -layout %s".printf (sLanguage);

        if (sVariant != "")
        {
            sCommand = "%s -variant %s".printf (sCommand, sVariant);
        }

        try
        {
            Process.spawn_command_line_sync (sCommand, null, null, null);
        }
        catch (Error pError)
        {
            error ("Panic: Could not set keyboard layout: %s", pError.message);
        }
    }

    public void ToggleOnBoard (bool bActive) throws GLib.DBusError, GLib.IOError
    {

        int nId = 0;
        var sTheme = "";

        if (AGSettings.get_boolean (AGSettings.KEY_ONSCREEN_KEYBOARD) != bActive)
        {
            AGSettings.set_boolean (AGSettings.KEY_ONSCREEN_KEYBOARD, bActive);
        }

        if (high_contrast_osk != AGSettings.get_boolean(AGSettings.KEY_HIGH_CONTRAST))
        {
            if (nOnBoard != 0)
            {

                /* Hide the OSK window while fiddling with it...
                 */
                this.pGreeter.pKeyboardWindow.visible = false;

                /* calling closePid sets nOnBoard to 0 */
                debug ("Closing previous keyboard with PID %d", nOnBoard);
                closePid (ref nOnBoard, -1);

                /* Sending SIGTERM to the plug (i.e. the onboard process group)
                 * will destroy pKeyboardSocket, so NULLing it now.
                 */
                debug ("Tearing down OSK's Gtk.Socket");
                this.pGreeter.pKeyboardWindow.remove (pKeyboardSocket);
                pKeyboardSocket = null;

                /* Start with fresh Gkt.Window object for OSK relaunch.
                 */
                debug ("Tearing down OSK's Gtk.Window");
                this.pGreeter.pKeyboardWindow.close();
                this.pGreeter.pKeyboardWindow = null;

            }
            high_contrast_osk = AGSettings.get_boolean(AGSettings.KEY_HIGH_CONTRAST);
        }

        if (nOnBoard == 0)
        {

            try
            {

                var sLayout = AGSettings.get_string (AGSettings.KEY_ONSCREEN_KEYBOARD_LAYOUT);
                var sLayoutPath = "/usr/share/onboard/layouts/%s.onboard".printf (sLayout);
                var pLayoutFile = File.new_for_path (sLayoutPath);
                if (high_contrast_osk)
                {
                    sTheme = AGSettings.get_string (AGSettings.KEY_HIGH_CONTRAST_ONSCREEN_KEYBOARD_THEME);
                }
                else
                {
                    sTheme = AGSettings.get_string (AGSettings.KEY_ONSCREEN_KEYBOARD_THEME);
                }
                var sThemePath = "/usr/share/onboard/themes/%s.theme".printf (sTheme);
                var pThemeFile = File.new_for_path (sThemePath);
                var sLayoutArgs = "";

                if (pLayoutFile.query_exists ())
                {
                    sLayoutArgs = "--layout='%s'".printf (sLayoutPath);
                }

                var sThemeArgs = "";

                if (pThemeFile.query_exists ())
                {
                    sThemeArgs  = "--theme='%s'".printf (sThemePath);
                }

                string sCommand = "onboard --keep-aspect --launched-by=arctica-greeter --xid %s %s".printf (sLayoutArgs, sThemeArgs);
                debug ("Launching OSK: '%s'", sCommand);

                string[] lArgs;
                Shell.parse_argv (sCommand, out lArgs);
                int nOnboardFD;
                Process.spawn_async_with_pipes (null,
                                                lArgs,
                                                null,
                                                SpawnFlags.SEARCH_PATH,
                                                null,
                                                out nOnBoard,
                                                null,
                                                out nOnboardFD,
                                                null);
                var pFile = FileStream.fdopen (nOnboardFD, "r");
                var sText = new char[1024];

                if (pFile.gets (sText) != null)
                {
                    nId = int.parse ((string) sText);
                }

            }
            catch (Error pError)
            {
                warning ("Error setting up keyboard: %s", pError.message);

                return;
            }
        }

        if (pKeyboardSocket == null)
        {
            debug ("Creating Gtk.Socket for OSK");
            pKeyboardSocket = new Gtk.Socket ();
            pKeyboardSocket.show ();
        }

        if ((this.pGreeter.pKeyboardWindow == null) && (pKeyboardSocket != null))
        {
            debug ("Creating Gtk.Window for OSK");
            this.pGreeter.pKeyboardWindow = new Gtk.Window ();
            this.pGreeter.pKeyboardWindow.accept_focus = false;
            this.pGreeter.pKeyboardWindow.focus_on_map = false;
            this.pGreeter.pKeyboardWindow.set_title("OSK (theme: %s)".printf(sTheme));
            this.pGreeter.pKeyboardWindow.set_decorated (false);
            this.pGreeter.pKeyboardWindow.set_keep_above (true);
        }

        if ((this.pGreeter.pKeyboardWindow != null) && (pKeyboardSocket != null) && (nId != 0))
        {
            /* attach the GtkSocket, which will host the onboard keyboard, to pKeyboardWindow */
            debug ("Adding OSK Gtk.Socket to OSK Gtk.Window");
            this.pGreeter.pKeyboardWindow.add (pKeyboardSocket);

            debug ("Attaching new onboard process to OSK Gtk.Socket (+ Gtk.Window)");
            pKeyboardSocket.add_id (nId);
        }

        if ((this.pGreeter.pKeyboardWindow != null) && (pKeyboardSocket != null) && bActive)
        {
            /* resize the keyboard window to cover the lower part of the screen */
            debug ("Resizing OSK window.");
            var pDisplay = this.pGreeter.main_window.get_display ();
            var pMonitor = pDisplay.get_monitor_at_window (this.pGreeter.main_window.get_window ());
            Gdk.Rectangle cRect = pMonitor.get_geometry ();
            this.pGreeter.pKeyboardWindow.move (cRect.x, cRect.y + cRect.height - 200);
            this.pGreeter.pKeyboardWindow.resize (cRect.width, 200);
        }

        this.pGreeter.pKeyboardWindow.visible = bActive;
    }

    public void ToggleOrca (bool bActive) throws GLib.DBusError, GLib.IOError
    {
        AGSettings.set_boolean (AGSettings.KEY_SCREEN_READER, bActive);

        if (bActive)
        {
            try
            {
                string[] lArgs;
                Shell.parse_argv ("orca --replace --no-setup --disable splash-window,", out lArgs);
                Process.spawn_async (null, lArgs, null, SpawnFlags.SEARCH_PATH, null, out nOrca);

                /*
                This is a workaround for bug https://launchpad.net/bugs/944159
                The problem is that orca seems to not notice that it's in a
                password field on startup.  We just need to kick orca in the
                pants.  We do this two ways:  a racy way and a non-racy way.
                We kick it after a second which is ideal if we win the race,
                because the user gets to hear what widget they are in, and
                the first character will be masked.  Otherwise, if we lose
                that race, the first time the user types (see
                DashEntry.key_press_event), we will kick orca again.  While
                this is not racy with orca startup, it is racy with whether
                orca will read the first character or not out loud.  Hence
                why we do both.  Ideally this would be fixed in orca itself.
                */
                var pGreeter = new ArcticaGreeter ();
                pGreeter.orca_needs_kick = true;

                Timeout.add_seconds (1, () =>
                {
                    Gtk.Window pWindow = (Gtk.Window) this.pGreeter.main_window.get_toplevel ();
                    Signal.emit_by_name (pWindow.get_focus ().get_accessible (), "focus-event", true);

                    return false;
                });
            }
            catch (Error pError)
            {
                warning ("Failed to run Orca: %s", pError.message);
            }
        }
        else
        {
            closePid (ref nOrca, 1);
            nOrca = 0;
        }
    }

    public void ToggleHighContrast (bool bActive) throws GLib.DBusError, GLib.IOError
    {
        var agsettings = new AGSettings ();
        agsettings.high_contrast = bActive;

        /* Trigger onboard restart with correct theme */
        debug ("High-Contrast mode toggled (new state: %b), refreshing OSK, as well.", bActive);
        ToggleOnBoard (AGSettings.get_boolean (AGSettings.KEY_ONSCREEN_KEYBOARD));
    }

    public void ToggleMagnifier (bool bActive) throws GLib.DBusError, GLib.IOError
    {
        int nId = 0;
        AGSettings.set_boolean (AGSettings.KEY_MAGNIFIER, bActive);

        if (this.nMagnifier == 0)
        {
            try
            {
                int nMagnifierFD = 0;
                string sPath = Path.build_filename (Config.PKGLIBEXECDIR, "arctica-greeter-magnifier");
                Process.spawn_async_with_pipes (null, {sPath}, null, SpawnFlags.SEARCH_PATH, null, out this.nMagnifier, null, out nMagnifierFD, null);
                var pFile = FileStream.fdopen (nMagnifierFD, "r");
                var sText = new char[1024];

                if (pFile.gets (sText) != null)
                {
                    nId = int.parse ((string) sText);
                }
            }
            catch (Error pError)
            {
                warning ("Failed to run magnifier: %s", pError.message);

                return;
            }
        }

        if (pMagnifierSocket == null)
        {
            debug ("Creating Gtk.Socket for the magnifier");
            pMagnifierSocket = new Gtk.Socket ();
            pMagnifierSocket.show ();
        }

        if ((this.pGreeter.pMagnifierWindow == null) && (pMagnifierSocket != null))
        {
            debug ("Creating Gtk.Window for the magnifier");
            this.pGreeter.pMagnifierWindow = new Gtk.Window ();
            this.pGreeter.pMagnifierWindow.accept_focus = false;
            this.pGreeter.pMagnifierWindow.focus_on_map = false;
            this.pGreeter.pMagnifierWindow.set_title ("Magnifier");
            this.pGreeter.pMagnifierWindow.set_decorated (false);
            this.pGreeter.pMagnifierWindow.set_keep_above (true);
        }

        if ((this.pGreeter.pMagnifierWindow != null) && (pMagnifierSocket != null) && (nId != 0))
        {
            debug ("Adding the magnifier Gtk.Socket to the magnifier Gtk.Window");
            this.pGreeter.pMagnifierWindow.add (pMagnifierSocket);

            debug ("Attaching new magnifier process to the magnifier Gtk.Socket (+ Gtk.Window)");
            pMagnifierSocket.add_id (nId);
        }

        if ((this.pGreeter.pMagnifierWindow != null) && (pMagnifierSocket != null) && bActive)
        {
            /* resize and position the magnifier window */
            debug ("Resizing and positioning Magnifier window.");
            var pDisplay = this.pGreeter.main_window.get_display ();
            var pMonitor = pDisplay.get_monitor_at_window (this.pGreeter.main_window.get_window ());
            Gdk.Rectangle cRect = pMonitor.get_geometry ();
            int magnifier_width  = 2 * cRect.width / 5;
            int magnifier_height = 2 * cRect.height / 5;
            string sPosition = AGSettings.get_string (AGSettings.KEY_MAGNIFIER_POSITION);

            if (sPosition == "top-left")
            {
                magnifier_width  = (int) (magnifier_width * 0.75);
                magnifier_height = (int) (magnifier_height * 0.75);
                this.pGreeter.pMagnifierWindow.move (cRect.x + ArcticaGreeter.MENUBAR_HEIGHT, cRect.y + ArcticaGreeter.MENUBAR_HEIGHT * 2);
            }
            else if (sPosition == "top-right")
            {
                magnifier_width  = (int) (magnifier_width * 0.75);
                magnifier_height = (int) (magnifier_height * 0.75);
                this.pGreeter.pMagnifierWindow.move (cRect.x + cRect.width - ArcticaGreeter.MENUBAR_HEIGHT - magnifier_width, cRect.y + ArcticaGreeter.MENUBAR_HEIGHT * 2);
            }
            else if (sPosition == "centre-left")
            {
                this.pGreeter.pMagnifierWindow.move (cRect.x + cRect.width / 10, cRect.y + cRect.height / 5 + cRect.height / 10);
            }
            else if (sPosition == "centre-right")
            {
                this.pGreeter.pMagnifierWindow.move (cRect.x + cRect.width - cRect.width / 10 - magnifier_width, cRect.y + cRect.height / 5 + cRect.height / 10);
            }

            this.pGreeter.pMagnifierWindow.resize (magnifier_width, magnifier_height);
        }

        this.pGreeter.pMagnifierWindow.visible = bActive;
    }
}
