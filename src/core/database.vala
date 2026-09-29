using Sqlite;

namespace Vicinae.Core {

    public class Database : Object {
        private Sqlite.Database db;
        private static Database? instance = null;

        public static Database get_default () {
            if (instance == null) {
                instance = new Database ();
            }
            return instance;
        }

        private Database () {
            string data_dir = Path.build_filename (Environment.get_user_data_dir (), "vicinae");
            DirUtils.create_with_parents (data_dir, 0755);
            string db_path = Path.build_filename (data_dir, "vicinae.db");

            int rc = Sqlite.Database.open (db_path, out db);
            if (rc != Sqlite.OK) {
                warning ("Cannot open database %s: %s", db_path, db.errmsg ());
                return;
            }

            init_schema ();
        }

        private void init_schema () {
            string schema = """
                CREATE TABLE IF NOT EXISTS app_usage (
                    app_id TEXT PRIMARY KEY,
                    count INTEGER DEFAULT 1,
                    last_used INTEGER
                );
                CREATE TABLE IF NOT EXISTS clipboard_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    content TEXT NOT NULL,
                    mime_type TEXT DEFAULT 'text/plain',
                    source_app TEXT,
                    timestamp INTEGER,
                    pinned INTEGER DEFAULT 0
                );
                CREATE INDEX IF NOT EXISTS idx_clip_time ON clipboard_history(timestamp DESC);
            """;

            char* errmsg;
            int rc = db.exec (schema, null, out errmsg);
            if (rc != Sqlite.OK) {
                warning ("Failed to init database schema: %s", (string) errmsg);
            }
        }

        public void record_app_launch (string app_id) {
            string sql = """
                INSERT INTO app_usage (app_id, count, last_used)
                VALUES (?1, 1, unixepoch())
                ON CONFLICT(app_id) DO UPDATE SET
                    count = count + 1,
                    last_used = unixepoch();
            """;

            Statement stmt;
            int rc = db.prepare_v2 (sql, -1, out stmt);
            if (rc == Sqlite.OK) {
                stmt.bind_text (1, app_id);
                stmt.step ();
            }
        }

        public int get_app_usage_count (string app_id) {
            string sql = "SELECT count FROM app_usage WHERE app_id = ?1";
            Statement stmt;
            int rc = db.prepare_v2 (sql, -1, out stmt);
            if (rc == Sqlite.OK) {
                stmt.bind_text (1, app_id);
                if (stmt.step () == Sqlite.ROW) {
                    return stmt.column_int (0);
                }
            }
            return 0;
        }

        public void add_clipboard_entry (string content, string mime_type = "text/plain", string? source_app = null) {
            if (content.strip ().length == 0) return;

            // Avoid immediate duplicate of last entry
            string check_sql = "SELECT content FROM clipboard_history ORDER BY id DESC LIMIT 1";
            Statement check_stmt;
            if (db.prepare_v2 (check_sql, -1, out check_stmt) == Sqlite.OK) {
                if (check_stmt.step () == Sqlite.ROW) {
                    if (check_stmt.column_text (0) == content) {
                        return;
                    }
                }
            }

            string sql = """
                INSERT INTO clipboard_history (content, mime_type, source_app, timestamp)
                VALUES (?1, ?2, ?3, unixepoch());
            """;

            Statement stmt;
            int rc = db.prepare_v2 (sql, -1, out stmt);
            if (rc == Sqlite.OK) {
                stmt.bind_text (1, content);
                stmt.bind_text (2, mime_type);
                stmt.bind_text (3, source_app ?? "Unknown");
                stmt.step ();
            }
        }

        public List<string> get_recent_clipboard (int limit = 50, string? search = null) {
            var list = new List<string> ();
            string sql = "SELECT content FROM clipboard_history WHERE 1=1";
            if (search != null && search.length > 0) {
                sql += " AND content LIKE ?1";
            }
            sql += " ORDER BY id DESC LIMIT " + limit.to_string ();

            Statement stmt;
            if (db.prepare_v2 (sql, -1, out stmt) == Sqlite.OK) {
                if (search != null && search.length > 0) {
                    stmt.bind_text (1, "%%%s%%".printf (search));
                }
                while (stmt.step () == Sqlite.ROW) {
                    list.append (stmt.column_text (0));
                }
            }
            return list;
        }
    }
}
