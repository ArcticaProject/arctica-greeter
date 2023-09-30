/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
 * Copyright (C) 2015-2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 * Copyright (C) 2022 Mihai Moldovan <ionic@ionic.de>
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
 *          Mihai Moldovan <ionic@ionic.de>
 */

#if !HAVE_GTK_4_0
[CCode(cname = "GTK_IS_CONTAINER", cheader_filename="gtk/gtk.h", simple_generics = true, has_target = false)]
static extern bool gtk_is_container<T> (T widget);
#endif

namespace AGUtils {
    public void greeter_set_env (string key, string val)
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

            debug ("Updating DBus activation environment, updating '%s' to '%s'", key, val);
            proxy.call_sync ("UpdateActivationEnvironment", new GLib.Variant ("(a{ss})", builder), GLib.DBusCallFlags.NONE, -1, null);
        }
        catch (Error e)
        {
            warning ("Could not set environment variable '%s' to '%s', error was: '%s'", key, val, e.message);
            return;
        }
    }
}
