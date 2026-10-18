using Gee;
using Poisk.Core;

namespace Poisk.Providers {

    public class CalendarEvent {
        public string uid { get; set; default = ""; }
        public string summary { get; set; default = "Встреча"; }
        public DateTime? start_time { get; set; default = null; }
        public DateTime? end_time { get; set; default = null; }
        public string? meeting_url { get; set; default = null; }
        public string? conference_url { get; set; default = null; }
        public string? event_url { get; set; default = null; }
        public string? location { get; set; default = null; }
        public bool is_all_day { get; set; default = false; }
    }

    public class CalendarGlanceProvider : GLib.Object, GlanceProvider {
        public string id { get { return "calendar"; } }

        private GlanceItem? current_item = null;
        private uint poll_timer_id = 0;
        private bool is_scanning = false;

        public CalendarGlanceProvider () {
            // Initial scan in background after 1 second
            GLib.Timeout.add_seconds (1, () => {
                scan_events_async.begin ();
                return GLib.Source.REMOVE;
            });

            // Poll every 15 seconds to catch the exact 5-minute window
            poll_timer_id = GLib.Timeout.add_seconds (15, () => {
                scan_events_async.begin ();
                return GLib.Source.CONTINUE;
            });
        }

        ~CalendarGlanceProvider () {
            if (poll_timer_id > 0) {
                GLib.Source.remove (poll_timer_id);
                poll_timer_id = 0;
            }
        }

        public GlanceItem? get_current_glance () {
            return current_item;
        }

        public async void scan_events_async () {
            if (is_scanning) return;
            is_scanning = true;

            new Thread<void*> ("poisk-cal-scan", () => {
                var events = load_calendar_events ();
                Idle.add (() => {
                    this.evaluate_events (events);
                    this.is_scanning = false;
                    return GLib.Source.REMOVE;
                });
                return null;
            });
        }

        private ArrayList<CalendarEvent> load_calendar_events () {
            var result = new ArrayList<CalendarEvent> ();

            // 1. Scan local ICS files in ~/.local/share/evolution/calendar/
            string cal_base_dir = Path.build_filename (
                GLib.Environment.get_home_dir (),
                ".local", "share", "evolution", "calendar"
            );

            scan_ics_directory (cal_base_dir, result);

            // Also check real home dir if running in profile
            string real_cal_dir = "/home/mrlogiousbanana/.local/share/evolution/calendar";
            if (real_cal_dir != cal_base_dir) {
                scan_ics_directory (real_cal_dir, result);
            }

            // 2. Query EDS over D-Bus for any other active calendar backends
            query_eds_dbus (result);

            return result;
        }

        private void scan_ics_directory (string dir_path, ArrayList<CalendarEvent> result) {
            try {
                var dir = File.new_for_path (dir_path);
                if (!dir.query_exists ()) return;

                var enumerator = dir.enumerate_children (
                    FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
                    FileQueryInfoFlags.NONE
                );

                FileInfo? info = null;
                while ((info = enumerator.next_file ()) != null) {
                    string name = info.get_name ();
                    string child_path = Path.build_filename (dir_path, name);
                    if (info.get_file_type () == FileType.DIRECTORY) {
                        scan_ics_directory (child_path, result);
                    } else if (name.has_suffix (".ics")) {
                        parse_ics_file (child_path, result);
                    }
                }
            } catch (Error e) {
                // Directory enumeration error
            }
        }

        private void parse_ics_file (string ics_path, ArrayList<CalendarEvent> result) {
            try {
                var file = File.new_for_path (ics_path);
                if (!file.query_exists ()) return;

                uint8[] contents;
                if (!file.load_contents (null, out contents, null)) return;

                string data = (string) contents;
                parse_ics_content (data, result);
            } catch (Error e) {
                // File load error
            }
        }

        private void query_eds_dbus (ArrayList<CalendarEvent> result) {
            try {
                // Call GetObjectList on known active calendar subprocesses
                string[] argv = {
                    "busctl", "--user", "tree", "org.gnome.evolution.dataserver.Calendar8"
                };
                string stdout_buf = "";
                int exit_status;
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_buf, null, out exit_status);

                if (exit_status == 0) {
                    string[] lines = stdout_buf.split ("\n");
                    foreach (var line in lines) {
                        if (line.contains ("/Subprocess/") && !line.contains ("/CalendarView/")) {
                            string obj_path = line.strip ();
                            int idx = obj_path.index_of ("/org/gnome");
                            if (idx >= 0) {
                                obj_path = obj_path.substring (idx).strip ();
                                fetch_eds_events (obj_path, result);
                            }
                        }
                    }
                }
            } catch (Error e) {
                // D-Bus query error
            }
        }

        private void fetch_eds_events (string obj_path, ArrayList<CalendarEvent> result) {
            try {
                string[] argv = {
                    "busctl", "--user", "call",
                    "org.gnome.evolution.dataserver.Calendar8",
                    obj_path,
                    "org.gnome.evolution.dataserver.Calendar",
                    "GetObjectList",
                    "s", ""
                };
                string stdout_buf = "";
                int exit_status;
                Process.spawn_sync (null, argv, null, SpawnFlags.SEARCH_PATH, null, out stdout_buf, null, out exit_status);

                if (exit_status == 0 && stdout_buf.contains ("BEGIN:VCALENDAR")) {
                    parse_ics_content (stdout_buf, result);
                }
            } catch (Error e) {
                // EDS fetch error
            }
        }

