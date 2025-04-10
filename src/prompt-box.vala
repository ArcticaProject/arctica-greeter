/* -*- Mode: Vala; indent-tabs-mode: nil; tab-width: 4 -*-
 *
 * Copyright (C) 2011,2012 Canonical Ltd
 * Copyright (C) 2015,2017 Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
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

public class PromptBox : FadableBox
{
    public signal void respond (string[] response);
    public signal void login ();
    public signal void show_options ();
    public signal void name_clicked ();

    public static string font = AGSettings.get_string (AGSettings.KEY_FONT_NAME);
    public static string font_family = "sans";
    public static int font_size = 11;
    public bool has_errors { get; set; default = false; }
    public string id { get; construct; }

    public string label
    {
        get { return name_label.label; }
        set
        {
            name_label.label = value;
            small_name_label.label = value;
        }
    }

    public double position { get; set; default = 0; }

    private Gtk.Fixed fixed;
    private Gtk.Widget zone; /* when overlapping zone we are fully expanded */

    /* Expanded widgets */
    protected Gtk.Grid box_grid;
    protected Gtk.Grid name_grid;
    private ActiveIndicator active_indicator;
    protected FadingLabel name_label;
    protected FlatButton option_button;
    private CachedImage option_image;
    private CachedImage message_image;

    /* Condensed widgets */
    protected Gtk.Widget small_box_widget;
    private ActiveIndicator small_active_indicator;
    protected FadingLabel small_name_label;
    private CachedImage small_message_image;

    protected const int COL_ACTIVE        = 0;
    protected const int COL_CONTENT       = 1;
    protected const int COL_SPACER        = 2;

    protected const int ROW_NAME          = 0;
    protected const int COL_NAME_LABEL    = 0;
    protected const int COL_NAME_MESSAGE  = 1;
    protected const int COL_NAME_OPTIONS  = 2;

    protected const int COL_ENTRIES_START = 1;
    protected const int COL_ENTRIES_END   = 1;
    protected const int COL_ENTRIES_WIDTH = 1;

    protected int start_row;
    protected int last_row;

    private enum PromptVisibility
    {
        HIDDEN,
        FADING,
        SHOWN,
    }
    private PromptVisibility prompt_visibility = PromptVisibility.HIDDEN;

    public PromptBox (string id)
    {
        Object (id: id);
    }

    construct
    {
        resize_mode = Gtk.ResizeMode.QUEUE;
        var greeter = new ArcticaGreeter();

        set_start_row ();
        reset_last_row ();
        expand = true;

        fixed = new Gtk.Fixed ();
        fixed.show ();
        add (fixed);

        box_grid = new Gtk.Grid ();
        box_grid.column_spacing = 4;
        box_grid.row_spacing = 3;
        box_grid.margin_top = (int)(GreeterList.BORDER * greeter.scaling_factor_widgets);
        box_grid.margin_bottom = 6;
        box_grid.expand = true;

        /** Grid layout:
          0 1     2      3 4
          > Name  M      S <
            Message.......
            Entry.........
         */

        if (font_size < 6)
            font_size = 6;

        active_indicator = new ActiveIndicator ();
        active_indicator.valign = Gtk.Align.START;
        active_indicator.margin_top = (greeter.grid_size - ActiveIndicator.HEIGHT) / 2;
        active_indicator.show ();
        box_grid.attach (active_indicator, COL_ACTIVE, last_row, 1, 1);

        /* Add a second one on right just for equal-spacing purposes */
        var dummy_indicator = new ActiveIndicator ();
        dummy_indicator.show ();
        box_grid.attach (dummy_indicator, COL_SPACER, last_row, 1, 1);

        box_grid.show ();

        /* Create fully expanded version of ourselves */
        name_grid = create_name_grid ();
        box_grid.attach (name_grid, COL_CONTENT, last_row, 1, 1);

        /* Now prep small versions of the above normal widgets.  These are
         * used when scrolling outside of the main dash box. */
        var small_box_grid = new Gtk.Grid ();
        small_box_grid.column_spacing = 4;
        small_box_grid.row_spacing = 6;
        small_box_grid.hexpand = true;
        small_box_grid.show ();

        small_active_indicator = new ActiveIndicator ();
        small_active_indicator.valign = Gtk.Align.START;
        small_active_indicator.margin_top = (greeter.grid_size - ActiveIndicator.HEIGHT) / 2;
        small_active_indicator.show ();
        small_box_grid.attach (small_active_indicator, 0, 0, 1, 1);

        var small_name_grid = create_small_name_grid ();
        small_box_grid.attach (small_name_grid, 1, 0, 1, 1);

        /* Add a second indicator on right just for equal-spacing purposes */
        var small_dummy_indicator = new ActiveIndicator ();
        small_dummy_indicator.show ();
        small_box_grid.attach (small_dummy_indicator, 3, 0, 1, 1);

        var small_box_eventbox = new Gtk.EventBox ();
        small_box_eventbox.visible_window = false;
        small_box_eventbox.button_release_event.connect (() =>
        {
            name_clicked ();
            return true;
        });
        small_box_eventbox.add (small_box_grid);
        small_box_eventbox.show ();
        small_box_widget = small_box_eventbox;

        fixed.add (small_box_widget);
        fixed.add (box_grid);

        /* Split font family and size via regular expression. */
        Regex font_regexp = null;

        try
        {
            font_regexp = new Regex ("^([[:blank:]]*)(?<font_family>[ a-zA-Z0-9]+) (?<font_size>[0-9]+)([[:blank:]]*)$");
        }
        catch (GLib.RegexError pError)
        {
            error ("Panic: Failed constructing RegEx: %s", pError.message);
        }

        MatchInfo font_info;
        if (font_regexp.match(font, 0, out font_info)) {
            font_family = font_info.fetch_named("font_family");
            font_size = int.parse(font_info.fetch_named("font_size"));
        }
        debug ("Using font family '%s'.", font_family);
        debug ("Using font size base '%d'.", font_size);
    }

    protected virtual Gtk.Grid create_name_grid ()
    {
        var name_grid = new Gtk.Grid ();
        name_grid.column_spacing = 4;
        name_grid.hexpand = true;

        name_label = new FadingLabel ("");

        var style_ctx = name_label.get_style_context();
        try
        {
            var font_provider = new Gtk.CssProvider ();
            var css = "* {font-family: %s; font-size: %dpt;}".printf (font_family, font_size+2);
            font_provider.load_from_data (css, -1);
            style_ctx.add_provider (font_provider,
                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading font style (%s, %dpt): %s", font_family, font_size+2, e.message);
        }

        try
        {
            var color_provider = new Gtk.CssProvider ();
            var css = "* { color: rgba(255, 255, 255, 1.0); }\n" +
                      ".high_contrast { color: rgba (0, 0, 0, 1.0); }";
            color_provider.load_from_data (css, -1);
            style_ctx.add_provider (color_provider,
                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error setting color on name label: %s", e.message);
        }

        var greeter = new ArcticaGreeter();

        name_label.valign = Gtk.Align.START;
        name_label.vexpand = true;
        name_label.yalign = 0.5f;
        name_label.xalign = 0.0f;
        name_label.margin_start = 2;
        name_label.set_size_request (-1, greeter.grid_size);
        name_label.show ();
        name_grid.attach (name_label, COL_NAME_LABEL, ROW_NAME, 1, 1);

        message_image = new CachedImage (null);
        message_image.set_from_icon_name("mail-unread", Gtk.IconSize.BUTTON);

        var align = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        align.valign = Gtk.Align.START;
        align.set_size_request (-1, greeter.grid_size);
        align.add (message_image);
        align.show ();
        name_grid.attach (align, COL_NAME_MESSAGE, ROW_NAME, 1, 1);

        option_button = new FlatButton ();
        var option_button_ctx = option_button.get_style_context ();
        option_button_ctx.add_class ("option-button");

        try {
            /*
             * Override background for both high-contrast and normal modes.
             * Note that we have to use CSS selectors here, since this code
             * is only executed once.
             */
            var background_style = new Gtk.CssProvider ();
            background_style.load_from_data ("button.flat.option-button.high_contrast {\n" +
                                             "   background-color: %s;\n".printf("rgba(0,0,0,1.0)") +
                                             "   background-image: none;\n" +
                                             "}\n" +
                                             "button.flat.option-button:hover:not(.high_contrast), " +
                                             "button.flat.option-button:active:not(.high_contrast), " +
                                             "button.flat.option-button:hover:active:not(.high_contrast) {\n"+
                                             "   background-color: %s;\n".printf("rgba(255,255,255,0.5)")+
                                             "   background-image: none;"+
                                             "}\n" +
                                             "button.flat.option-button:hover.high_contrast," +
                                             "button.flat.option-button:active.high_contrast," +
                                             "button.flat.option-button:hover:active.high_contrast {\n" +
                                             "   background-color:%s;\n".printf("rgba(70, 70, 70, 1.0)") +
                                             "   background-image: none;" +
                                             "}\n", -1);
            option_button_ctx.add_provider (background_style,
                                            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading option button background style: %s", e.message);
        }

        option_button.hexpand = true;
        option_button.halign = Gtk.Align.END;
        option_button.valign = Gtk.Align.START;
        // Keep as much space on top as on the right
        option_button.margin_top = ActiveIndicator.WIDTH + box_grid.column_spacing;
        Gtk.button_set_focus_on_click (option_button, false);
        option_button.relief = Gtk.ReliefStyle.NONE;
        option_button.get_accessible ().set_name (_("Session Options"));
        option_button.clicked.connect (option_button_clicked_cb);
        option_image = new CachedImage (null);
        option_image.show ();

        option_button.add (option_image);
        name_grid.attach (option_button, COL_NAME_OPTIONS, ROW_NAME, 1, 1);

        name_grid.show ();

        return name_grid;
    }

    protected virtual Gtk.Grid create_small_name_grid ()
    {
        var small_name_grid = new Gtk.Grid ();
        small_name_grid.column_spacing = 4;

        small_name_label = new FadingLabel ("");

    var style_ctx = small_name_label.get_style_context();

        try
        {
            var font_provider = new Gtk.CssProvider ();
            var css = "* {font-family: %s; font-size: %dpt;}".printf (font_family, font_size);
            font_provider.load_from_data (css, -1);
            style_ctx.add_provider (font_provider,
                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading font style (%s, %dpt): %s", font_family, font_size, e.message);
        }

        var greeter = new ArcticaGreeter();

        small_name_label.override_color (Gtk.StateFlags.NORMAL, { 1.0f, 1.0f, 1.0f, 1.0f });
        small_name_label.yalign = 0.5f;
        small_name_label.xalign = 0.0f;
        small_name_label.margin_start = 2;
        small_name_label.set_size_request (-1, greeter.grid_size);
        small_name_label.show ();
        small_name_grid.attach (small_name_label, 1, 0, 1, 1);

        small_message_image = new CachedImage (null);
        small_message_image.set_from_icon_name("mail-unread", Gtk.IconSize.BUTTON);

        var align = new Gtk.Alignment (0.5f, 0.5f, 0.0f, 0.0f);
        align.set_size_request (-1, greeter.grid_size);
        align.add (small_message_image);
        align.show ();
        small_name_grid.attach (align, 2, 0, 1, 1);

        small_name_grid.show ();
        return small_name_grid;
    }

    protected virtual void set_start_row ()
    {
        start_row = 0;
    }

    protected virtual void reset_last_row ()
    {
        last_row = start_row;
    }

#if HAVE_GTK_3_20_0
    private int round_to_grid (int size)
    {
        var greeter = new ArcticaGreeter();

        var num_grids = size / greeter.grid_size;
        var remainder = size % greeter.grid_size;
        if (remainder > 0)
            num_grids += 1;
        num_grids = int.max (num_grids, 3);
        return num_grids * greeter.grid_size;
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        base.get_preferred_height (out min, out nat);

        var greeter = new ArcticaGreeter();

        int double_border_scaled = (int)(GreeterList.BORDER * greeter.scaling_factor_widgets * 2);
        min = round_to_grid (min + double_border_scaled) - double_border_scaled;
        nat = round_to_grid (nat + double_border_scaled) - double_border_scaled;

        if (position <= -1 || position >= 1)
            min = nat = greeter.grid_size;
    }
#endif

    public void set_zone (Gtk.Widget zone)
    {
        this.zone = zone;
        queue_draw ();
    }

    public void set_options_image (Gdk.Pixbuf? image, string? tooltip)
    {
        if (option_button == null)
            return;

        option_image.set_pixbuf (image);

        if (tooltip == null)
            option_image.set_tooltip_text("");
        else
            option_image.set_tooltip_text(tooltip);

        if (image == null)
            option_button.hide ();
        else
            option_button.show ();
    }

    private void option_button_clicked_cb (Gtk.Button button)
    {
        show_options ();
    }

    public void set_show_message_icon (bool show)
    {
        message_image.visible = show;
        small_message_image.visible = show;
    }

    public void set_is_active (bool active)
    {
        active_indicator.active = active;
        small_active_indicator.active = active;
    }

    protected void foreach_prompt_widget (Gtk.Callback cb)
    {
        var prompt_widgets = new List<Gtk.Widget> ();

        var i = start_row + 1;
        while (i <= last_row)
        {
            var c = box_grid.get_child_at (COL_ENTRIES_START, i);
            if (c != null) /* c might have been deleted from selective clear */
                prompt_widgets.append (c);
            i++;
        }

        foreach (var w in prompt_widgets)
            cb (w);
    }

    public void clear ()
    {
        prompt_visibility = PromptVisibility.HIDDEN;
        active_indicator.expanded = false;

        /* Hold a ref while removing the prompt widgets -
         * if we just do w.destroy() we get this warning:
         * CRITICAL: pango_layout_get_cursor_pos: assertion 'index >= 0 && index <= layout->length' failed
         * by GtkWidget's screen-changed signal being called on
         * widget when we destroy it.
         */
        foreach_prompt_widget ((w) => {
#if HAVE_GTK_3_20_0
            w.ref ();
            w.get_parent().remove(w);
            w.unref ();
#else
            w.destroy ();
#endif
        });

        reset_last_row ();
        has_errors = false;
    }

    /* Clears error messages */
    public void reset_messages ()
    {
        has_errors = false;
        foreach_prompt_widget ((w) =>
        {
            var is_error = w.get_data<bool> ("prompt-box-is-error");
            if (is_error)
                w.destroy ();
        });
    }

    /* Stops spinners */
    public void reset_spinners ()
    {
        foreach_prompt_widget ((w) =>
        {
            if (w is DashEntry)
            {
                var e = w as DashEntry;
                e.did_respond = false;
            }
        });
    }

    /* Clears error messages and stops spinners.  Basically gets the box back to a filled-by-user-but-no-status state. */
    public void reset_state ()
    {
        reset_messages ();
        reset_spinners ();
    }

    public virtual void add_static_prompts ()
    {
        /* Subclasses may want to add prompts that are always present here */
    }

    private void update_prompt_visibility (Gtk.Widget w)
    {
        switch (prompt_visibility)
        {
        case PromptVisibility.HIDDEN:
            w.hide ();
            active_indicator.expanded = false;
            break;
        case PromptVisibility.FADING:
            var f = w as Fadable;
            w.sensitive = true;
            if (f != null)
                f.fade_in ();
            else
                w.show ();
            active_indicator.expanded = true;
            break;
        case PromptVisibility.SHOWN:
            w.show ();
            w.sensitive = true;
            active_indicator.expanded = true;
            break;
        }
    }

    public void fade_in_prompts ()
    {
        prompt_visibility = PromptVisibility.FADING;
        show ();
        foreach_prompt_widget ((w) => { update_prompt_visibility (w); });
        active_indicator.expanded = true;
    }

    public void show_prompts ()
    {
        prompt_visibility = PromptVisibility.SHOWN;
        show ();
        foreach_prompt_widget ((w) => { update_prompt_visibility (w); });
        active_indicator.expanded = true;
    }

    protected void attach_item (Gtk.Widget w, bool add_style_class = true)
    {
        w.set_data ("prompt-box-widget", this);
        if (add_style_class)
            ArcticaGreeter.add_style_class (w);

        last_row += 1;
        box_grid.attach (w, COL_ENTRIES_START, last_row, COL_ENTRIES_WIDTH, 1);

        update_prompt_visibility (w);
        queue_resize ();
    }

    public void add_message (string text, bool is_error)
    {
        var label = new FadingLabel (text);

        var style_ctx = label.get_style_context();

        try
        {
            var font_provider = new Gtk.CssProvider ();
            var css = "* {font-family: %s; font-size: %dpt; color: white}
                       *.high_contrast {color: black; }".printf (font_family, font_size-1);
            font_provider.load_from_data (css, -1);
            style_ctx.add_provider (font_provider,
                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading font style (%s, %dpt): %s", font_family, font_size-1, e.message);
        }

        if (is_error) {

            /* red */
            Gdk.RGBA color = { 1.0f, 1.0f, 1.0f, 1.0f };
            color.parse ("#820900");

            /*
             * Overriding the background color will look ugly, but at least
             * always make the text readable, which is probably important for
             * error messages.
             * We probably want to find a better way of handling this.
             */
            Gdk.RGBA bg_color = { 1.0f, 1.0f, 1.0f, 1.0f };
            label.override_background_color (Gtk.StateFlags.NORMAL, bg_color);
            label.override_color (Gtk.StateFlags.NORMAL, color);
        }

        label.xalign = 0.0f;
        label.set_data<bool> ("prompt-box-is-error", is_error);

        attach_item (label);

        if (is_error)
            has_errors = true;
    }

    public DashEntry add_prompt (string text, string? accessible_text, bool is_secret)
    {
        /* Stop other entry's arrows/spinners from showing */
        foreach_prompt_widget ((w) =>
        {
            if (w is DashEntry)
            {
                var e = w as DashEntry;
                if (e != null)
                    e.can_respond = false;
            }
        });

        var entry = new DashEntry ();
        entry.sensitive = false;

        if (text.contains ("\n"))
        {
            add_message (text, false);
            entry.constant_placeholder_text = "";
        }
        else
        {
            /* Strip trailing colon if present (also handle CJK version) */
            var placeholder = text;
            if (placeholder.has_suffix (":") || placeholder.has_suffix ("："))
            {
                var len = placeholder.char_count ();
                placeholder = placeholder.substring (0, placeholder.index_of_nth_char (len - 1));
            }
            entry.constant_placeholder_text = placeholder;
        }

        var accessible = entry.get_accessible ();
        if (accessible_text != null)
            accessible.set_name (accessible_text);
        else
            accessible.set_name (text);

        if (is_secret)
        {
            entry.visibility = false;
            entry.caps_lock_warning = true;
            entry.button_release_event.connect ((widget, event) => {
                if (event.button == 1)
                    show_toggle_visibility_icon (entry);
                return false;
            });
            entry.key_press_event.connect ((widget, event) => {
                switch (event.keyval) {
                    case Gdk.Key.Left:
                    case Gdk.Key.KP_Left:
                    case Gdk.Key.Right:
                    case Gdk.Key.KP_Right:
                        show_toggle_visibility_icon (entry);
                        return false;
                    case Gdk.Key.F8:
                        if (Gdk.ModifierType.MOD1_MASK in event.state) {
                            entry.set_visibility (!entry.get_visibility ());
                            show_toggle_visibility_icon (entry);
                            return true;
                        }
                        break;
                }
                return base.key_press_event (event);
            });
            entry.icon_press.connect(entry_icon_press_cb);
        }

        entry.respond.connect (entry_activate_cb);

        attach_item (entry);

        return entry;
    }

    public void show_toggle_visibility_icon (Gtk.Entry entry)
    {
        if (entry.get_visibility ()) {
            entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "view-conceal-symbolic");
        }
        else {
            entry.set_icon_from_icon_name(Gtk.EntryIconPosition.PRIMARY, "view-reveal-symbolic");
        }
    }

    public void entry_icon_press_cb (Gtk.Entry entry, Gtk.EntryIconPosition position, Gdk.Event event)
    {
        entry.set_visibility (!entry.get_visibility ());
        show_toggle_visibility_icon (entry);
    }

    public Gtk.ComboBox add_combo (GenericArray<string> texts, bool read_only)
    {
        Gtk.ComboBoxText combo;
        if (read_only)
            combo = new Gtk.ComboBoxText ();
        else
            combo = new Gtk.ComboBoxText.with_entry ();

        combo.get_style_context ().add_class ("lightdm-combo");
        combo.get_child ().get_style_context ().add_class ("lightdm-combo");

        var style_ctx = combo.get_child ().get_style_context();
        try
        {
            var font_provider = new Gtk.CssProvider ();
            var css = "* {font-family: %s; font-size: %dpt;}".printf (DashEntry.font_family, DashEntry.font_size);
            font_provider.load_from_data (css, -1);
            style_ctx.add_provider (font_provider,
                                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
        catch (Error e)
        {
            debug ("Internal error loading font style (%s, %dpt): %s", font_family, font_size+2, e.message);
        }

        attach_item (combo, false);

        texts.foreach ((text) => { combo.append_text (text); });

        if (texts.length > 0)
            combo.active = 0;

        return combo;
    }

    protected void entry_activate_cb ()
    {
        var response = new string[0];

        foreach_prompt_widget ((w) =>
        {
            if (w is Gtk.Entry)
            {
                var e = w as Gtk.Entry;
                if (e != null)
                    response += e.text;
            }
        });
        respond (response);
    }

    public void add_button (string text, string? accessible_text)
    {
        var button = new DashButton (text);

        var accessible = button.get_accessible ();
        accessible.set_name (accessible_text);

        button.clicked.connect (button_clicked_cb);

        attach_item (button);
    }

    private void button_clicked_cb (Gtk.Button button)
    {
        login ();
    }

    public override void grab_focus ()
    {
        var done = false;
        Gtk.Widget best = null;
        foreach_prompt_widget ((w) =>
        {
            if (done)
                return;
            best = w; /* last entry wins, all else considered */
            var e = w as Gtk.Entry;
            var b = w as Gtk.Button;
            var c = w as Gtk.ComboBox;

            /* We've found ideal entry (first empty one), so stop looking */
            if ((e != null && e.text == "") || b != null || c != null)
                done = true;
        });
        if (best != null)
            best.grab_focus ();
    }

    public override void size_allocate (Gtk.Allocation allocation)
    {
        base.size_allocate (allocation);
        box_grid.size_allocate (allocation);

        int small_height;
        small_box_widget.get_preferred_height (null, out small_height);
        allocation.height = small_height;
        small_box_widget.size_allocate (allocation);
    }

    public override void draw_full_alpha (Cairo.Context c)
    {
        /* Draw either small or normal version of ourselves, depending on where
           our allocation put us relative to our zone */
        int x, y;
        zone.translate_coordinates (this, 0, 0, out x, out y);

        Gtk.Allocation alloc, zone_alloc;
        this.get_allocation (out alloc);
        zone.get_allocation (out zone_alloc);

        /* Draw main grid only in that area */
        c.save ();
        c.rectangle (x, y, zone_alloc.width, zone_alloc.height);
        c.clip ();
        fixed.propagate_draw (box_grid, c);
        c.restore ();

        /* Do actual drawing */
        c.save ();
        if (y > 0)
            c.rectangle (x, 0, zone_alloc.width, y);
        else
            c.rectangle (x, y + zone_alloc.height, zone_alloc.width, -y);
        c.clip ();
        fixed.propagate_draw (small_box_widget, c);
        c.restore ();
    }
}

private class ActiveIndicator : Gtk.Image
{
    public bool active { get; set; }
    public bool expanded { get; set; }
    public const int WIDTH = 8;
    public const int HEIGHT = 7;

    construct
    {
        var filename = Path.build_filename (Config.PKGDATADIR, "active.png");
        try
        {
            pixbuf = new Gdk.Pixbuf.from_file (filename);
            pixbuf_changed_helper ();
        }
        catch (Error e)
        {
            debug ("Could not load active image: %s", e.message);
        }
        notify["active"].connect (() => { queue_draw (); });
        notify["expanded"].connect (() => { notify_expanded (); });
        notify["pixbuf"].connect ((s, p) => { notify_pixbuf_changed (s, p); });
        this.style_updated.connect ((w) => { handle_style_updated (w); });
        xalign = 0.0f;
    }

    public override void get_preferred_width (out int min, out int nat)
    {
        var greeter = new ArcticaGreeter();
        min = (int)Math.round(WIDTH * greeter.scaling_factor_widgets);
        nat = min;
    }

    public override void get_preferred_height (out int min, out int nat)
    {
        var greeter = new ArcticaGreeter();
        min = (int)Math.round(HEIGHT * greeter.scaling_factor_widgets);
        nat = min;
    }

    public override bool draw (Cairo.Context c)
    {
        if (!active)
            return false;

        return base.draw (c);
    }

    private void notify_pixbuf_changed (Object src, ParamSpec prop) {
        assert ("pixbuf" == prop.name);

        if (!(this.swapping_)) {
            pixbuf_changed_helper ();
        }
    }

    private void pixbuf_changed_helper () {
        /* Copy the new pixbuf. */
        this.pixbuf_orig_ = this.pixbuf.copy ();
        this.pixbuf.copy_options (this.pixbuf_orig_);
        this.pixbuf_inverted_ = this.pixbuf.copy ();
        this.pixbuf.copy_options (this.pixbuf_inverted_);

        /* Invert the new pixbuf. */
        invert_pixbuf ();

        if (this.inverted_) {
            this.swapping_ = true;
            this.pixbuf = this.pixbuf_inverted_;
            this.swapping_ = false;
        }
    }

    private void handle_style_updated (Gtk.Widget widget) {
        var style_ctx = this.get_style_context ();
        if (style_ctx.has_class ("high_contrast")) {
            if ((!(this.inverted_)) && (this.expanded)) {
                this.swapping_ = true;
                this.pixbuf = this.pixbuf_inverted_;
                this.inverted_ = true;
                this.swapping_ = false;
            }
        }
        else {
            if (this.inverted_) {
                this.swapping_ = true;
                this.pixbuf = this.pixbuf_orig_;
                this.inverted_ = false;
                this.swapping_ = false;
            }
        }
    }

    private void invert_pixbuf () {
        assert (Gdk.Colorspace.RGB == this.pixbuf_inverted_.get_colorspace ());
        var sample_size = this.pixbuf_inverted_.get_bits_per_sample ();
        var alpha = this.pixbuf_inverted_.get_has_alpha ();
        var channels = this.pixbuf_inverted_.get_n_channels ();

        assert (((4 == channels) && (alpha)) ||
                (3 == channels));

        /*
         * Fun fact: we don't need to decompose the actual colors. Since
         * the inversion is just a simple XOR operation, we can just
         * invert all the bits minus the alpha value.
         */
        assert (1 <= sample_size);

        var rowstride = this.pixbuf_inverted_.get_rowstride ();
        var col_bytes = (((channels * sample_size) + 7) / 8);
        unowned var pixels = this.pixbuf_inverted_.get_pixels ();
        assert (pixels != null);
        size_t color_bits = channels;
        if (alpha) {
            --color_bits;
        }
        color_bits *= sample_size;
        for (size_t i = 0; i < this.pixbuf_inverted_.height; (++i)) {
            for (size_t y = 0; y < this.pixbuf_inverted_.width; (++y)) {
                /* Invert full bytes first. */
                for (size_t x = 0; x < (color_bits / 8); (++(x))) {
                    pixels[(i * rowstride) + (y * col_bytes) + (x)] ^= (~(0));
                }

                /*
                 * And now, invert the last actual color bits minus alpha
                 * and padding.
                 */
                uint8 rest = (uint8) (color_bits % 8);
                if (0 < rest) {
                    uint8 mask = (~(0));
                    mask <<= (8 - rest);
                    pixels[(i * rowstride) + (y * col_bytes) + (color_bits / 8)] ^= mask;
                }
            }
        }
    }

    private void notify_expanded () {
        if (!(this.expanded)) {
            /*
             * In non-expanded form, we always want to have the original
             * look.
             */
            if (this.inverted_) {
                this.swapping_ = true;
                this.pixbuf = this.pixbuf_orig_;
                this.inverted_ = false;
                this.swapping_ = false;
            }
        }
        else {
            /*
             * In expanded form, we want to restore the inverted form iff the
             * high contrast mode is enabled.
             */
            var agsettings = new AGSettings ();
            if ((!(this.inverted_)) && (agsettings.high_contrast)) {
                this.swapping_ = true;
                this.pixbuf = this.pixbuf_inverted_;
                this.inverted_ = true;
                this.swapping_ = false;
            }
        }
    }

    private bool inverted_ = false;
    private bool swapping_ = false;
    private Gdk.Pixbuf? pixbuf_orig_ = null;
    private Gdk.Pixbuf? pixbuf_inverted_ = null;
}
