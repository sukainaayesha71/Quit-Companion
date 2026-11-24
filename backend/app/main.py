import time
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from .config import settings

from .account_deletion.router import router as account_router
from .healthbot.router import router as healthbot_router
from .notifications.router import router as notifications_router
from .otp.router import router as phone_auth_router
from .relapse.router import router as relapse_router
from .coaching.router import router as coaching_router
from .content.router import router as content_router

app = FastAPI(title="Quit Companion API")
app.include_router(phone_auth_router)
app.include_router(relapse_router)
app.include_router(healthbot_router)
app.include_router(notifications_router)
app.include_router(account_router)
app.include_router(coaching_router)
app.include_router(content_router)


@app.middleware("http")
async def response_timing(request: Request, call_next):
    started = time.perf_counter()
    response = await call_next(request)
    response.headers["X-Response-Time-Ms"] = f"{(time.perf_counter() - started) * 1000:.1f}"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.get("/ready")
def readiness():
    from .healthbot.review import review_status
    ready = bool(settings.firebase_service_account_json)
    if settings.require_clinical_review:
        ready = ready and review_status(settings.clinical_review_record) == "approved_catalogue"
    from .dependencies import relapse_predictor_status
    # FR5: which relapse predictor is serving (no paths or secrets). A
    # rule-based fallback doesn't make the API unready unless
    # RELAPSE_MODEL_REQUIRED is set, in which case startup fails instead.
    return JSONResponse(
        status_code=200 if ready else 503,
        content={"ready": ready, "relapse_predictor": dict(relapse_predictor_status)},
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
