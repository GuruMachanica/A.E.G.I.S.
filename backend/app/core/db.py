"""
A.E.G.I.S Database Connection & Session Lifecycle Manager
"""
import contextlib
import logging
import sqlite3
from typing import Generator
from .config import DATABASE_PATH

logger = logging.getLogger(__name__)


def create_connection() -> sqlite3.Connection:
    """Create a new SQLite connection with WAL mode and row factory."""
    conn = sqlite3.connect(DATABASE_PATH, timeout=15.0, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    return conn


@contextlib.contextmanager
def get_db() -> Generator[sqlite3.Connection, None, None]:
    """Context manager for SQLite operations with automatic commit/rollback and cleanup."""
    conn = create_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def get_db_session() -> Generator[sqlite3.Connection, None, None]:
    """FastAPI Dependency yield pattern."""
    with get_db() as conn:
        yield conn


def init_db() -> None:
    """Initialize all database tables and indexes."""
    with get_db() as conn:
        cursor = conn.cursor()
        
        # 1. Users table
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS users (
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
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);")

        # 2. OTP Challenges table
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS otp_challenges (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                channel TEXT NOT NULL,
                destination TEXT NOT NULL,
                otp_hash TEXT NOT NULL,
                pending_token TEXT,
                status TEXT NOT NULL,
                attempts INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """
        )
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_otp_user_id ON otp_challenges(user_id);")

        # 3. Refresh Sessions table
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS refresh_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                refresh_hash TEXT NOT NULL,
                device_id TEXT,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL,
                revoked INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """
        )
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_refresh_hash ON refresh_sessions(refresh_hash);")

        # 4. Call Records table
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS call_records (
                id TEXT PRIMARY KEY,
                user_id INTEGER NOT NULL,
                payload_json TEXT NOT NULL,
                synced_at TEXT NOT NULL,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
            """
        )
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_call_records_user ON call_records(user_id);")

        # 5. AI Call Logs & Reports table
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS ai_call_logs (
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
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_ai_call_logs_call_id ON ai_call_logs(call_id);")
        
        logger.info("Database schema initialized successfully.")
