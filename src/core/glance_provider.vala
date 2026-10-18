namespace Poisk.Core {

    public interface GlanceProvider : GLib.Object {
        public abstract string id { get; }
        public abstract GlanceItem? get_current_glance ();
        public signal void glance_updated (GlanceItem? item);
    }
}
