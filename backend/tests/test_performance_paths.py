"""Step 13: recommendation endpoint reads only what it ranks."""
from app.coaching.router import get_coaching_context
from app.main import app


def test_recommend_reads_only_attempts(client, firebase_identity):
    calls = []

    class Context:
        def read(self, uid):
            calls.append("read")
            return {"profile": {}, "attempts": [], "cravings": [], "usage": []}

        def read_attempts(self, uid):
            calls.append(("read_attempts", uid))
            return []

    app.dependency_overrides[get_coaching_context] = lambda: Context()
    firebase_identity.valid_tokens["perf"] = "owner"
    response = client.post("/recommend/alternative", json={"trigger_category": "stress", "mood": "stressed"},
                           headers={"Authorization": "Bearer perf"})
    assert response.status_code == 200
    assert calls == [("read_attempts", "owner")]
    assert "recommendations" in response.json()


def test_recommend_still_works_with_contexts_that_only_implement_read(client, firebase_identity):
    class Legacy:
        def read(self, uid):
            return {"profile": {}, "attempts": [], "cravings": [], "usage": []}

    app.dependency_overrides[get_coaching_context] = lambda: Legacy()
    firebase_identity.valid_tokens["perf"] = "owner"
    response = client.post("/recommend/alternative", json={}, headers={"Authorization": "Bearer perf"})
    assert response.status_code == 200
