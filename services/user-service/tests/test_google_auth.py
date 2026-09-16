"""Google login and stale PostgreSQL connection regressions."""
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, Mock

import psycopg2
from psycopg2.pool import PoolError
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import create_app
from app import models
from app.models import create_google_user


@pytest.fixture
def postgres_pool(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://database.invalid/test")
    monkeypatch.setenv("USE_REAL_DB_FOR_TESTS", "1")
    monkeypatch.delenv("USER_DATABASE_URL", raising=False)
    pool = Mock()
    monkeypatch.setattr(models, "_pool", pool)
    monkeypatch.setattr(models, "_test_sqlite_conn", None)
    return pool


def test_healthy_pooled_connection_is_checked_before_use(postgres_pool):
    connection = MagicMock()
    postgres_pool.getconn.return_value = connection
    assert models.get_connection() is connection
    connection.cursor.return_value.__enter__.return_value.execute.assert_called_once_with("SELECT 1")
    connection.rollback.assert_called_once_with()
    postgres_pool.putconn.assert_not_called()


def test_stale_ssl_connection_is_discarded_before_authentication(postgres_pool):
    stale = MagicMock()
    stale.cursor.side_effect = psycopg2.OperationalError("SSL connection has been closed unexpectedly")
    fresh = MagicMock()
    postgres_pool.getconn.side_effect = [stale, fresh]
    assert models.get_connection() is fresh
    postgres_pool.putconn.assert_called_once_with(stale, close=True)
    assert postgres_pool.getconn.call_count == 2
    assert models._test_sqlite_conn is None


def test_repeated_connection_failures_do_not_fall_back_to_empty_accounts(postgres_pool):
    stale = MagicMock()
    stale.cursor.side_effect = psycopg2.InterfaceError("connection already closed")
    postgres_pool.getconn.return_value = stale
    with pytest.raises(psycopg2.InterfaceError):
        models.get_connection()
    assert postgres_pool.getconn.call_count == 2
    assert postgres_pool.putconn.call_count == 2
    assert models._test_sqlite_conn is None


def test_postgres_startup_failure_does_not_create_a_sqlite_fallback(postgres_pool, monkeypatch):
    monkeypatch.setattr(models, "_pool", None)
    unavailable = Mock(side_effect=psycopg2.OperationalError("Database unavailable"))
    monkeypatch.setattr(models, "ThreadedConnectionPool", unavailable)
    monkeypatch.setattr(models.psycopg2, "connect", unavailable)
    with pytest.raises(psycopg2.OperationalError):
        models.get_connection()
    assert models._test_sqlite_conn is None


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "sqlite")
    monkeypatch.setenv("USE_SQLITE", "1")
    monkeypatch.delenv("USE_REAL_DB_FOR_TESTS", raising=False)
    app = create_app()
    app.config["TESTING"] = True
    return app.test_client()


@pytest.mark.parametrize("error", [
    psycopg2.OperationalError("private connection details"),
    psycopg2.InterfaceError("private connection details"),
    PoolError("private connection details"),
])
def test_google_database_failure_returns_safe_retryable_json(client, monkeypatch, error):
    verified = Mock(status_code=200)
    verified.json.return_value = {"email": "alice@example.com"}
    monkeypatch.setattr("app.routes.requests.get", Mock(return_value=verified))
    monkeypatch.setattr("app.routes.get_user_by_email", Mock(side_effect=error))
    response = client.post("/auth/google", json={"id_token": "test-google-token"})
    assert response.status_code == 503
    assert response.is_json
    assert "try again" in response.json["error"].lower()
    assert "private connection details" not in response.get_data(as_text=True)


def test_google_login_reuses_existing_account_and_returns_a_token(client, monkeypatch):
    original = create_google_user("existing-traveler", "alice@example.com", [])
    verified = Mock(status_code=200)
    verified.json.return_value = {"email": "alice@example.com"}
    monkeypatch.setattr("app.routes.requests.get", Mock(return_value=verified))
    response = client.post("/auth/google", json={"id_token": "test-google-token"})
    assert response.status_code == 200
    assert response.json["username"] == original["username"]
    assert isinstance(response.json["token"], str)
    assert models.get_user_by_email("alice@example.com")["id"] == original["id"]


@pytest.mark.skipif(
    os.environ.get("USE_REAL_DB_FOR_TESTS") != "1",
    reason="Requires a disposable PostgreSQL database",
)
def test_google_login_recovers_after_postgres_closes_an_idle_connection(monkeypatch):
    app = create_app()
    app.config["TESTING"] = True
    original = create_google_user("returning-google-user", "returning@example.com", [])
    pooled = models.get_connection(app)
    backend_pid = pooled.get_backend_pid()
    models.release_connection(pooled)
    killer = psycopg2.connect(os.environ["DATABASE_URL"], connect_timeout=10)
    try:
        killer.autocommit = True
        with killer.cursor() as cursor:
            cursor.execute("SELECT pg_terminate_backend(%s)", (backend_pid,))
            assert cursor.fetchone()[0] is True
    finally:
        killer.close()
    verified = Mock(status_code=200)
    verified.json.return_value = {"email": "returning@example.com"}
    monkeypatch.setattr("app.routes.requests.get", Mock(return_value=verified))
    response = app.test_client().post("/auth/google", json={"id_token": "test-google-token"})
    assert response.status_code == 200
    assert response.json["username"] == original["username"]
    assert models.get_user_by_email("returning@example.com")["id"] == original["id"]
