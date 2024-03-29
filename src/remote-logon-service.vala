/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2012 Canonical Ltd
 * Copyright (C) 2015-2016 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 * Copyright (C) 2023 Robert Tari <robert@tari.in>
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
 */

protected struct RemoteServerField
{
    public string type;
    public bool required;
    public Variant default_value;
    public HashTable<string, Variant> properties;
}

protected struct RemoteServerApplication
{
    public string application_id;
    public int pin_position;
}

protected struct RemoteServer
{
    public string type;
    public string name;
    public string url;
    public bool last_used_server;
    public RemoteServerField[] fields;
    public RemoteServerApplication[] applications;
}

[DBus (name = "org.ArcticaProject.RemoteLogon")]
interface RemoteLogonService : Object
{
    public abstract async void get_servers (out RemoteServer[] serverList)  throws GLib.DBusError, GLib.IOError;
    public abstract async void get_servers_for_login (string url, string emailAddress, string password, bool allowCache, out bool loginSuccess, out string dataType, out RemoteServer[] serverList)  throws GLib.DBusError, GLib.IOError;
    public abstract async void get_cached_domains_for_server (string url, out string[] domains)  throws GLib.DBusError, GLib.IOError;
    public abstract async void set_last_used_server (string uccsUrl, string serverUrl) throws GLib.DBusError, GLib.IOError;

    public signal void servers_updated (RemoteServer[] serverList);
    public signal void login_servers_updated (string url, string emailAddress, string dataType, RemoteServer[] serverList);
    public signal void login_changed (string url, string emailAddress);
}
