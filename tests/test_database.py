"""
Unit tests for database connectivity
"""


def test_database_connection(db_connection):
    """Test database connection works"""
    cursor = db_connection.cursor()
    cursor.execute("SELECT 1")
    result = cursor.fetchone()
    assert result == (1,)
    cursor.close()
