using Vicinae.Core;
using Vicinae.Bridges;

namespace Vicinae.Providers {

    public class WindowProvider : Object, SearchProvider {
        public string id { get { return "windows"; } }
        public string display_name { get { return "Open Windows"; } }
        public string category { get { return "Open Windows"; } }
        public bool is_enabled { get; set; default = true; }

        private DesktopBridge bridge;

        public WindowProvider (DesktopBridge bridge) {
            this.bridge = bridge;
        }

        public async List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var results = new List<SearchItem> ();
            if (!bridge.is_available) return results;

            var windows = yield bridge.get_open_windows ();
            foreach (var win in windows) {
                if (cancellable != null && cancellable.is_cancelled ()) break;

                int score = 0;
                if (query_text.length == 0) {
                    score = 90; // Visible when empty but below top apps
                } else if (query_text.has_prefix ("win ") || query_text.has_prefix ("w ")) {
                    string term = query_text.substring (query_text.index_of (" ") + 1);
                    score = SearchEngine.fuzzy_score (term, win.title) + 500;
                } else {
                    int title_score = SearchEngine.fuzzy_score (query_text, win.title);
                    int class_score = SearchEngine.fuzzy_score (query_text, win.subtitle);
                    score = int.max (title_score, class_score);
                    if (score > 0) score += 50; // Bonus for existing active windows
                }

                if (score > 0) {
                    win.score = score;
                    results.append (win);
                }
            }

            return results;
        }

        public void activate (SearchItem item) {
            item.execute ();
        }
    }
}
