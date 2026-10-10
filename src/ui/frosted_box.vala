using Gtk;

namespace Poisk.UI {

    public class FrostedBox : Box {
        public bool frosted { get; set; default = false; }
        public double blur_radius { get; set; default = 20.0; }
        public float corner_radius { get; set; default = 16.0f; }
        public string? custom_tint_color { get; set; default = null; }

        public FrostedBox (Orientation orientation, int spacing) {
            Object (orientation: orientation, spacing: spacing);
        }

        public override void snapshot (Gtk.Snapshot snapshot) {
            if (!frosted) {
                base.snapshot (snapshot);
                return;
            }

            float w = (float) get_width ();
            float h = (float) get_height ();
            if (w <= 0 || h <= 0) {
                base.snapshot (snapshot);
                return;
            }

            var rect = Graphene.Rect ();
            rect.init (0.0f, 0.0f, w, h);

            var rounded = Gsk.RoundedRect ();
            var sz = Graphene.Size ();
            sz.init (corner_radius, corner_radius);
            rounded.init (rect, sz, sz, sz, sz);

            // GNOME 51 / Wayland ext-background-effect-v1 protocol marker tree:
            // 1. Push rounded clip so compositor and GTK restrict blur to rounded geometry
            snapshot.push_rounded_clip (rounded);

            // 2. Marker sequence: push_copy -> push_blur -> append_paste
            snapshot.push_copy ();
            snapshot.push_blur (blur_radius);
            snapshot.append_paste (rect, 0);

            snapshot.pop (); // blur
            snapshot.pop (); // copy

            // 3. Render background and children widgets according to CSS dock styling
            base.snapshot (snapshot);

            snapshot.pop (); // rounded_clip
        }
    }
}
