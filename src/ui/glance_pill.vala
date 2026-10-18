using Gtk;
using Poisk.Core;

namespace Poisk.UI {

    public class GlancePill : Button {
        private Box content_box;
        private Box dot_widget;
        private Label icon_label;
        private Image icon_image;
        private Label title_label;
        private Label badge_label;
        private ProgressBar? progress_bar = null;

        private Gtk.Widget? custom_child = null;
        private Gtk.CssProvider css_provider;
        private Gtk.CssProvider dot_css_provider;

        public delegate void ActionCallback ();
        private ActionCallback? action_cb = null;

        public signal void activated ();

        public bool has_action {
            get { return action_cb != null; }
        }

        public GlancePill () {
            Object ();

            this.add_css_class ("poisk-glance-pill");
            this.valign = Align.CENTER;
            this.halign = Align.END;
            this.cursor = new Gdk.Cursor.from_name ("pointer", null);

            css_provider = new Gtk.CssProvider ();
            dot_css_provider = new Gtk.CssProvider ();
            var display = Gdk.Display.get_default ();
            if (display != null) {
                Gtk.StyleContext.add_provider_for_display (
                    display,
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
                Gtk.StyleContext.add_provider_for_display (
                    display,
                    dot_css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            }

            content_box = new Box (Orientation.HORIZONTAL, 6);
            content_box.valign = Align.CENTER;
            content_box.halign = Align.CENTER;

            // Indicator dot (status / active call / record)
            dot_widget = new Box (Orientation.HORIZONTAL, 0);
            dot_widget.add_css_class ("glance-dot");
            dot_widget.valign = Align.CENTER;
            dot_widget.visible = false;

            // Emoji icon
            icon_label = new Label ("");
            icon_label.add_css_class ("glance-icon-emoji");
            icon_label.visible = false;

            // Symbolic or file icon
            icon_image = new Image ();
            icon_image.pixel_size = 14;
            icon_image.add_css_class ("glance-icon-image");
            icon_image.visible = false;

            // Main text / markup label
            title_label = new Label ("");
            title_label.add_css_class ("glance-title");
            title_label.use_markup = true;
            title_label.ellipsize = Pango.EllipsizeMode.END;
            title_label.max_width_chars = 40;

            // Key badge (default ↵)
            badge_label = new Label ("↵");
            badge_label.add_css_class ("glance-key-badge");

            content_box.append (dot_widget);
            content_box.append (icon_label);
            content_box.append (icon_image);
            content_box.append (title_label);
            content_box.append (badge_label);

            this.set_child (content_box);

            this.clicked.connect (() => {
                execute_action ();
            });
        }

        public void set_custom_child (Gtk.Widget? widget) {
            custom_child = widget;
            if (widget != null) {
                this.set_child (widget);
            } else {
                this.set_child (content_box);
            }
        }

        public void apply_item (GlanceItem item, owned ActionCallback? cb = null) {
            action_cb = (owned) cb;

            // Tooltip
            if (item.tooltip != null && item.tooltip.length > 0) {
                this.tooltip_markup = item.tooltip;
            } else {
                this.tooltip_markup = null;
                this.tooltip_text = null;
            }

            // Custom in-process widget takes precedence over standard layout
            if (item.custom_widget != null) {
                set_custom_child (item.custom_widget);
                apply_styling (item);
                return;
            } else {
                set_custom_child (null);
            }

            // Status dot
            if (item.dot_color != null && item.dot_color.length > 0) {
                dot_widget.visible = true;
                apply_dot_color (item.dot_color);
            } else {
                dot_widget.visible = false;
            }

            // Text / Markup
            if (item.markup != null && item.markup.length > 0) {
                title_label.set_markup (item.markup);
            } else if (item.title != null) {
                title_label.label = item.title;
            } else {
                title_label.label = "";
            }

            // Icon
            if (item.icon_path != null && item.icon_path.length > 0) {
                icon_image.set_from_file (item.icon_path);
                icon_image.visible = true;
                icon_label.visible = false;
            } else if (item.icon_emoji != null && item.icon_emoji.length > 0) {
                icon_label.label = item.icon_emoji;
                icon_label.visible = true;
                icon_image.visible = false;
            } else if (item.icon_name != null && item.icon_name.length > 0) {
                icon_image.set_from_icon_name (item.icon_name);
                icon_image.visible = true;
                icon_label.visible = false;
            } else {
                icon_label.visible = false;
                icon_image.visible = false;
            }

            // Shortcut badge
            if (item.shortcut_badge != null && item.shortcut_badge.length > 0) {
                badge_label.label = item.shortcut_badge;
                badge_label.visible = true;
            } else {
                badge_label.visible = false;
            }

            // Progress bar
            if (item.progress >= 0.0) {
                if (progress_bar == null) {
                    progress_bar = new ProgressBar ();
                    progress_bar.add_css_class ("glance-progress-bar");
                    content_box.append (progress_bar);
                }
                progress_bar.set_fraction (item.progress.clamp (0.0, 1.0));
                progress_bar.visible = true;
            } else if (progress_bar != null) {
                progress_bar.visible = false;
            }

            // Styling (background, borders, colors)
            apply_styling (item);
        }

        private void apply_dot_color (string color) {
            string css_color = color;
            if (color == "green") css_color = "#22c55e";
            else if (color == "red") css_color = "#ef4444";
            else if (color == "orange" || color == "amber") css_color = "#f59e0b";
            else if (color == "blue") css_color = "#3b82f6";
            else if (color == "purple") css_color = "#a855f7";

            string dot_css = """
                .glance-dot.dot-active {
                    background-color: %s;
                    box-shadow: 0 0 6px alpha(%s, 0.60);
                }
            """.printf (css_color, css_color);

            dot_widget.add_css_class ("dot-active");
            dot_css_provider.load_from_string (dot_css);
        }

        private void apply_styling (GlanceItem item) {
            bool has_custom = (item.background != null && item.background.length > 0)
                || (item.border_color != null && item.border_color.length > 0)
                || (item.text_color != null && item.text_color.length > 0)
                || (item.custom_css != null && item.custom_css.length > 0);

            if (!has_custom) {
                this.remove_css_class ("poisk-glance-custom");
                css_provider.load_from_string ("");
                return;
            }

            this.add_css_class ("poisk-glance-custom");

            var sb = new StringBuilder ();
            sb.append ("button.poisk-glance-pill.poisk-glance-custom {\n");

            if (item.background != null && item.background.length > 0) {
                sb.append_printf ("    background: %s !important;\n", item.background);
                sb.append ("    background-image: none !important;\n");
            }
            if (item.border_color != null && item.border_color.length > 0) {
                sb.append_printf ("    border-color: %s !important;\n", item.border_color);
            }
            if (item.text_color != null && item.text_color.length > 0) {
                sb.append_printf ("    color: %s !important;\n", item.text_color);
            }
            if (item.custom_css != null && item.custom_css.length > 0) {
                sb.append_printf ("    %s\n", item.custom_css);
            }
            sb.append ("}\n");

            css_provider.load_from_string (sb.str);
        }

        public void set_glance (string? icon_name, string? emoji, string text, owned ActionCallback? cb = null) {
            var item = new GlanceItem ("legacy", 0);
            item.title = text;
            item.icon_name = icon_name;
            item.icon_emoji = emoji;
            apply_item (item, (owned) cb);
        }

        public void execute_action () {
            if (action_cb != null) {
                action_cb ();
                activated ();
            }
        }
    }
}
