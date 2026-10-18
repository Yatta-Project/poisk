using GLib;

namespace Poisk.Core {

    public class MeetingLauncher {

        public static string? detect_meeting_url (string text) {
            if (text.length == 0) return null;

            try {
                // Regex for supported video meeting platforms
                var regex = new Regex (
                    "(https?:\\/\\/(?:meet\\.google\\.com\\/[a-z]{3}-[a-z]{4}-[a-z]{3}" +
                    "|[a-zA-Z0-9\\.\\-]*zoom\\.us\\/[a-z]\\/[0-9]+(?:\\?[^\\s\"'>]*)?" +
                    "|[a-zA-Z0-9\\.\\-]*telemost(?:\\.360)?\\.yandex\\.ru\\/j\\/[0-9]+" +
                    "|teams\\.microsoft\\.com\\/l\\/meetup-join\\/[^\\s\"'>]+" +
                    "|[a-zA-Z0-9\\.\\-]*(?:mts-link\\.ru|webinar\\.ru)\\/[^\\s\"'>]+" +
                    "|meet\\.jit\\.si\\/[^\\s\"'>]+" +
                    "|jazz\\.sber\\.ru\\/[^\\s\"'>]+" +
                    "|calls\\.vk\\.com\\/[^\\s\"'>]+" +
                    "|t\\.me\\/(?:call|[a-zA-Z0-9_\\+]+)))",
                    RegexCompileFlags.CASELESS
                );

                MatchInfo info;
                if (regex.match (text, 0, out info)) {
                    return info.fetch (1);
                }
            } catch (RegexError e) {
                warning ("Regex error in detect_meeting_url: %s", e.message);
            }

            return null;
        }

        public static string get_meeting_platform_icon (string url) {
            string lower = url.down ();
            if (lower.contains ("telemost")) {
                return "yandex-telemost";
            }
            if (lower.contains ("t.me")) {
                return "com.ayugram.desktop-symbolic";
            }
            if (lower.contains ("zoom.us")) {
                return "us.zoom.Zoom";
            }
            if (lower.contains ("teams.microsoft.com")) {
                return "com.microsoft.Teams";
            }
            if (lower.contains ("calls.vk.com")) {
                return "vk-calls";
            }
            if (lower.contains ("jazz.sber.ru")) {
                return "camera-web-symbolic";
            }
            if (lower.contains ("meet.google.com") || lower.contains ("mts-link.ru") || lower.contains ("webinar.ru")) {
                return "camera-web-symbolic";
            }
            return "io.elementary.calendar.event-new-symbolic";
        }

