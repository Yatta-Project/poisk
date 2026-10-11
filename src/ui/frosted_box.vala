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
            base.snapshot (snapshot);
        }
    }
}
