/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011 Canonical Ltd
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
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 */

public const int grid_size = 40;

[SingleInstance]
public class ArcticaGreeter : Object
{
    public signal void show_message (string text, LightDM.MessageType type);
    public signal void show_prompt (string text, LightDM.PromptType type);
    public signal void authentication_complete ();
    public signal void starting_session ();

    public bool test_mode { get; construct; default = false; }
    public bool test_highcontrast { get; construct; default = false; }
    public bool test_bigfont { get; construct; default = false; }
    private string state_file;
    private KeyFile state;

    private Cairo.XlibSurface background_surface;

    private SettingsDaemon settings_daemon;

    public bool orca_needs_kick;
    private MainWindow main_window;

    private LightDM.Greeter greeter;

    private Canberra.Context canberra_context;

    private static Timer log_timer;

    private DialogDBusInterface dbus_object;
    private SettingsDaemonDBusInterface  settings_daemon_proxy;
    public signal void xsettings_ready ();
    public signal void greeter_ready ();

    construct
    {
        greeter = new LightDM.Greeter ();
        greeter.show_message.connect ((text, type) => { show_message (text, type); });
        greeter.show_prompt.connect ((text, type) => { show_prompt (text, type); });
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

    /*
     * Note that we need a way to specify a parameter for the initial instance
     * creation of the singleton, but also a constructor that takes no
     * parameters for later usage.
     *
     * Making the parameter optional is a good compromise.
     *
     * This this parameter is construct-only, initializing it by passing it to
     * the GObject constructor is both the correct way to do it, and it will
     * additionally avoid changing it in later calls of our constructor.
     */
    public ArcticaGreeter (bool test_mode_ = false,
                           bool test_highcontrast_ = false,
                           bool test_bigfont_ = false)
    {
        Object (test_mode: test_mode_,
                test_highcontrast: test_highcontrast_,
                test_bigfont: test_bigfont_
        );
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
        var sessions = new List<string> ();
        sessions.append ("lightdm-xsession");

        // FIXME: this list should be obtained from AGSettings, ideally...
        sessions.append ("mate");
        sessions.append ("xfce");
        sessions.append ("kde-plasma");
        sessions.append ("kde");
        sessions.append ("gnome");
        sessions.append ("cinnamon");
        sessions.append ("lomiri");

        foreach (string session in sessions) {
            var path = Path.build_filename  ("/usr/share/wayland-sessions/", session.concat(".desktop"), null);
            if (FileUtils.test (path, FileTest.EXISTS)) {
                debug ("Using %s as default (Wayland) session.", session);
                return session;
            }
        }

        foreach (string session in sessions) {
            var path = Path.build_filename  ("/usr/share/xsessions/", session.concat(".desktop"), null);
            if (FileUtils.test (path, FileTest.EXISTS)) {
                debug ("Using %s as default (X11) session.", session);
                return session;
            }
        }

        warning ("Could not find a default session. Falling back to LightDM's system default.");
        return greeter.default_session_hint;
    }

    public string validate_session (string? session)
    {
        /* Make sure the given session actually exists. Return it if it does.
         * otherwise, return the default session.
         */
        if (session != null) {
            var path = Path.build_filename  ("/usr/share/xsessions/", session.concat(".desktop"), null);
            var waypath = Path.build_filename  ("/usr/share/wayland-sessions/", session.concat(".desktop"), null);
            if (!FileUtils.test (path, FileTest.EXISTS) & !FileUtils.test (waypath, FileTest.EXISTS)) {
                debug ("Invalid session: '%s'", session);
                session = null;
            }
        }

        if (session == null) {
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

        main_window.before_session_start();

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
            agsettings.big_font = !(!(agsettings.big_font));
        } else {
            agsettings.high_contrast = test_highcontrast;
            agsettings.big_font = test_bigfont;
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
        Timeout.add_full (GLib.Priority.HIGH_IDLE, 302, () => {
            var agsettings_intimer = new AGSettings ();
            /*
            if (0 == GLib.Random.int_range (0, 10)) {
                debug ("Syncing up big font value via timer: %s", agsettings_intimer.big_font.to_string ());
            }
            */
            switch_font (agsettings_intimer.big_font);

            return true;
        });

        return false;
    }

    public void show ()
    {
        debug ("Showing main window");
        if (!test_mode)
            main_window.set_decorated (false);
        main_window.show ();
        main_window.get_window ().focus (Gdk.CURRENT_TIME);
        main_window.set_keyboard_state ();
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

    public void switch_font (bool big)
    {
        iterate_children_generic (main_window, switch_generic, "big_font", big);
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
                if (main_window.menubar.keyboard_window != null)
                    keyboard_xid = (main_window.menubar.keyboard_window.get_window () as Gdk.X11.Window).get_xid ();

                if (xwin != keyboard_xid && win.get_type_hint() != Gdk.WindowTypeHint.NOTIFICATION)
                {
                    win.focus (Gdk.CURRENT_TIME);

                    /* Make sure to keep keyboard above */
                    if (main_window.menubar.keyboard_window != null)
                        main_window.menubar.keyboard_window.get_window ().raise ();
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
                if (main_window.menubar.keyboard_window != null)
                    main_window.menubar.keyboard_window.get_window ().raise ();
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

        unowned X.Display display = (screen.get_display () as Gdk.X11.Display).get_xdisplay ();
        unowned X.Screen xscreen = (screen as Gdk.X11.Screen).get_xscreen ();

        var pixmap = X.CreatePixmap (display,
                                     (screen.get_root_window () as Gdk.X11.Window).get_xid (),
                                     xscreen.width_of_screen (),
                                     xscreen.height_of_screen (),
                                     visual.get_depth ());

        /* Convert into a Cairo surface */
        var surface = new Cairo.XlibSurface (display,
                                             pixmap,
                                             (visual as Gdk.X11.Visual).get_xvisual (),
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

        main_window.destroy.connect(() => { kill_fake_wm (); });
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

    private static void check_hidpi ()
    {
        try {
            string output;
            Process.spawn_command_line_sync(Path.build_filename (Config.PKGLIBEXECDIR, "arctica-greeter-check-hidpi"), out output, null, null);
            output = output.strip();
            if (output == "2") {
                debug ("Activating HiDPI (2x scale ratio)");
                GLib.Environment.set_variable ("GDK_SCALE", "2", true);
            }
        }
        catch (Error e){
            warning ("Error while setting HiDPI support: %s", e.message);
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
        Environment.set_variable ("GTK_MODULES", "atk-bridge", false);

        /* Fix for https://bugs.launchpad.net/ubuntu/+source/unity-greeter/+bug/1024482
           Slick-greeter sets the mouse cursor on the root window.
           Without GDK_CORE_DEVICE_EVENTS set, the DE is unable to apply its own cursor theme and size.
        */
        GLib.Environment.set_variable ("GDK_CORE_DEVICE_EVENTS", "1", true);

        log_timer = new Timer ();
        Log.set_default_handler (log_cb);

        bool do_show_version = false;
        bool do_test_mode = false;
        bool do_test_highcontrast = false;
        bool do_test_bigfont = false;

        OptionEntry versionOption = { "version", 'v', 0, OptionArg.NONE, ref do_show_version,
                /* Help string for command line --version flag */
                N_("Show release version"), null };
        OptionEntry testOption =  { "test-mode", 0, 0, OptionArg.NONE, ref do_test_mode,
                /* Help string for command line --test-mode flag */
                N_("Run in test mode"), null };
        OptionEntry highcontrastOption =  { "test-highcontrast", 0, 0, OptionArg.NONE, ref do_test_highcontrast,
                /* Help string for command line --test-highcontrast flag */
                N_("Run in test mode with a11y highcontrast theme enabled"), null };
        OptionEntry bigfontOption =  { "test-bigfont", 0, 0, OptionArg.NONE, ref do_test_bigfont,
                /* Help string for command line --test-bigfont flag */
                N_("Run in test mode with a11y big font feature enabled"), null };
        OptionEntry nullOption = { null };
        OptionEntry[] options = { versionOption, testOption, highcontrastOption, bigfontOption, nullOption };

        debug ("Loading command line options");
        var c = new OptionContext (/* Arguments and description for --help text */
                                   _("- Arctica Greeter"));
        c.add_main_entries (options, Config.GETTEXT_PACKAGE);
        c.add_group (Gtk.get_option_group (true));
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

        if (!do_test_mode)
        {
            var hidpi = AGSettings.get_string (AGSettings.KEY_ENABLE_HIDPI);
            debug ("HiDPI support: %s", hidpi);
            if (hidpi == "auto") {
                check_hidpi ();
            }
            else if (hidpi == "on") {
                GLib.Environment.set_variable ("GDK_SCALE", "2", true);
            }
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
            if (do_test_bigfont) {
                debug ("Switching on big font feature for test mode");
            }
        }

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
        if (!do_test_mode)
        {

            try
            {
                string[] argv = null;

                if (FileUtils.test ("/usr/lib/at-spi2-core/at-spi-bus-launcher", FileTest.EXISTS)) {
                    // Debian & derivatives...
                    Shell.parse_argv ("/usr/lib/at-spi2-core/at-spi-bus-launcher --launch-immediately", out argv);
                }
                else if  (FileUtils.test ("/usr/libexec/at-spi-bus-launcher", FileTest.EXISTS)) {
                    // Fedora & derivatives...
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
        }

        /* Enable touchpad tap-to-click */
        enable_tap_to_click ();

        Gtk.init (ref args);
        Ido.init ();

        debug ("Starting arctica-greeter %s UID=%d LANG=%s", Config.VERSION, (int) Posix.getuid (), Environment.get_variable ("LANG"));

        /* Set the cursor to not be the crap default */
        debug ("Setting cursor");
        Gdk.get_default_root_window ().set_cursor (new Gdk.Cursor.for_display (Gdk.Display.get_default (), Gdk.CursorType.LEFT_PTR));

        /* Set GTK+ settings */
        debug ("Setting GTK+ settings");
        var settings = Gtk.Settings.get_default ();
        var value = AGSettings.get_string (AGSettings.KEY_THEME_NAME);
        if (value != ""){
            debug ("Setting GTK theme: %s", value);
            settings.set ("gtk-theme-name", value, null);
        }
        value = AGSettings.get_string (AGSettings.KEY_ICON_THEME_NAME);
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

        /*
         * Keep a reference to an AGSettings instance for the whole program
         * run, so that the SingleInstance property is working the way we'd
         * like it to work.
         *
         * We want to do this before creating the actual greeter, since the
         * latter is using AGSettings quite extensively.
         *
         * This will throw a Vala warning: "local variable `agsettings' declared
         * but never used". Which can be ignored.
         */
        var agsettings = new AGSettings ();

        debug ("Creating Arctica Greeter");
        var greeter = new ArcticaGreeter (do_test_mode, do_test_highcontrast, do_test_bigfont);
        greeter.go();

        string systemd_stderr;
        int systemd_exitcode = 0;

        Pid marco_pid = 0;
        Pid nmapplet_pid = 0;

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

        var launched_indicator_services = new List<string>();

        if (!do_test_mode)
        {

            activate_upower();

            try
            {
                string[] argv;

                Shell.parse_argv ("marco", out argv);
                Process.spawn_async (null,
                                     argv,
                                     null,
                                     SpawnFlags.SEARCH_PATH,
                                     null,
                                     out marco_pid);
                debug ("Launched marco WM. PID: %d", marco_pid);
            }
            catch (Error e)
            {
                warning ("Error starting the Marco Window Manager: %s", e.message);
            }

            greeter.greeter_ready.connect (() => {
                debug ("Showing greeter");
                greeter.show ();
            });

            var indicator_service = "";
            foreach (unowned string indicator in indicator_list)
            {
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
                    string[] argv;

                    Shell.parse_argv ("systemctl --user start %s".printf(indicator_service), out argv);
                    Process.spawn_sync (null,
                                        argv,
                                        null,
                                        SpawnFlags.SEARCH_PATH,
                                        null,
                                        null,
                                        out systemd_stderr,
                                        out systemd_exitcode);

                    if (systemd_exitcode == 0)
                    {
                        launched_indicator_services.append(indicator_service);
                        debug ("Successfully started Indicator Service '%s'", indicator_service);
                    }
                    else {
                        warning ("Systemd failed to start Indicator Service '%s': %s", indicator_service, systemd_stderr);
                    }
                }
                catch (Error e) {
                    warning ("Error starting Indicator Service '%s': %s", indicator_service, e.message);
                }
            }

            /* Make nm-applet hide items the user does not have permissions to interact with */
            Environment.set_variable ("NM_APPLET_HIDE_POLICY_ITEMS", "1", true);

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

            foreach (unowned string indicator_service in launched_indicator_services)
            {

                try {
                    /* Stop this indicator service */
                    string[] argv;

                    Shell.parse_argv ("systemctl --user stop %s".printf(indicator_service), out argv);
                    Process.spawn_sync (null,
                                        argv,
                                        null,
                                        SpawnFlags.SEARCH_PATH,
                                        null,
                                        null,
                                        out systemd_stderr,
                                        out systemd_exitcode);

                    if (systemd_exitcode == 0)
                    {
                        debug ("Successfully stopped Indicator Service '%s' via systemd", indicator_service);
                    }
                    else {
                        warning ("Systemd failed to stop Indicator Service '%s': %s", indicator_service, systemd_stderr);
                    }
                }
                catch (Error e) {
                    warning ("Error stopping Indicator Service '%s': %s", indicator_service, e.message);
                }
            }

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

            if (marco_pid != 0)
            {
#if VALA_0_40
                Posix.kill (marco_pid, Posix.Signal.TERM);
#else
                Posix.kill (marco_pid, Posix.SIGTERM);
#endif
                int status;
                Posix.waitpid (marco_pid, out status, 0);
                if (Process.if_exited (status))
                    debug ("Marco Window Manager exited with return value %d", Process.exit_status (status));
                else
                    debug ("Marco Window Manager terminated with signal %d", Process.term_sig (status));
                marco_pid = 0;
            }
        }

        var screen = Gdk.Screen.get_default ();
        unowned X.Display xdisplay = (screen.get_display () as Gdk.X11.Display).get_xdisplay ();

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

    public void open (uint32 type, uint32 timestamp, uint32 seconds_to_stay_open, ObjectPath[] inhibitor_object_paths)
    {
        open_dialog (type);
    }

    public void close ()
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
