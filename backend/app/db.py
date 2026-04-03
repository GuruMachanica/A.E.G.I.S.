import sqlite3

from .config import DB_PATH


def get_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          full_name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          phone TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          two_fa_enabled INTEGER NOT NULL DEFAULT 0,
          auto_delete_logs INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS otp_challenges(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          channel TEXT NOT NULL,
          destination TEXT NOT NULL,
          otp_hash TEXT NOT NULL,
          pending_token TEXT,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          expires_at TEXT NOT NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS refresh_sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          refresh_hash TEXT NOT NULL,
          device_id TEXT,
          created_at TEXT NOT NULL,
          expires_at TEXT NOT NULL,
          revoked INTEGER NOT NULL DEFAULT 0
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS call_records(
          id TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL,
          payload_json TEXT NOT NULL,
          synced_at TEXT NOT NULL
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS ai_call_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          call_id TEXT UNIQUE NOT NULL,
          call_number TEXT,
          transcription TEXT NOT NULL,
          detected_keywords_json TEXT NOT NULL,
          risk_score REAL NOT NULL,
          risk_level TEXT NOT NULL,
          started_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          raw_payload_json TEXT NOT NULL
        )
        """
    )
    conn.commit()
    conn.close()
