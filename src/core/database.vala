using Sqlite;

namespace Poisk.Core {

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
            string data_dir = Path.build_filename (Environment.get_user_data_dir (), "poisk");
            DirUtils.create_with_parents (data_dir, 0755);
            string db_path = Path.build_filename (data_dir, "poisk.db");

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
    }
}
