namespace Vicinae.Core {

    public delegate void ActionCallback (SearchItem item);

    public class SearchItem : Object {
        public string id { get; set; default = ""; }
        public string title { get; set; default = ""; }
        public string subtitle { get; set; default = ""; }
        public string icon_name { get; set; default = "system-run"; }
        public string category { get; set; default = "General"; }
        public int score { get; set; default = 0; }
        public string preview_text { get; set; default = ""; }
        public string action_label { get; set; default = "Open"; }
        public string extra_info { get; set; default = ""; }
        
        public unowned ActionCallback? callback { get; set; default = null; }

        public SearchItem (string id, string title, string subtitle, string icon_name, string category) {
            this.id = id;
            this.title = title;
            this.subtitle = subtitle;
            this.icon_name = icon_name;
            this.category = category;
        }

        public void execute () {
            if (callback != null) {
                callback (this);
            }
        }
    }
}