        private void parse_ics_content (string data, ArrayList<CalendarEvent> result) {
            string[] lines = data.split ("\n");
            bool in_vevent = false;
            CalendarEvent? current = null;
            var desc_builder = new StringBuilder ();

            for (int i = 0; i < lines.length; i++) {
                string line = lines[i].replace ("\r", "");

                // Handle folded lines in RFC 5545 (lines starting with space or tab)
                while (i + 1 < lines.length && (lines[i + 1].has_prefix (" ") || lines[i + 1].has_prefix ("\t"))) {
                    line += lines[i + 1].substring (1).replace ("\r", "");
                    i++;
                }

                string line_trimmed = line.strip ();

                if (line_trimmed == "BEGIN:VEVENT") {
                    in_vevent = true;
                    current = new CalendarEvent ();
                    desc_builder = new StringBuilder ();
                } else if (line_trimmed == "END:VEVENT") {
                    if (current != null && current.uid.length > 0) {
                        string full_desc = desc_builder.str;

                        // Priority 1: Direct conference URL (from CONFERENCE or X-TELEMOST-CONFERENCE)
                        if (current.conference_url != null && current.conference_url.length > 0) {
                            current.meeting_url = current.conference_url;
                        }

                        // Priority 2: Detect meeting platform in LOCATION
                        if (current.meeting_url == null && current.location != null) {
                            current.meeting_url = MeetingLauncher.detect_meeting_url (current.location);
                        }

                        // Priority 3: Detect meeting platform in DESCRIPTION
                        if (current.meeting_url == null && full_desc.length > 0) {
                            current.meeting_url = MeetingLauncher.detect_meeting_url (full_desc);
                        }

                        // Priority 4: Detect meeting platform in event_url
                        if (current.meeting_url == null && current.event_url != null) {
                            current.meeting_url = MeetingLauncher.detect_meeting_url (current.event_url);
                        }

                        // Priority 5: Fallback to direct http in LOCATION
                        if (current.meeting_url == null && current.location != null && current.location.has_prefix ("http")) {
                            current.meeting_url = current.location;
                        }

                        // Priority 6: Fallback to event page URL (e.g. Яндекс Календарь)
                        if (current.meeting_url == null && current.event_url != null && current.event_url.has_prefix ("http")) {
                            current.meeting_url = current.event_url;
                        }

                        result.add (current);
                    }
                    in_vevent = false;
                    current = null;
                } else if (in_vevent && current != null) {
                    if (line_trimmed.has_prefix ("UID")) {
                        int colon = line_trimmed.index_of (":");
                        if (colon >= 0) current.uid = line_trimmed.substring (colon + 1).strip ();
                    } else if (line_trimmed.has_prefix ("SUMMARY")) {
                        int colon = line_trimmed.index_of (":");
                        if (colon >= 0) current.summary = unescape_ical_text (line_trimmed.substring (colon + 1).strip ());
                    } else if (line_trimmed.has_prefix ("DTSTART")) {
                        if (line_trimmed.contains ("VALUE=DATE") || (!line_trimmed.contains ("T") && line_trimmed.length <= 20)) {
                            current.is_all_day = true;
                        }
                        current.start_time = parse_ical_datetime (line_trimmed);
                    } else if (line_trimmed.has_prefix ("DTEND")) {
                        current.end_time = parse_ical_datetime (line_trimmed);
                    } else if (line_trimmed.has_prefix ("LOCATION")) {
                        int colon = line_trimmed.index_of (":");
                        if (colon >= 0) current.location = unescape_ical_text (line_trimmed.substring (colon + 1).strip ());
                    } else if (line_trimmed.has_prefix ("DESCRIPTION")) {
                        int colon = line_trimmed.index_of (":");
                        if (colon >= 0) {
                            desc_builder.append (unescape_ical_text (line_trimmed.substring (colon + 1)));
                            desc_builder.append ("\n");
                        }
                    } else if (line_trimmed.has_prefix ("CONFERENCE") || line_trimmed.has_prefix ("X-TELEMOST-CONFERENCE")) {
                        int colon = line_trimmed.index_of (":");
                        if (colon >= 0) {
                            string raw_conf = line_trimmed.substring (colon + 1).strip ();
                            if (raw_conf.has_prefix ("http")) {
                                current.conference_url = raw_conf;
                            }
                        }
                    } else if (line_trimmed.has_prefix ("URL")) {
                        int colon = line_trimmed.index_of (":");
                        if (colon >= 0) current.event_url = line_trimmed.substring (colon + 1).strip ();
                    }
                }
            }
        }

        private static string unescape_ical_text (string text) {
            return text.replace ("\\n", "\n")
                       .replace ("\\N", "\n")
                       .replace ("\\,", ",")
                       .replace ("\\;", ";")
                       .replace ("\\\\", "\\");
        }

