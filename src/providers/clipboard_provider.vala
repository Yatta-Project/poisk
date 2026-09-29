using Vicinae.Core;

namespace Vicinae.Providers {

    public class ClipboardProvider : Object, SearchProvider {
        public string id { get { return "clipboard"; } }
        public string display_name { get { return "Clipboard History"; } }
        public string category { get { return "Clipboard"; } }
        public bool is_enabled { get; set; default = true; }

        public async List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var items = new List<SearchItem> ();
            var db = Database.get_default ();

            bool explicit_clip = query_text.has_prefix ("clip ") || query_text.has_prefix ("cb ");
            string filter = explicit_clip ? query_text.substring (query_text.index_of (" ") + 1).strip () : query_text;

            // Only search clipboard when user types at least 2 chars or uses explicit prefix
            if (!explicit_clip && query_text.length < 2) {
                return items;
            }

            var clips = db.get_recent_clipboard (explicit_clip ? 30 : 5, filter.length > 0 ? filter : null);
            int idx = 0;

            foreach (var clip in clips) {
                if (cancellable != null && cancellable.is_cancelled ()) break;

                string single_line = clip.replace ("\n", " ").strip ();
                if (single_line.length > 60) {
                    single_line = single_line.substring (0, 57) + "...";
                }

                int score = 0;
                if (explicit_clip) {
                    score = 800 - idx * 10;
                } else {
                    int match = SearchEngine.fuzzy_score (filter, clip);
                    if (match > 0) {
                        score = match - 50; // slightly lower than direct app match
                    }
                }

                if (score > 0) {
                    var item = new SearchItem (
                        "clip:%d".printf (idx),
                        single_line,
                        "Clipboard History",
                        "edit-copy",
                        "Clipboard"
                    );
                    item.score = score;
                    item.action_label = "Copy to Clipboard";
                    item.preview_text = clip;

                    item.callback = () => {
                        this.activate (item);
                    };

                    items.append (item);
                }
                idx++;
            }

            return items;
        }

        public void activate (SearchItem item) {
            var display = Gdk.Display.get_default ();
            if (display != null) {
                var clipboard = display.get_clipboard ();
                clipboard.set_text (item.preview_text);
            }
        }
    }
}
