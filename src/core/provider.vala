namespace Vicinae.Core {

    public interface SearchProvider : Object {
        public abstract string id { get; }
        public abstract string display_name { get; }
        public abstract string category { get; }
        public abstract bool is_enabled { get; set; default = true; }

        public abstract async List<SearchItem> search (string query_text, Cancellable? cancellable = null);
        public abstract void activate (SearchItem item);
    }
}
