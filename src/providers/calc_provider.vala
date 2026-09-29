using Vicinae.Core;

namespace Vicinae.Providers {

    public class CalcProvider : Object, SearchProvider {
        public string id { get { return "calc"; } }
        public string display_name { get { return "Calculator"; } }
        public string category { get { return "Calculator"; } }
        public bool is_enabled { get; set; default = true; }

        public async List<SearchItem> search (string query_text, Cancellable? cancellable = null) {
            var items = new List<SearchItem> ();
            string q = query_text.strip ();

            if (!looks_like_math (q)) {
                return items;
            }

            double result = 0.0;
            if (eval_simple (q, out result)) {
                string formatted = (result % 1.0 == 0.0) ? "%.0f".printf (result) : "%.4f".printf (result).strip ();
                // Remove trailing zeros
                if (formatted.contains (".")) {
                    while (formatted.has_suffix ("0")) {
                        formatted = formatted.substring (0, formatted.length - 1);
                    }
                    if (formatted.has_suffix (".")) {
                        formatted = formatted.substring (0, formatted.length - 1);
                    }
                }

                var item = new SearchItem (
                    "calc:" + formatted,
                    formatted,
                    "= %s".printf (q),
                    "accessories-calculator",
                    "Calculator"
                );
                item.score = 1200; // Top priority if math expression
                item.action_label = "Copy Result";
                item.preview_text = "<b>Calculation Result</b>\n\n<tt>%s = %s</tt>\n\nPress Enter to copy result to clipboard.".printf (
                    Markup.escape_text (q),
                    Markup.escape_text (formatted)
                );

                item.provider = this;
                items.append (item);
            }

            return items;
        }

        public void activate (SearchItem item) {
            var display = Gdk.Display.get_default ();
            if (display != null) {
                var clipboard = display.get_clipboard ();
                clipboard.set_text (item.title);
            }
        }

        private bool looks_like_math (string s) {
            if (s.length < 2) return false;
            bool has_operator = false;
            bool has_digit = false;

            for (int i = 0; i < s.length; i++) {
                char c = s[i];
                if (c.isdigit ()) has_digit = true;
                if (c == '+' || c == '-' || c == '*' || c == '/' || c == '^' || c == '%') {
                    has_operator = true;
                }
            }

            return has_digit && has_operator;
        }

        // Recursive descent parser for math expressions
        private bool eval_simple (string expr, out double result) {
            result = 0.0;
            try {
                int pos = 0;
                string clean = expr.replace (" ", "");
                result = parse_expression (clean, ref pos);
                return (pos == clean.length && Math.isnan (result) == 0 && Math.isinf (result) == 0);
            } catch (Error e) {
                return false;
            }
        }

        private double parse_expression (string s, ref int pos) throws Error {
            double res = parse_term (s, ref pos);
            while (pos < s.length) {
                char op = s[pos];
                if (op != '+' && op != '-') break;
                pos++;
                double next_term = parse_term (s, ref pos);
                if (op == '+') res += next_term;
                else res -= next_term;
            }
            return res;
        }

        private double parse_term (string s, ref int pos) throws Error {
            double res = parse_factor (s, ref pos);
            while (pos < s.length) {
                char op = s[pos];
                if (op != '*' && op != '/' && op != '%') break;
                pos++;
                double next_factor = parse_factor (s, ref pos);
                if (op == '*') res *= next_factor;
                else if (op == '/') {
                    if (next_factor == 0.0) throw new IOError.FAILED ("Division by zero");
                    res /= next_factor;
                } else if (op == '%') {
                    res = res % next_factor;
                }
            }
            return res;
        }

        private double parse_factor (string s, ref int pos) throws Error {
            if (pos >= s.length) throw new IOError.FAILED ("Unexpected end");

            // Handle unary minus
            if (s[pos] == '-') {
                pos++;
                return -parse_factor (s, ref pos);
            }
            if (s[pos] == '+') {
                pos++;
                return parse_factor (s, ref pos);
            }

            // Parentheses
            if (s[pos] == '(') {
                pos++;
                double inner = parse_expression (s, ref pos);
                if (pos < s.length && s[pos] == ')') {
                    pos++;
                    return inner;
                }
                throw new IOError.FAILED ("Missing closing parenthesis");
            }

            // Numbers
            int start = pos;
            bool has_dot = false;
            while (pos < s.length && (s[pos].isdigit () || (s[pos] == '.' && !has_dot))) {
                if (s[pos] == '.') has_dot = true;
                pos++;
            }

            if (start == pos) throw new IOError.FAILED ("Expected number");
            string num_str = s.substring (start, pos - start);
            return double.parse (num_str);
        }
    }
}
