/* -*- Mode:Vala; indent-tabs-mode:nil; tab-width:4 -*-
 *
 * Copyright (C) 2011 Canonical Ltd
 * Copyright (C) 2015,2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
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
 * Authored by: Michael Terry <michael.terry@canonical.com>
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 */

public class SettingsDaemon : Object
{
    private int sd_pid = 0;
    private int logind_inhibit_fd = -1;
    private ScreenSaverInterface screen_saver;
    private SessionManagerInterface session_manager;
    private int n_names = 2;

    public void start ()
    {
        string[] disabled = { "org.mate.settings-daemon.plugins.background",
                              "org.mate.settings-daemon.plugins.clipboard",
                              "org.mate.settings-daemon.plugins.housekeeping",
                              "org.mate.settings-daemon.plugins.keybindings",
                              "org.mate.settings-daemon.plugins.keyboard",
                              "org.mate.settings-daemon.plugins.media-keys",
                              "org.mate.settings-daemon.plugins.mouse",
                              "org.mate.settings-daemon.plugins.mpris",
                              "org.mate.settings-daemon.plugins.smartcard",
                              "org.mate.settings-daemon.plugins.sound",
                              "org.mate.settings-daemon.plugins.typing-break",
                              "org.mate.settings-daemon.plugins.xrdb" };

        string[] enabled =  { "org.mate.settings-daemon.plugins.a11y-keyboard",
                              "org.mate.settings-daemon.plugins.a11y-settings",
                              "org.mate.settings-daemon.plugins.xrandr",
                              "org.mate.settings-daemon.plugins.xsettings" };

        foreach (var schema in disabled)
            set_plugin_enabled (schema, false);

        foreach (var schema in enabled)
            set_plugin_enabled (schema, true);

        /* Pretend to be MATE/GNOME session */
        session_manager = new SessionManagerInterface ();
        GLib.Bus.own_name (BusType.SESSION, "org.gnome.SessionManager", BusNameOwnerFlags.NONE,
                           (c) =>
                           {
                               try
                               {
                                   c.register_object ("/org/gnome/SessionManager", session_manager);
                               }
                               catch (Error e)
                               {
                                   warning ("Failed to register /org/gnome/SessionManager: %s", e.message);
                               }
                           },
                           () =>
                           {
                               debug ("Acquired org.gnome.SessionManager");
                               start_settings_daemon ();
                           },
                           () => debug ("Failed to acquire name org.gnome.SessionManager"));

        /* The power plugin does the screen saver screen blanking and disables
         * the builtin X screen saver. It relies on mate-screensaver to generate
         * the event to trigger this (which actually comes from mate-session).
         * We implement the mate-screensaver inteface and start the settings
         * daemon once it is registered on the bus so mate-screensaver is not
         * started when it accesses this interface */
        screen_saver = new ScreenSaverInterface ();
        GLib.Bus.own_name (BusType.SESSION, "org.gnome.ScreenSaver", BusNameOwnerFlags.NONE,
                           (c) =>
                           {
                               try
                               {
                                   c.register_object ("/org/gnome/ScreenSaver", screen_saver);
                               }
                               catch (Error e)
                               {
                                   warning ("Failed to register /org/gnome/ScreenSaver: %s", e.message);
                               }
                           },
                           () =>
                           {
                               debug ("Acquired org.gnome.ScreenSaver");
                               start_settings_daemon ();
                           },
                           () => debug ("Failed to acquire name org.gnome.ScreenSaver"));

        /* The media-keys plugin inhibits the power key, but we don't want
           all the other keys doing things. So inhibit it ourselves */
        /* NOTE: We are using the synchronous method here since there is a bug in Vala/GLib in that
         * g_dbus_connection_call_with_unix_fd_list_finish and g_dbus_proxy_call_with_unix_fd_list_finish
         * don't have the GAsyncResult as the second argument.
         * https://bugzilla.gnome.org/show_bug.cgi?id=688907
         */
        try
        {
            var b = Bus.get_sync (BusType.SYSTEM);
            UnixFDList fd_list;
            var result = b.call_with_unix_fd_list_sync  ("org.freedesktop.login1",
                                                         "/org/freedesktop/login1",
                                                         "org.freedesktop.login1.Manager",
                                                         "Inhibit",
                                                         new Variant ("(ssss)",
                                                                      "handle-power-key",
                                                                      Environment.get_user_name (),
                                                                      "Arctica Greeter handling keypresses",
                                                                      "block"),
                                                         new VariantType ("(h)"),
                                                         DBusCallFlags.NONE,
                                                         -1,
                                                         null,
                                                         out fd_list);
            int32 index = -1;
            result.get ("(h)", &index);
            logind_inhibit_fd = fd_list.get (index);
        }
        catch (Error e)
        {
            warning ("Failed to inhibit power keys: %s", e.message);
        }
    }

