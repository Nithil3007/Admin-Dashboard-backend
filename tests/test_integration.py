"""
Integration tests
"""
import pytest


@pytest.mark.integration
def test_api_with_database(client, db_connection):
    """Test API endpoint works with database"""
    # Get users from API
    response = client.get("/admin/users/stats")
    assert response.status_code == 200
    
    # Verify database is accessible
    cursor = db_connection.cursor()
    cursor.execute("SELECT COUNT(*) FROM users")
    count = cursor.fetchone()[0]
    cursor.close()
    
    assert count >= 0
