from datetime import datetime, timezone
import json

import pytest

from app.main import app
from app.config import settings
from app.coaching.router import get_coaching_context
from app.coaching.service import ACTIONS, generate_plan, rank_actions
from app.healthbot.review import content_digest, review_status
from app.worker import due_slots


def test_outcomes_never_cross_participants_or_treat_censored_tails_as_no_lapse():
    pd = pytest.importorskip("pandas")
    pytest.importorskip("xgboost")
    from ml.evaluate_candidate import build_outcomes
    frame = pd.DataFrame({"id": ["a", "b", "a", "b"], "EMA_date_time": [1, 1, 2, 2],
                          "EMA_number": [1, 1, 2, 2], "lapse_event_imp": [0, 1, 1, 0]})
    rebuilt = build_outcomes(frame)
    assert list(rebuilt["id"]) == ["a", "b"]
    assert list(rebuilt["next_lapse"]) == [1, 0]


def test_outcome_learner_uses_completed_contextual_feedback_only():
    observations = [{"alternativeId": "short_walk", "outcomeHelped": True,
                     "triggerCategory": "other", "mood": "happy"}] * 5
    observations += [{"alternativeId": "breathing", "outcomeHelped": None}] * 100
    ranked = rank_actions(observations, "other", "happy")
    assert ranked[0]["alternative_id"] == "short_walk"
    assert next(row for row in ranked if row["alternative_id"] == "breathing")["completed_outcomes"] == 0
    assert {row["alternative_id"] for row in ranked} == set(ACTIONS)


@pytest.mark.asyncio
async def test_offline_plan_is_personalized_and_labeled():
    plan = await generate_plan({"profile": {}, "attempts": [], "cravings": [{}]}, "restart", "boredom", "bored", api_key=None, model="test")
    assert plan["source"] == "personalized_fallback"
    assert plan["medical_review_status"] == "pending"
    assert "slip" in plan["steps"][0]
    assert all(action in ACTIONS for action in plan["action_ids"])