    public void stop ()
    {
        stop_settings_daemon();
    }

    private void set_plugin_enabled (string schema_name, bool enabled)
    {
        var source = SettingsSchemaSource.get_default ();
        var schema = source.lookup (schema_name, false);
        if (schema != null)
        {
            var settings = new Settings (schema_name);
            settings.set_boolean ("active", enabled);
        }
    }

    private void start_settings_daemon ()
    {
        n_names--;
        if (n_names != 0)
            return;

        debug ("All bus names acquired, starting %s", Config.SD_BINARY);

        try
        {
            string[] argv;

            Shell.parse_argv (Config.SD_BINARY, out argv);
            Process.spawn_async (null,
                                 argv,
                                 null,
                                 SpawnFlags.SEARCH_PATH,
                                 null,
                                 out sd_pid);
            debug ("Launched %s. PID: %d", Config.SD_BINARY, sd_pid);
        }
        catch (Error e)
        {
            debug ("Could not start %s: %s", Config.SD_BINARY, e.message);
        }
    }

    private void stop_settings_daemon ()
    {
        if (sd_pid != 0)
        {
#if VALA_0_40
            Posix.kill (sd_pid, Posix.Signal.KILL);
#else
            Posix.kill (sd_pid, Posix.SIGKILL);
#endif
            int status;
            Posix.waitpid (sd_pid, out status, 0);
            if (Process.if_exited (status))
                debug ("SettingsDaemon exited with return value %d", Process.exit_status (status));
            else
                debug ("SettingsDaemon terminated with signal %d", Process.term_sig (status));
            sd_pid = 0;
        }
    }

}

[DBus (name="org.gnome.ScreenSaver")]
public class ScreenSaverInterface : Object
{
    public signal void active_changed (bool value);

    private IdleMonitor idle_monitor;
    private bool _active = false;
    private uint idle_watch = 0;

    public ScreenSaverInterface ()
    {
        idle_monitor = new IdleMonitor ();
        _set_active (false);
    }

    private void _set_active (bool value)
    {
        _active = value;
        if (idle_watch != 0)
            idle_monitor.remove_watch (idle_watch);
        idle_watch = 0;
        if (value)
            idle_monitor.add_user_active_watch (() => set_active (false));
        else
        {
            var timeout = AGSettings.get_integer (AGSettings.KEY_IDLE_TIMEOUT);
            if (timeout > 0)
                idle_watch = idle_monitor.add_idle_watch (timeout * 1000, () => set_active (true));
        }
    }

    public void set_active (bool value)
    {
        if (_active == value)
            return;

        if (value)
            debug ("Screensaver activated");
        else
            debug ("Screensaver disabled");

        _set_active (value);
        active_changed (value);
    }

    public bool get_active ()
    {
        return _active;
    }

    public uint32 get_active_time () { return 0; }
    public void lock () {}
    public void show_message (string summary, string body, string icon) {}
    public void simulate_user_activity () {}
}

[DBus (name="org.gnome.SessionManager")]
public class SessionManagerInterface : Object
{
    public bool session_is_active { get { return true; } }
    public string session_name { get { return "greeter"; } }
    public uint32 inhibited_actions { get { return 0; } }
}
