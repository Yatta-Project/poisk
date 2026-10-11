using Gtk;
using Gsk;

namespace Poisk.UI {

    public class FadingBox : Box {
        public float fade_height { get; set; default = 32.0f; }

        private ScrolledWindow? target_scroll = null;
        private Adjustment? current_vadj = null;
        private ulong val_conn = 0;
        private ulong chg_conn = 0;
        private ulong adj_notify_conn = 0;

        public FadingBox (Orientation orientation = Orientation.VERTICAL, int spacing = 0) {
            Object (orientation: orientation, spacing: spacing);
            this.hexpand = true;
            this.vexpand = true;
        }

        public void attach_scrolled_window (ScrolledWindow scroll) {
            if (target_scroll != null && adj_notify_conn != 0) {
                target_scroll.disconnect (adj_notify_conn);
                adj_notify_conn = 0;
            }

            target_scroll = scroll;
            if (target_scroll != null) {
                adj_notify_conn = target_scroll.notify["vadjustment"].connect (() => {
                    bind_adjustment ();
                });
                bind_adjustment ();
            }
        }

        private void bind_adjustment () {
            if (current_vadj != null) {
                if (val_conn != 0) {
                    current_vadj.disconnect (val_conn);
                    val_conn = 0;
                }
                if (chg_conn != 0) {
                    current_vadj.disconnect (chg_conn);
                    chg_conn = 0;
                }
                current_vadj = null;
            }

            if (target_scroll != null) {
                current_vadj = target_scroll.vadjustment;
                if (current_vadj != null) {
                    val_conn = current_vadj.value_changed.connect (() => {
                        this.queue_draw ();
                    });
                    chg_conn = current_vadj.changed.connect (() => {
                        this.queue_draw ();
                    });
                }
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            int w = get_width ();
            int h = get_height ();
            if (w <= 0 || h <= 0) {
                base.snapshot (snapshot);
                return;
            }

            float top_alpha_scale = 0.0f;
            float bottom_alpha_scale = 0.0f;

            var vadj = current_vadj;
            if (vadj != null) {
                double ramp = (double) fade_height;
                if (ramp < 1.0) ramp = 1.0;

                // How much top is scrolled off
                if (vadj.value > 0.0) {
                    top_alpha_scale = (float) double.min (vadj.value / ramp, 1.0);
                }

                // How much bottom is overflowing
                double max_scroll = vadj.upper - vadj.page_size;
                if (max_scroll > 0.5) {
                    double dist_from_bottom = max_scroll - vadj.value;
                    if (dist_from_bottom > 0.0) {
                        bottom_alpha_scale = (float) double.min (dist_from_bottom / ramp, 1.0);
                    }
                }
            }

            // If neither edge needs fading, render directly without mask overhead
            if (top_alpha_scale <= 0.001f && bottom_alpha_scale <= 0.001f) {
                base.snapshot (snapshot);
                return;
            }

            float effective_fade = fade_height;
            if ((float) h < effective_fade * 2.5f) {
                effective_fade = (float) h / 2.5f;
            }

            var bounds = Graphene.Rect ();
            bounds.init (0, 0, (float) w, (float) h);

            var start_pt = Graphene.Point ();
            start_pt.init (0, 0);

            var end_pt = Graphene.Point ();
            end_pt.init (0, (float) h);

            float top_stop_offset = effective_fade / (float) h;
            float bottom_stop_offset = ((float) h - effective_fade) / (float) h;

            Gsk.ColorStop[] stops = new Gsk.ColorStop[4];
            stops[0].offset = 0.0f;
            stops[0].color = Gdk.RGBA () { red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f - top_alpha_scale };

            stops[1].offset = top_stop_offset;
            stops[1].color = Gdk.RGBA () { red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f };

            stops[2].offset = bottom_stop_offset;
            stops[2].color = Gdk.RGBA () { red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f };

            stops[3].offset = 1.0f;
            stops[3].color = Gdk.RGBA () { red = 0.0f, green = 0.0f, blue = 0.0f, alpha = 1.0f - bottom_alpha_scale };

            snapshot.push_mask (Gsk.MaskMode.ALPHA);
            snapshot.append_linear_gradient (bounds, start_pt, end_pt, stops);
            snapshot.pop ();

            base.snapshot (snapshot);

            snapshot.pop ();
        }
    }
}
