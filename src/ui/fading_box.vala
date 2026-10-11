using Gtk;
using Gsk;

namespace Poisk.UI {

    public class FadingBox : Box {
        public float fade_height { get; set; default = 32.0f; }

        private ScrolledWindow? target_scroll = null;
        private Adjustment? current_vadj = null;
        private EventControllerScroll? scroll_controller = null;

        private ulong val_conn = 0;
        private ulong chg_conn = 0;
        private ulong adj_notify_conn = 0;

        private uint tick_id = 0;
        private double target_y = 0.0;
        private double last_animated_val = 0.0;

        public FadingBox (Orientation orientation = Orientation.VERTICAL, int spacing = 0) {
            Object (orientation: orientation, spacing: spacing);
            this.hexpand = true;
            this.vexpand = true;
        }

        public void attach_scrolled_window (ScrolledWindow scroll) {
            if (target_scroll != null) {
                if (adj_notify_conn != 0) {
                    target_scroll.disconnect (adj_notify_conn);
                    adj_notify_conn = 0;
                }
                if (scroll_controller != null) {
                    target_scroll.remove_controller (scroll_controller);
                    scroll_controller = null;
                }
            }

            target_scroll = scroll;
            if (target_scroll != null) {
                adj_notify_conn = target_scroll.notify["vadjustment"].connect (() => {
                    bind_adjustment ();
                });
                bind_adjustment ();
                setup_smooth_scroll_controller ();
            }
        }

        private void setup_smooth_scroll_controller () {
            if (target_scroll == null) return;

            scroll_controller = new EventControllerScroll (
                EventControllerScrollFlags.VERTICAL | 
                EventControllerScrollFlags.DISCRETE | 
                EventControllerScrollFlags.KINETIC |
                EventControllerScrollFlags.BOTH_AXES
            );
            scroll_controller.propagation_phase = PropagationPhase.CAPTURE;

            scroll_controller.scroll.connect ((dx, dy) => {
                if (current_vadj == null || dy == 0.0) return false;

                double max_scroll = double.max (current_vadj.upper - current_vadj.page_size, 0.0);
                if (max_scroll <= 0.0) return false;

                // Sync target_y if animation was idle
                if (tick_id == 0) {
                    target_y = current_vadj.get_value ();
                }

                double step_px = 0.0;
                if (scroll_controller.get_unit () == Gdk.ScrollUnit.WHEEL) {
                    step_px = dy * 68.0;
                } else {
                    step_px = dy * 1.5;
                }

                target_y = (target_y + step_px).clamp (0.0, max_scroll);
                start_animation ();
                return true;
            });

            target_scroll.add_controller (scroll_controller);
        }

        private void bind_adjustment () {
            stop_animation ();

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
                    target_y = current_vadj.get_value ();
                    last_animated_val = target_y;

                    val_conn = current_vadj.value_changed.connect (() => {
                        // If external code adjusted value (not our animation tick), sync target_y
                        if (tick_id == 0 || Math.fabs (current_vadj.get_value () - last_animated_val) > 1.5) {
                            target_y = current_vadj.get_value ();
                        }
                        this.queue_draw ();
                    });

                    chg_conn = current_vadj.changed.connect (() => {
                        this.queue_draw ();
                    });
                }
            }
        }

        public void scroll_to_smooth (double dest_y) {
            if (current_vadj == null) return;
            double max_scroll = double.max (current_vadj.upper - current_vadj.page_size, 0.0);
            target_y = dest_y.clamp (0.0, max_scroll);
            start_animation ();
        }

        public void scroll_to_child (Widget child) {
            if (target_scroll == null || current_vadj == null) return;

            var p_in = Graphene.Point ();
            p_in.init (0.0f, 0.0f);
            Graphene.Point p_out;
            if (!child.compute_point (target_scroll, p_in, out p_out)) {
                return;
            }

            double child_top = p_out.y;
            double child_h = (double) child.get_height ();
            double page_size = current_vadj.get_page_size ();

            double margin = 28.0;
            if (child_top < margin) {
                double dest = current_vadj.get_value () + child_top - margin;
                scroll_to_smooth (dest);
            } else if (child_top + child_h + margin > page_size) {
                double dest = current_vadj.get_value () + child_top + child_h + margin - page_size;
                scroll_to_smooth (dest);
            }
        }

        public void reset_scroll () {
            stop_animation ();
            if (current_vadj != null) {
                target_y = 0.0;
                last_animated_val = 0.0;
                current_vadj.set_value (0.0);
            }
        }

        private void start_animation () {
            if (tick_id != 0) return;
            tick_id = this.add_tick_callback (on_tick);
        }

        private void stop_animation () {
            if (tick_id != 0) {
                this.remove_tick_callback (tick_id);
                tick_id = 0;
            }
        }

        private bool on_tick (Widget widget, Gdk.FrameClock frame_clock) {
            if (current_vadj == null) {
                tick_id = 0;
                return Source.REMOVE;
            }

            double current = current_vadj.get_value ();
            double diff = target_y - current;

            if (Math.fabs (diff) < 0.6) {
                current_vadj.set_value (target_y);
                last_animated_val = target_y;
                tick_id = 0;
                return Source.REMOVE;
            }

            double step = diff * 0.22;
            if (Math.fabs (step) < 0.5) {
                step = (diff > 0) ? 0.5 : -0.5;
            }

            last_animated_val = current + step;
            current_vadj.set_value (last_animated_val);
            return Source.CONTINUE;
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