        public static void launch_meeting (string raw_url) {
            string url = raw_url.strip ();
            if (url.length == 0) return;

            // 1. Zoom
            if (url.contains ("zoom.us/j/") || url.contains ("zoom.us/w/")) {
                if (try_launch_zoom (url)) return;
            }

            // 2. Telegram (e.g. t.me call or voice chat)
            if (url.contains ("t.me/")) {
                if (try_launch_telegram (url)) return;
            }

            // 3. Yandex Telemost
            if (url.contains ("telemost") && url.contains ("/j/")) {
                if (try_launch_telemost (url)) return;
            }

            // 4. Microsoft Teams
            if (url.contains ("teams.microsoft.com/l/meetup-join/")) {
                if (try_launch_teams (url)) return;
            }

            // 5. VK Calls
            if (url.contains ("calls.vk.com/")) {
                if (try_launch_vk_calls (url)) return;
            }

            // 6. Sber Jazz
            if (url.contains ("jazz.sber.ru/")) {
                if (try_launch_sber_jazz (url)) return;
            }

            // Default fallback: open URL via system default handler (default browser or dedicated PWA)
            try {
                AppInfo.launch_default_for_uri (url, null);
            } catch (Error e) {
                try {
                    string[] argv = { "xdg-open", url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e2) {
                    warning ("Failed to open meeting URL %s: %s", url, e2.message);
                }
            }
        }

        private static bool try_launch_zoom (string url) {
            try {
                // Extract conference number and pwd
                var regex = new Regex ("zoom\\.us\\/[a-z]\\/([0-9]+)(?:\\?[^\\s\"']*pwd=([a-zA-Z0-9_\\-]+))?", RegexCompileFlags.CASELESS);
                MatchInfo match;
                if (regex.match (url, 0, out match)) {
                    string confno = match.fetch (1);
                    string? pwd = match.fetch (2);

                    string zoommtg = "zoommtg://zoom.us/join?action=join&confno=" + confno;
                    if (pwd != null && pwd.length > 0) {
                        zoommtg += "&pwd=" + pwd;
                    }

                    // Check if zoommtg URI handler is registered
                    var app = AppInfo.get_default_for_uri_scheme ("zoommtg");
                    if (app != null) {
                        AppInfo.launch_default_for_uri (zoommtg, null);
                        return true;
                    }

                    // Check if zoom binary or flatpak exists
                    if (Environment.find_program_in_path ("zoom") != null) {
                        string[] argv = { "zoom", "--url=" + zoommtg };
                        Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                        return true;
                    }

                    if (has_flatpak_app ("us.zoom.Zoom")) {
                        string[] argv = { "flatpak", "run", "us.zoom.Zoom", "--url=" + zoommtg };
                        Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                        return true;
                    }
                }
            } catch (Error e) {
                warning ("Failed to parse/launch Zoom URL: %s", e.message);
            }
            return false;
        }

        private static bool try_launch_telegram (string url) {
            try {
                string? tg_url = null;
                if (url.contains ("t.me/+")) {
                    string invite = url.substring (url.index_of ("t.me/+") + 6);
                    tg_url = "tg://join?invite=" + invite;
                } else if (url.contains ("t.me/joinchat/")) {
                    string invite = url.substring (url.index_of ("t.me/joinchat/") + 14);
                    tg_url = "tg://join?invite=" + invite;
                } else if (url.contains ("t.me/")) {
                    string path = url.substring (url.index_of ("t.me/") + 5);
                    if (path.length > 0) {
                        tg_url = "tg://resolve?domain=" + path;
                    }
                }

                // If registered handler for tg:// exists, launch via AppInfo
                if (tg_url != null && AppInfo.get_default_for_uri_scheme ("tg") != null) {
                    AppInfo.launch_default_for_uri (tg_url, null);
                    return true;
                }

                // Check custom AyuGram path or in PATH
                string? ayugram = Environment.find_program_in_path ("ayugram");
                if (ayugram == null && FileUtils.test ("/subhome/bin/ayugram", FileTest.IS_EXECUTABLE)) {
                    ayugram = "/subhome/bin/ayugram";
                }
                if (ayugram != null) {
                    string[] argv = { ayugram, "--", tg_url != null ? tg_url : url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }

                string? tg_desktop = Environment.find_program_in_path ("telegram-desktop");
                if (tg_desktop != null) {
                    string[] argv = { tg_desktop, "--", tg_url != null ? tg_url : url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }

                if (has_flatpak_app ("org.telegram.desktop")) {
                    string[] argv = { "flatpak", "run", "org.telegram.desktop", "--", tg_url != null ? tg_url : url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }
            } catch (Error e) {
                warning ("Failed to launch Telegram URL: %s", e.message);
            }
            return false;
        }

        private static bool try_launch_telemost (string url) {
            try {
                var regex = new Regex ("telemost(?:\\.360)?\\.yandex\\.ru\\/j\\/([0-9]+)", RegexCompileFlags.CASELESS);
                MatchInfo match;
                if (regex.match (url, 0, out match)) {
                    string meet_id = match.fetch (1);
                    string custom_uri = "telemost://j/" + meet_id;

                    if (AppInfo.get_default_for_uri_scheme ("telemost") != null) {
                        try {
                            AppInfo.launch_default_for_uri (custom_uri, null);
                            return true;
                        } catch (Error e) {
                        }
                    }

                    if (Environment.find_program_in_path ("yandex-telemost") != null) {
                        string[] argv = { "yandex-telemost", custom_uri };
                        Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                        return true;
                    }

                    // Fallback to opening original URL in browser
                    try {
                        AppInfo.launch_default_for_uri (url, null);
                        return true;
                    } catch (Error e) {
                    }
                }
            } catch (Error e) {
                warning ("Failed to launch Telemost URL: %s", e.message);
            }
            return false;
        }

        private static bool try_launch_teams (string url) {
            try {
                if (AppInfo.get_default_for_uri_scheme ("msteams") != null) {
                    string msteams_uri = url.replace ("https://teams.microsoft.com", "msteams:");
                    AppInfo.launch_default_for_uri (msteams_uri, null);
                    return true;
                }

                if (Environment.find_program_in_path ("teams") != null) {
                    string[] argv = { "teams", url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }

                if (has_flatpak_app ("com.microsoft.Teams")) {
                    string[] argv = { "flatpak", "run", "com.microsoft.Teams", url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }
            } catch (Error e) {
                warning ("Failed to launch Teams URL: %s", e.message);
            }
            return false;
        }

        private static bool try_launch_vk_calls (string url) {
            try {
                if (AppInfo.get_default_for_uri_scheme ("vkcalls") != null) {
                    string vk_uri = url.replace ("https://calls.vk.com/", "vkcalls://join/");
                    AppInfo.launch_default_for_uri (vk_uri, null);
                    return true;
                }

                if (Environment.find_program_in_path ("vk-calls") != null) {
                    string[] argv = { "vk-calls", url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }
            } catch (Error e) {
                warning ("Failed to launch VK Calls URL: %s", e.message);
            }
            return false;
        }

        private static bool try_launch_sber_jazz (string url) {
            try {
                if (Environment.find_program_in_path ("jazz") != null) {
                    string[] argv = { "jazz", url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }
                if (Environment.find_program_in_path ("sberjazz") != null) {
                    string[] argv = { "sberjazz", url };
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    return true;
                }
            } catch (Error e) {
                warning ("Failed to launch Sber Jazz URL: %s", e.message);
            }
            return false;
        }

        private static bool has_flatpak_app (string app_id) {
            try {
                string[] argv = { "flatpak", "info", app_id };
                int exit_status;
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, null, null, out exit_status);
                return exit_status == 0;
            } catch (Error e) {
                return false;
            }
        }
    }
}