        private static DateTime? parse_ical_datetime (string dt_str) {
            string s = dt_str.strip ();
            int colon_idx = s.index_of (":");
            if (colon_idx >= 0) {
                s = s.substring (colon_idx + 1).strip ();
            }

            if (s.length >= 15 && s.index_of ("T") == 8) {
                int year = int.parse (s.substring (0, 4));
                int month = int.parse (s.substring (4, 2));
                int day = int.parse (s.substring (6, 2));
                int hour = int.parse (s.substring (9, 2));
                int min = int.parse (s.substring (11, 2));
                int sec = int.parse (s.substring (13, 2));

                if (s.has_suffix ("Z")) {
                    var utc = new DateTime.utc (year, month, day, hour, min, sec);
                    return utc.to_local ();
                } else {
                    var tz = new TimeZone.local ();
                    return new DateTime (tz, year, month, day, hour, min, sec);
                }
            } else if (s.length == 8) {
                int year = int.parse (s.substring (0, 4));
                int month = int.parse (s.substring (4, 2));
                int day = int.parse (s.substring (6, 2));
                var tz = new TimeZone.local ();
                return new DateTime (tz, year, month, day, 0, 0, 0);
            }
            return null;
        }

        private void evaluate_events (ArrayList<CalendarEvent> events) {
            var now = new DateTime.now_local ();
            int64 now_unix = now.to_unix ();
            var glance_mgr = GlanceManager.get_default ();

            CalendarEvent? best_event = null;
            int64 best_score = int64.MIN;
            int64 best_diff = 0;

            foreach (var ev in events) {
                if (ev.is_all_day || ev.start_time == null) continue;

                var start = ev.start_time;
                var end = ev.end_time;
                if (end == null) {
                    end = start.add_minutes (45);
                }

                int64 start_unix = start.to_unix ();
                int64 end_unix = end.to_unix ();

                // Check if meeting has already ended
                if (now_unix >= end_unix) {
                    continue;
                }

                // Check if user already connected to this meeting via pill
                string meeting_key = "calendar:" + ev.uid;
                if (glance_mgr.is_connected (meeting_key)) {
                    continue;
                }

                int64 diff_sec = start_unix - now_unix;

                // USER REQUIREMENT:
                // Show if starting in <= 10 minutes (600 sec) OR currently ongoing (diff_sec <= 0)
                if (diff_sec <= 600) {
                    // Prioritize upcoming (score: 10000 - diff_sec) over ongoing (score: 5000 + diff_sec)
                    int64 score = (diff_sec >= 0) ? (10000 - diff_sec) : (5000 + diff_sec);
                    if (score > best_score) {
                        best_score = score;
                        best_event = ev;
                        best_diff = diff_sec;
                    }
                }
            }

            if (best_event != null) {
                create_or_update_glance (best_event, best_diff);
            } else {
                if (current_item != null) {
                    current_item = null;
                    glance_updated (null);
                }
            }
        }

        private void create_or_update_glance (CalendarEvent ev, int64 diff_sec) {
            var item = new GlanceItem ("calendar:" + ev.uid, 100);
            item.dot_color = "#22c55e"; // bright live green indicator
            item.shortcut_badge = "↵";
            item.auto_dismiss_on_activate = true;

            string target_url = ev.meeting_url != null ? ev.meeting_url : "";

            if (target_url.length > 0) {
                item.icon_name = MeetingLauncher.get_meeting_platform_icon (target_url);
            } else {
                item.icon_name = "io.elementary.calendar.event-new-symbolic";
            }

            // Soft modern green gradient for active call
            item.background = "linear-gradient(135deg, rgba(34, 197, 94, 0.22), rgba(16, 185, 129, 0.12))";
            item.border_color = "rgba(34, 197, 94, 0.40)";

            var start = ev.start_time;
            string time_str = start != null ? start.format ("%H:%M") : "";

            string escaped_summary = GLib.Markup.escape_text (ev.summary);
            if (diff_sec > 0) {
                int mins = (int) Math.ceil (diff_sec / 60.0);
                if (mins <= 1) {
                    item.title = "<b>%s</b> · через минуту".printf (escaped_summary);
                } else {
                    item.title = "<b>%s</b> · через %d мин".printf (escaped_summary, mins);
                }
            } else {
                item.title = "<b>%s</b> · идёт сейчас".printf (escaped_summary);
            }

            item.tooltip = "Встреча: %s\nНачало: %s\n%s\n\nНажмите ↵ для быстрого подключения".printf (
                ev.summary,
                time_str,
                target_url.length > 0 ? "Ссылка: " + target_url : ""
            );

            // Native action: launch in app if installed (Zoom, Telegram/AyuGram, Telemost, Teams) or browser
            item.native_action = () => {
                if (target_url.length > 0) {
                    MeetingLauncher.launch_meeting (target_url);
                } else {
                    try {
                        string[] argv = { "io.elementary.calendar" };
                        Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    } catch (Error e) {
                        warning ("Failed to open calendar app: %s", e.message);
                    }
                }
            };

            current_item = item;
            glance_updated (item);
        }
    }
}
