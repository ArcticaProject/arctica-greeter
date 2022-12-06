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
    public static string font_family = "sans";
    public static int font_size = 11;

    public ToggleBox (string? default_key, string? starting_key)
    {
        Object (default_key: default_key, starting_key: starting_key,
                selected_key: starting_key);

        /* Split font family and size via regular expression. */
        Regex font_regexp = new Regex ("^([[:blank:]]*)(?<font_family>[ a-zA-Z0-9]+) (?<font_size>[0-9]+)([[:blank:]]*)$");
        MatchInfo font_info;
        if (font_regexp.match(font, 0, out font_info)) {
            font_family = font_info.fetch_named("font_family");
            font_size = int.parse(font_info.fetch_named("font_size"));
        }
        debug ("Using font family '%s'.", font_family);
        debug ("Using font size base '%d'.", font_size);
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
                                  "GtkButton, button {\n"+
                                  "   background-color: %s;\n".printf("rgba(0,0,0,0)")+
                                  "   background-image: none;"+
                                  "}\n"+
                                  "button:hover,\n"+
                                  "button:active,\n" +
                                  "button:hover:active,\n" +
                                  "button.selected {\n"+
                                  "   background-color: %s;\n".printf(AGSettings.get_string (AGSettings.KEY_TOGGLEBOX_BUTTON_BGCOLOR))+
                                  "}\n" +
                                  "button.high_contrast {\n" +
                                  "   background-color: %s;\n".printf ("rgba(70, 70, 70, 1.0)") +
                                  "   background-image: none;\n" +
                                  "   border-color: %s\n;".printf ("rgba(0, 0, 0, 1.0)") +
                                  "}\n" +
                                  "button.high_contrast:hover,\n" +
                                  "button.high_contrast:active,\n" +
                                  "button.high_contrast:hover:active,\n" +
                                  "button.high_contrast.selected {\n" +
                                  "   background-color: %s;\n".printf ("rgba(0, 0, 0, 1.0)") +
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

        /* Handle color via CSS. */
        selected_button.get_style_context ().add_class ("selected");
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
        /* Font and other properties are being handled via CSS. */
        label.set_text (name);
        try {
            var style = new Gtk.CssProvider ();
            style.load_from_data ("label {\n" +
                                  "   font-family: \"%s\", sans-serif;\n".printf (font_family) +
                                  "   font-size: %d;\n".printf (font_size + 2) +
                                  "   color: %s;\n".printf (AGSettings.get_string (AGSettings.KEY_TOGGLEBOX_FONT_FGCOLOR)) +
                                  "}\n" +
                                  "label.high_contrast {\n" +
                                  "   color: %s;\n".printf ("rgba(255, 255, 255, 1.0)") +
                                  "}\n", -1);
            label.get_style_context ().add_provider (style, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading session chooser label style: %s", e.message);
        }
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
