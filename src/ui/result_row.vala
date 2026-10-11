using Gtk;
using Poisk.Core;

namespace Poisk.UI {

    public class ResultRow : ListBoxRow {
        public SearchItem item { get; private set; }
        private static HashTable<string, Gdk.Paintable>? icon_cache = null;

        private Image icon_img;
        private Label title_lbl;
        private Label subtitle_lbl;
        private Label badge_lbl;

        public static Gdk.Paintable? get_cached_icon (string icon_name, int size = 28, int forced_scale = 0) {
            var display = Gdk.Display.get_default ();
            if (display == null) return null;

            int scale = forced_scale;
            if (scale <= 0) {
                scale = 1;
                var monitors = display.get_monitors ();
                if (monitors.get_n_items () > 0) {
                    var mon = monitors.get_item (0) as Gdk.Monitor;
                    if (mon != null) {
                        scale = mon.get_scale_factor ();
                    }
                }
            }
            if (scale < 1) scale = 1;

            if (icon_cache == null) {
                icon_cache = new HashTable<string, Gdk.Paintable> (str_hash, str_equal);
            }
            string key = "%s@%d@%d".printf (icon_name, size, scale);
            var cached = icon_cache.lookup (key);
            if (cached != null) {
                return cached;
            }

            var theme = Gtk.IconTheme.get_for_display (display);

            Gdk.Paintable? paintable = null;

            // 1. If icon_name is a direct file path or URI
            if (icon_name.has_prefix ("/") || icon_name.has_prefix ("file://")) {
                string path = icon_name.has_prefix ("file://") ? File.new_for_uri (icon_name).get_path () : icon_name;
                try {
                    var gicon = Icon.new_for_string (path);
                    if (gicon != null) {
                        paintable = theme.lookup_by_gicon (gicon, size, scale, Gtk.TextDirection.NONE, 0);
                    }
                } catch (Error e) {
                }

                if (paintable == null) {
                    try {
                        paintable = Gdk.Texture.from_filename (path);
                    } catch (Error e) {
                    }
                }
            } else {
                // 2. Themed icon name: try lookup_by_gicon first, then lookup_icon
                try {
                    var gicon = Icon.new_for_string (icon_name);
                    if (gicon != null) {
                        paintable = theme.lookup_by_gicon (gicon, size, scale, Gtk.TextDirection.NONE, 0);
                    }
                } catch (Error e) {
                }

                if (paintable == null) {
                    paintable = theme.lookup_icon (icon_name, null, size, scale, Gtk.TextDirection.NONE, 0);
                }

                // If theme lookup returned image-missing fallback, check pixmaps in all XDG_DATA_DIRS
                if (paintable is Gtk.IconPaintable) {
                    var f = ((Gtk.IconPaintable) paintable).get_file ();
                    if (f != null && f.get_path () != null && f.get_path ().contains ("image-missing")) {
                        unowned string[] data_dirs = GLib.Environment.get_system_data_dirs ();
                        foreach (unowned string data_dir in data_dirs) {
                            string pixmap_path = Path.build_filename (data_dir, "pixmaps", icon_name);
                            if (!pixmap_path.has_suffix (".png") && !pixmap_path.has_suffix (".svg")) {
                                if (FileUtils.test (pixmap_path + ".png", FileTest.EXISTS)) {
                                    pixmap_path += ".png";
                                } else if (FileUtils.test (pixmap_path + ".svg", FileTest.EXISTS)) {
                                    pixmap_path += ".svg";
                                }
                            }
                            if (FileUtils.test (pixmap_path, FileTest.EXISTS)) {
                                try {
                                    paintable = Gdk.Texture.from_filename (pixmap_path);
                                    break;
                                } catch (Error e) {
                                }
                            }
                        }
                    }
                }
            }

            if (paintable != null) {
                icon_cache.insert (key, paintable);
            }
            return paintable;
        }

        public ResultRow (SearchItem item) {
            this.item = item;
            this.add_css_class ("poisk-result-row");

            var main_box = new Box (Orientation.HORIZONTAL, 12);
            main_box.margin_start = 12;
            main_box.margin_end = 12;
            main_box.margin_top = 8;
            main_box.margin_bottom = 8;

            // Icon
            var paintable = get_cached_icon (item.icon_name, 28);
            if (paintable != null) {
                icon_img = new Image.from_paintable (paintable);
            } else if (item.icon_name.has_prefix ("/") && FileUtils.test (item.icon_name, FileTest.EXISTS)) {
                icon_img = new Image.from_file (item.icon_name);
            } else {
                icon_img = new Image.from_icon_name (item.icon_name);
            }
            icon_img.pixel_size = 28;
            icon_img.add_css_class ("poisk-app-icon");
            main_box.append (icon_img);

            // Text Box (Title + Subtitle)
            var text_box = new Box (Orientation.VERTICAL, 2);
            text_box.hexpand = true;

            title_lbl = new Label (item.title);
            title_lbl.halign = Align.START;
            title_lbl.ellipsize = Pango.EllipsizeMode.END;
            title_lbl.add_css_class ("poisk-row-title");
            text_box.append (title_lbl);

            subtitle_lbl = new Label (item.subtitle);
            subtitle_lbl.halign = Align.START;
            subtitle_lbl.ellipsize = Pango.EllipsizeMode.END;
            subtitle_lbl.add_css_class ("poisk-row-subtitle");
            text_box.append (subtitle_lbl);

            main_box.append (text_box);

            // Badge / Category column (reserved width for max category like "Командировочные" + padding)
            var badge_box = new Box (Orientation.HORIZONTAL, 0);
            badge_box.valign = Align.CENTER;
            badge_box.halign = Align.END;
            badge_box.margin_start = 16;
            badge_box.set_size_request (150, -1);

            badge_lbl = new Label (item.category);
            badge_lbl.halign = Align.END;
            badge_lbl.ellipsize = Pango.EllipsizeMode.END;
            badge_lbl.add_css_class ("poisk-row-badge");
            badge_box.append (badge_lbl);

            main_box.append (badge_box);

            this.set_child (main_box);
        }
    }
}
