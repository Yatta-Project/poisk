namespace Poisk.Core {

    public class SearchEngine : Object {
        private List<SearchProvider> providers = new List<SearchProvider> ();

        public void register_provider (SearchProvider provider) {
            providers.append (provider);
        }

        public async List<SearchItem> query (string raw_query, Cancellable? cancellable = null) {
            var results = new List<SearchItem> ();
            string clean_query = raw_query.strip ();

            foreach (unowned SearchProvider provider in providers) {
                if (!provider.is_enabled) continue;
                if (cancellable != null && cancellable.is_cancelled ()) break;

                try {
                    var items = yield provider.search (clean_query, cancellable);
                    foreach (var item in items) {
                        results.append (item);
                    }
                } catch (Error e) {
                    warning ("Error from provider %s: %s", provider.display_name, e.message);
                }
            }

            // Sort by score descending
            results.sort ((a, b) => {
                if (b.score != a.score) {
                    return b.score - a.score;
                }
                return a.title.collate (b.title);
            });

            return results;
        }

        public List<SearchItem> get_all_applications () {
            foreach (unowned SearchProvider provider in providers) {
                if (provider is Poisk.Providers.AppProvider) {
                    return ((Poisk.Providers.AppProvider) provider).get_all_applications ();
                }
            }
            return new List<SearchItem> ();
        }

        public List<AppInfo> get_all_installed_app_infos () {
            foreach (unowned SearchProvider provider in providers) {
                if (provider is Poisk.Providers.AppProvider) {
                    return ((Poisk.Providers.AppProvider) provider).get_all_installed_app_infos ();
                }
            }
            return new List<AppInfo> ();
        }

        public static int fuzzy_score (string pattern, string text) {
            if (pattern.length == 0) return 100;
            if (text.length == 0) return 0;

            string p = pattern.down ();
            string t = text.down ();

            // Exact prefix bonus
            if (t.has_prefix (p)) {
                return 1000 + (100 - (t.length - p.length));
            }

            // Substring bonus
            int index = t.index_of (p);
            if (index >= 0) {
                int bonus = 500 - (index * 10);
                return int.max (100, bonus);
            }

            // Subsequence fuzzy search
            int p_idx = 0;
            int score = 0;
            int last_match = -1;

            for (int i = 0; i < t.length && p_idx < p.length; i++) {
                if (t[i] == p[p_idx]) {
                    score += 10;
                    if (last_match == i - 1) {
                        score += 20; // Consecutive match bonus
                    }
                    if (i == 0 || t[i - 1] == ' ' || t[i - 1] == '-' || t[i - 1] == '_') {
                        score += 30; // Word start bonus
                    }
                    last_match = i;
                    p_idx++;
                }
            }

            if (p_idx == p.length) {
                return score;
            }

            return 0; // Not matched
        }
    }
}
