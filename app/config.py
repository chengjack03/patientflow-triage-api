"""Application configuration loaded from environment variables."""
from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "PatientFlow Triage API"
    environment: str = "development"
    # Database (SQLAlchemy URL). Defaults to local SQLite so the app runs with zero setup;
    # in Docker/AWS this is overridden with a PostgreSQL URL.
    database_url: str = "sqlite:///./patientflow.db"
    # LLM
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-4-5"
    # If true, skip live LLM calls and return a deterministic stub (used by CI/tests).
    llm_stub_mode: bool = False

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> "Settings":
    return Settings()
