using Vicinae.Core;

namespace Vicinae.Providers {

    public delegate void DmenuSelectCallback (string selected);

    public class DmenuProvider : GLib.Object, SearchProvider {
        public string id { get { return "dmenu"; } }
        public string display_name { get { return "Options"; } }
        public string category { get { return "Dmenu"; } }
        public bool is_enabled { get; set; default = true; }

        private GLib.List<string> entries;
        private DmenuSelectCallback on_select;

        public DmenuProvider (owned GLib.List<string> entries, owned DmenuSelectCallback callback) {
            this.entries = (owned) entries;
            this.on_select = (owned) callback;
        }

        public async GLib.List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var items = new GLib.List<SearchItem> ();

            foreach (unowned string text in entries) {
                if (cancellable != null && cancellable.is_cancelled ()) break;

                int score = 100;
                if (query_text.length > 0) {
                    score = SearchEngine.fuzzy_score (query_text, text);
                }

                if (score > 0) {
                    var item = new SearchItem (
                        "dmenu:" + text,
                        text,
                        "",
                        "view-list-symbolic",
                        "Selection"
                    );
                    item.score = score;
                    item.action_label = "Select";
                    item.preview_text = "<b>Selection</b>\n\n%s".printf (Markup.escape_text (text));
                    item.callback = () => {
                        on_select (text);
                    };

                    items.append (item);
                }
            }

            return items;
        }

        public void activate (SearchItem item) {
            item.execute ();
        }
    }
}
