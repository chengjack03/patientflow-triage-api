"""API tests. Run with LLM_STUB_MODE=true so no network/keys are needed."""
import os

os.environ.setdefault("LLM_STUB_MODE", "true")
os.environ.setdefault("DATABASE_URL", "sqlite:///./test.db")

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_intake_emergency_path():
    resp = client.post(
        "/intake",
        json={"patient_reference": "patient-001", "reported_symptoms": "Chest pain and shortness of breath"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["urgency_level"] == "emergency"
    assert body["recommended_department"] == "Emergency Department"
    assert body["id"] > 0


def test_intake_routine_and_fetch():
    created = client.post(
        "/intake",
        json={"patient_reference": "patient-002", "reported_symptoms": "Mild seasonal allergies"},
    ).json()
    fetched = client.get(f"/intake/{created['id']}")
    assert fetched.status_code == 200
    assert fetched.json()["urgency_level"] == "routine"


def test_intake_validation_error():
    resp = client.post("/intake", json={"patient_reference": "p", "reported_symptoms": "x"})
    assert resp.status_code == 422


def test_missing_record_returns_404():
    assert client.get("/intake/999999").status_code == 404
