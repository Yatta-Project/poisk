namespace Poisk.Core {

    [DBus (name = "io.github.mrlogiousbanana.poisk.Glance")]
    public class GlanceDBusService : GLib.Object {
        private GlanceManager manager;

        public GlanceDBusService (GlanceManager manager) {
            this.manager = manager;
            manager.glance_activated.connect ((id) => {
                this.GlanceActivated (id);
            });
        }

        public void SetGlance (
            string id,
            int priority,
            string title,
            string icon,
            string background,
            string action
        ) throws GLib.Error {
            var item = new GlanceItem (id, priority);
            item.title = title;
            if (icon.length > 0) {
                if (icon.has_prefix ("/") || icon.has_prefix (".")) {
                    item.icon_path = icon;
                } else if (icon.char_count () <= 2 && !icon.has_suffix ("-symbolic")) {
                    item.icon_emoji = icon;
                } else {
                    item.icon_name = icon;
                }
            }
            if (background.length > 0) item.background = background;
            if (action.length > 0) {
                item.action_payload = action;
                if (action.has_prefix ("http://") || action.has_prefix ("https://")) {
                    item.action_type = "url";
                } else if (action.has_suffix (".desktop")) {
                    item.action_type = "app";
                } else {
                    item.action_type = "command";
                }
            }
            manager.set_glance (item);
        }

        public void SetGlanceFull (
            string id,
            int priority,
            string title,
            string markup,
            string icon_name,
            string icon_emoji,
            string dot_color,
            string shortcut_badge,
            string background,
            string border_color,
            string text_color,
            string action_type,
            string action_payload,
            int ttl_seconds
        ) throws GLib.Error {
            var item = new GlanceItem (id, priority);
            if (title.length > 0) item.title = title;
            if (markup.length > 0) item.markup = markup;
            if (icon_name.length > 0) item.icon_name = icon_name;
            if (icon_emoji.length > 0) item.icon_emoji = icon_emoji;
            if (dot_color.length > 0) item.dot_color = dot_color;
            if (shortcut_badge.length > 0) item.shortcut_badge = shortcut_badge;
            else if (shortcut_badge == "") item.shortcut_badge = null;
            if (background.length > 0) item.background = background;
            if (border_color.length > 0) item.border_color = border_color;
            if (text_color.length > 0) item.text_color = text_color;
            if (action_type.length > 0) item.action_type = action_type;
            if (action_payload.length > 0) item.action_payload = action_payload;
            if (ttl_seconds > 0) {
                item.expires_at = GLib.get_monotonic_time () + (int64) ttl_seconds * 1000000;
            }
            manager.set_glance (item);
        }

        public void SetGlanceJson (string json_str) throws GLib.Error {
            var item = GlanceItem.from_json (json_str);
            manager.set_glance (item);
        }

        public void ClearGlance (string id) throws GLib.Error {
            manager.clear_glance (id);
        }

        public void DismissGlance (string id) throws GLib.Error {
            manager.mark_connected (id);
        }

        public string GetActiveId () throws GLib.Error {
            var active = manager.get_active_glance ();
            return active != null ? active.id : "";
        }

        public signal void GlanceActivated (string id);
    }
}
