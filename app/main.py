"""FastAPI application entrypoint."""
from fastapi import FastAPI

from app.config import get_settings
from app.database import Base, engine
from app.routers import intake

settings = get_settings()

# Create tables on startup. In a larger system this is handled by Alembic migrations.
Base.metadata.create_all(bind=engine)

app = FastAPI(title=settings.app_name, version="1.0.0")
app.include_router(intake.router)


@app.get("/health", tags=["ops"])
def health():
    """Liveness/readiness probe for load balancers and container orchestration."""
    return {"status": "ok", "service": settings.app_name, "environment": settings.environment}
