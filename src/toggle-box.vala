/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2012 Canonical Ltd
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
 * Authors: Michael Terry <michael.terry@canonical.com>
 *          Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
 */

public class ToggleBox : Gtk.Box
{
    public string default_key {get; construct;}
    public string starting_key {get; construct;}
    public string selected_key {get; protected set;}

    public static string font = AGSettings.get_string (AGSettings.KEY_FONT_NAME);
    public static string font_family = font.split_set(" ")[0];
    public static int font_size = int.parse(font.split_set(" ")[1]);

    public ToggleBox (string? default_key, string? starting_key)
    {
        Object (default_key: default_key, starting_key: starting_key,
                selected_key: starting_key);
    }

    public void add_item (string key, string label, Gdk.Pixbuf? icon)
    {
        var item = make_button (key, label, icon);

        if (get_children () == null ||
            (starting_key == null && default_key == key) ||
            starting_key == key)
            select (item);

        item.show ();
        add (item);
    }

    public void set_normal_button_style (Gtk.Button button)
    {
        try
        {
            /* Tighten padding on buttons to not be so large, default color scheme for buttons */
            var style = new Gtk.CssProvider ();
            style.load_from_data ("* {padding: 8px;}\n"+
                                  "GtkButton {\n"+
                                  "   background-color: %s;\n".printf("rgba(0,0,0,0)")+
                                  "   background-image: none;"+
                                  "}\n"+
                                  ".button:hover,\n"+
                                  ".button:hover:active {\n"+
                                  "   background-color: %s;\n".printf(AGSettings.get_string (AGSettings.KEY_TOGGLEBOX_BUTTON_BGCOLOR))+
                                  "}\n", -1);
            button.get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading session chooser style: %s", e.message);
        }
        return;
    }

    private Gtk.Button selected_button;

    construct
    {
        orientation = Gtk.Orientation.VERTICAL;
    }

    public override bool draw (Cairo.Context c)
    {
        Gtk.Allocation allocation;
        get_allocation (out allocation);

        CairoUtils.rounded_rectangle (c, 0, 0, allocation.width,
                                      allocation.height, 0.1 * grid_size);
        c.set_source_rgba (0.5, 0.5, 0.5, 0.5);
        c.set_line_width (1);
        c.stroke ();

        return base.draw (c);
    }

    private void select (Gtk.Button button)
    {
        if (selected_button != null)
        {
            selected_button.get_style_context ().remove_class ("selected");
            set_normal_button_style (selected_button);
        }
        selected_button = button;
        selected_key = selected_button.get_data<string> ("toggle-list-key");

        var bg_color = Gdk.RGBA ();
        bg_color.parse (AGSettings.get_string (AGSettings.KEY_TOGGLEBOX_BUTTON_BGCOLOR));
        selected_button.override_background_color(Gtk.StateFlags.NORMAL, bg_color);
    }

    private Gtk.Button make_button (string key, string name_in, Gdk.Pixbuf? icon)
    {
        var item = new FlatButton ();
        item.relief = Gtk.ReliefStyle.NONE;
        item.clicked.connect (button_clicked_cb);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

        if (icon != null)
        {
            var image = new CachedImage (icon);
            hbox.pack_start (image, false, false, 0);
        }

        var name = name_in;
        if (key == default_key)
        {
            /* Translators: %s is a session name like KDE or Ubuntu */
            name = _("%s (Default)").printf (name);
        }

        var label = new Gtk.Label (null);
        label.set_markup ("<span font=\"%s %d\" fgcolor=\"%s\">%s</span>".printf (font_family, font_size+2, AGSettings.get_string (AGSettings.KEY_TOGGLEBOX_FONT_FGCOLOR), name));
        label.halign = Gtk.Align.START;
        hbox.pack_start (label, true, true, 0);

        item.hexpand = true;
        item.add (hbox);
        hbox.show_all ();

        set_normal_button_style (item);

        item.set_data<string> ("toggle-list-key", key);
        return item;
    }

    private void button_clicked_cb (Gtk.Button button)
    {
        selected_key = button.get_data<string> ("toggle-list-key");
    }

    public override void grab_focus ()
    {
        if (selected_button != null)
            selected_button.grab_focus ();
    }
}
