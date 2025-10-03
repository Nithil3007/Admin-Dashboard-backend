"""
Pytest configuration and shared fixtures
"""
import os
import sys
import pytest
import psycopg2
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from main import app


@pytest.fixture(scope="session")
def db_connection():
    """Database connection for tests"""
    db_params = {
        "host": os.getenv("DB_HOST", "localhost"),
        "database": os.getenv("DB_NAME", "test_db"),
        "user": os.getenv("DB_USER", "postgres"),
        "password": os.getenv("DB_PASSWORD", "password"),
        "port": os.getenv("DB_PORT", "5432")
    }
    
    conn = None
    try:
        conn = psycopg2.connect(**db_params)
        yield conn
    except psycopg2.Error as e:
        pytest.skip(f"Database connection failed: {e}")
    finally:
        if conn:
            conn.close()


@pytest.fixture(scope="module")
def client():
    """FastAPI test client"""
    with TestClient(app) as test_client:
        yield test_client
