from fastapi.testclient import TestClient
from src.app import app

client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "version" in response.json()


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_get_item_valid():
    response = client.get("/items/1")
    assert response.status_code == 200
    assert response.json()["item_id"] == 1


def test_get_item_invalid():
    response = client.get("/items/-1")
    assert response.status_code == 400


def test_create_item():
    response = client.post("/items", json={
        "name": "Laptop",
        "description": "Un bon laptop",
        "price": 999.99
    })
    assert response.status_code == 200
    assert response.json()["item"]["name"] == "Laptop"


def test_create_item_invalid_price():
    response = client.post("/items", json={
        "name": "Test",
        "price": -10.0
    })
    assert response.status_code == 400