@pytest.mark.asyncio
async def test_gemini_cannot_invent_actions_or_medication_plans(monkeypatch):
    from app.coaching import service
    class Response:
        def raise_for_status(self): pass
        def json(self):
            return {"candidates": [{"content": {"parts": [{"text": json.dumps({"action_ids": ["take_drugs", "breathing", "cold_water"]})}]}}]}
    class Client:
        def __init__(self, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def post(self, *args, **kwargs): return Response()
    monkeypatch.setattr(service.httpx, "AsyncClient", Client)
    result = await service.generate_plan({'cravings': [{}]}, "weekly", "other", "happy", api_key="not-real", model="test")
    assert result["source"] == "personalized_fallback"
    assert "take_drugs" not in result["action_ids"]


@pytest.mark.asyncio
async def test_new_account_gets_generic_plan_without_calling_gemini(monkeypatch):
    from app.coaching import service
    def unexpected_call(**kwargs):
        raise AssertionError('New account should not require AI generation')
    monkeypatch.setattr(service.httpx, 'AsyncClient', unexpected_call)
    result = await service.generate_plan({}, 'initial', 'other', 'happy', api_key='not-real', model='test')
    assert result['source'] == 'generic_starter'
    assert len(result['steps']) == 5


@pytest.mark.asyncio
async def test_usage_only_account_receives_personalized_plan():
    result = await generate_plan(
        {'profile': {'quitStrategy': 'gradual'}, 'usage': [{'actualUsage': 2, 'targetUsage': 3}]},
        'weekly', 'other', 'happy', api_key=None, model='test',
    )
    assert result['source'] == 'personalized_fallback'
    assert len(result['action_ids']) == 3


@pytest.mark.asyncio
@pytest.mark.parametrize('object_response', [True, False])
async def test_usage_only_ai_plan_accepts_validated_selection_formats(monkeypatch, object_response):
    from app.coaching import service
    ids = ['breathing', 'cold_water', 'short_walk']
    class Response:
        def raise_for_status(self): pass
        def json(self):
            selection = {'action_ids': ids} if object_response else ids
            return {'candidates': [{'content': {'parts': [{'text': json.dumps(selection)}]}}]}
    class Client:
        def __init__(self, **kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *args): pass
        async def post(self, *args, **kwargs):
            assert kwargs['json']['generationConfig']['responseSchema']['required'] == ['action_ids']
            return Response()
    monkeypatch.setattr(service.httpx, 'AsyncClient', Client)
    result = await service.generate_plan({'usage': [{}]}, 'weekly', 'other', 'happy', api_key='test', model='test')
    assert result['source'] == 'gemini_catalogue_selection'
    assert result['action_ids'] == ids


def test_coaching_cannot_read_or_write_another_account(client, firebase_identity, monkeypatch):
    calls = []
    class Context:
        def read(self, uid):
            calls.append(("read", uid))
            return {"profile": {}, "attempts": [], "cravings": []}
        def save_plan(self, uid, kind, plan): calls.append(("save", uid))
    app.dependency_overrides[get_coaching_context] = lambda: Context()
    firebase_identity.valid_tokens["good"] = "owner"
    monkeypatch.setattr(settings, "gemini_api_key", None)
    response = client.post("/plans/weekly", json={"user_id": "victim"}, headers={"Authorization": "Bearer good"})
    assert response.status_code == 200
    assert calls == [("read", "owner"), ("save", "owner")]
    assert client.post("/recommend/alternative", json={}).status_code == 401


def test_timezone_delivery_is_due_once_in_a_single_minute_and_not_replayed_late():
    schedule = {"enabled": True, "timezone": "Asia/Karachi", "dailyTimes": ["10:00", "15:00", "20:00"]}
    now = datetime(2026, 11, 17, 5, 0, 30, tzinfo=timezone.utc)
    assert due_slots(schedule, now) == [("2026-11-17_1000_daily_checkin", "daily_checkin")]
    assert due_slots(schedule, now.replace(minute=2)) == []
    assert due_slots({**schedule, "enabled": False}, now) == []


def test_scheduler_rejects_duplicate_slots_and_out_of_range_frequency():
    with pytest.raises(ValueError):
        due_slots({"enabled": True, "timezone": "UTC", "dailyTimes": ["10:00"] * 3}, datetime.now(timezone.utc))


def test_clinical_approval_is_bound_to_exact_content(tmp_path):
    record = tmp_path / "review.json"
    payload = {"approved": True, "reviewer": "Test advisor fixture", "reviewed_at": "2026-01-01T00:00:00+00:00", "content_sha256": content_digest()}
    record.write_text(json.dumps(payload))
    assert review_status(str(record)) == "approved_catalogue"
    payload["content_sha256"] = "old version"
    record.write_text(json.dumps(payload))
    assert review_status(str(record)) == "pending"


def test_emergencies_are_not_blocked_by_pending_clinical_review(client, firebase_identity, monkeypatch):
    firebase_identity.valid_tokens["good"] = "owner"
    monkeypatch.setattr(settings, "require_clinical_review", True)
    monkeypatch.setattr(settings, "clinical_review_record", None)
    headers = {"Authorization": "Bearer good"}
    assert client.post("/healthbot/query", json={"query": "headache"}, headers=headers).status_code == 503
    urgent = client.post("/healthbot/query", json={"query": "severe anxiety"}, headers=headers)
    assert urgent.status_code == 200
    assert urgent.json()["answer_type"] == "emergency"


def test_candidate_context_rejects_unknown_fields_and_non_finite_ratings(client, firebase_identity):
    firebase_identity.valid_tokens["good"] = "owner"
    body = {"intensity": 5, "mood": "happy", "trigger_category": "other", "last_24h_count": 1,
            "recovery_context": {"cigarette_availability_imp": 8}}
    assert client.post("/predict/relapse", json=body, headers={"Authorization": "Bearer good"}).status_code == 422


def test_push_schedule_uses_authenticated_owner_and_validates_times(client, firebase_identity):
    saved = []
    class Reference:
        def __init__(self, path=()): self.path = path
        def collection(self, name): return Reference((*self.path, name))
        def document(self, name): return Reference((*self.path, name))
        def set(self, payload): saved.append((self.path, payload))
    class Context:
        def database(self): return Reference()
    app.dependency_overrides[get_coaching_context] = lambda: Context()
    firebase_identity.valid_tokens["good"] = "owner"
    payload = {"enabled": True, "timezone": "Asia/Karachi", "dailyTimes": ["10:00", "15:00", "20:00"], "user_id": "victim"}
    headers = {"Authorization": "Bearer good"}
    assert client.put("/notifications/schedule", json=payload, headers=headers).status_code == 200
    assert saved[0][0] == ("nicotineUsers", "owner", "reminderSchedules", "daily")
    assert client.put("/notifications/schedule", json={**payload, "dailyTimes": ["99:00"] * 3}, headers=headers).status_code == 422
    assert client.put("/notifications/schedule", json=payload).status_code == 401
