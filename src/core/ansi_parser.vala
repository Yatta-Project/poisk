using GLib;

namespace Poisk.Core {

    public class AnsiParser {

        public static string strip_ansi (string input) {
            try {
                var regex = new Regex ("\x1b\\[[0-9;?]*[a-zA-Z]", RegexCompileFlags.OPTIMIZE);
                return regex.replace (input, -1, 0, "");
            } catch (Error e) {
                return input;
            }
        }

        public static string ansi_to_pango (string raw) {
            if (raw.length == 0) return "";

            var sb = new StringBuilder ();
            bool in_span = false;
            bool in_bold = false;
            bool in_italic = false;

            try {
                // Split input by ANSI escape sequences
                var token_regex = new Regex ("(\x1b\\[[0-9;]*m|\x1b\\[\\?[0-9]*[a-zA-Z]|\x1b\\[[0-9;]*[a-zA-Z])", RegexCompileFlags.OPTIMIZE);
                string[] parts = token_regex.split (raw);

                foreach (var part in parts) {
                    if (part.length == 0) continue;

                    if (part.has_prefix ("\x1b[")) {
                        if (part.has_suffix ("m")) {
                            string body = part.substring (2, part.length - 3);
                            string[] codes = body.split (";");

                            if (codes.length == 0 || body == "" || body == "0") {
                                if (in_span) { sb.append ("</span>"); in_span = false; }
                                if (in_bold) { sb.append ("</b>"); in_bold = false; }
                                if (in_italic) { sb.append ("</i>"); in_italic = false; }
                            } else {
                                int i = 0;
                                string? new_fg = null;
                                bool? new_bold = null;
                                bool? new_italic = null;

                                while (i < codes.length) {
                                    string c = codes[i].strip ();
                                    if (c == "0" || c == "") {
                                        if (in_span) { sb.append ("</span>"); in_span = false; }
                                        if (in_bold) { sb.append ("</b>"); in_bold = false; }
                                        if (in_italic) { sb.append ("</i>"); in_italic = false; }
                                    } else if (c == "1") {
                                        new_bold = true;
                                    } else if (c == "3") {
                                        new_italic = true;
                                    } else if (c == "22") {
                                        if (in_bold) { sb.append ("</b>"); in_bold = false; }
                                    } else if (c == "23") {
                                        if (in_italic) { sb.append ("</i>"); in_italic = false; }
                                    } else if (c == "30") { new_fg = "#1e293b"; }
                                    else if (c == "31") { new_fg = "#ef4444"; }
                                    else if (c == "32") { new_fg = "#22c55e"; }
                                    else if (c == "33") { new_fg = "#eab308"; }
                                    else if (c == "34") { new_fg = "#3b82f6"; }
                                    else if (c == "35") { new_fg = "#a855f7"; }
                                    else if (c == "36") { new_fg = "#06b6d4"; }
                                    else if (c == "37") { new_fg = "#f8fafc"; }
                                    else if (c == "39") {
                                        if (in_span) { sb.append ("</span>"); in_span = false; }
                                    } else if (c == "90") { new_fg = "#64748b"; }
                                    else if (c == "91") { new_fg = "#f87171"; }
                                    else if (c == "92") { new_fg = "#4ade80"; }
                                    else if (c == "93") { new_fg = "#fde047"; }
                                    else if (c == "94") { new_fg = "#60a5fa"; }
                                    else if (c == "95") { new_fg = "#c084fc"; }
                                    else if (c == "96") { new_fg = "#22d3ee"; }
                                    else if (c == "97") { new_fg = "#ffffff"; }
                                    else if (c == "38" && i + 2 < codes.length && codes[i + 1] == "5") {
                                        int color_idx = int.parse (codes[i + 2]);
                                        new_fg = get_256_color (color_idx);
                                        i += 2;
                                    } else if (c == "38" && i + 4 < codes.length && codes[i + 1] == "2") {
                                        int r = int.parse (codes[i + 2]).clamp (0, 255);
                                        int g = int.parse (codes[i + 3]).clamp (0, 255);
                                        int b = int.parse (codes[i + 4]).clamp (0, 255);
                                        new_fg = "#%02x%02x%02x".printf (r, g, b);
                                        i += 4;
                                    }
                                    i++;
                                }

                                if (new_bold != null && new_bold && !in_bold) {
                                    sb.append ("<b>");
                                    in_bold = true;
                                }
                                if (new_italic != null && new_italic && !in_italic) {
                                    sb.append ("<i>");
                                    in_italic = true;
                                }
                                if (new_fg != null) {
                                    if (in_span) { sb.append ("</span>"); }
                                    sb.append_printf ("<span foreground=\"%s\">", new_fg);
                                    in_span = true;
                                }
                            }
                        }
                        // Other escape codes (cursor position, mode, etc.) are ignored
                        continue;
                    }

                    // Regular text: escape XML entities
                    sb.append (GLib.Markup.escape_text (part));
                }

                if (in_span) sb.append ("</span>");
                if (in_bold) sb.append ("</b>");
                if (in_italic) sb.append ("</i>");

                string candidate = "<span font_family=\"monospace\">" + sb.str + "</span>";

                // Validate with Pango parser to ensure it never crashes
                try {
                    Pango.AttrList attr_list;
                    string text_out;
                    Pango.parse_markup (candidate, -1, 0, out attr_list, out text_out, null);
                    return candidate;
                } catch (Error err) {
                    // Fallback to safely escaped plain text
                    return "<span font_family=\"monospace\">" + GLib.Markup.escape_text (strip_ansi (raw)) + "</span>";
                }
            } catch (Error e) {
                return "<span font_family=\"monospace\">" + GLib.Markup.escape_text (strip_ansi (raw)) + "</span>";
            }
        }

        private static string get_256_color (int idx) {
            string[] base_palette = {
                "#000000", "#800000", "#008000", "#808000", "#000080", "#800080", "#008080", "#c0c0c0",
                "#808080", "#ff0000", "#00ff00", "#ffff00", "#0000ff", "#ff00ff", "#00ffff", "#ffffff"
            };

            if (idx >= 0 && idx < 16) {
                return base_palette[idx];
            } else if (idx >= 16 && idx < 232) {
                int n = idx - 16;
                int r = (n / 36) * 51;
                int g = ((n % 36) / 6) * 51;
                int b = (n % 6) * 51;
                return "#%02x%02x%02x".printf (r, g, b);
            } else if (idx >= 232 && idx <= 255) {
                int gray = (idx - 232) * 10 + 8;
                return "#%02x%02x%02x".printf (gray, gray, gray);
            }
            return "#ffffff";
        }
    }
}
