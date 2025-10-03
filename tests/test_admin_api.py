"""
Unit tests for API endpoints
"""


def test_health_check(client):
    """Test GET / health check endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


def test_get_user_stats(client):
    """Test GET /admin/users/stats endpoint"""
    response = client.get("/admin/users/stats")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_upgrade_user_missing_tier(client):
    """Test POST /admin/users/{user_id}/upgrade without tier_name"""
    response = client.post(
        "/admin/users/test-user/upgrade",
        json={}
    )
    assert response.status_code == 422
