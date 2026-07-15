"""LLM integration: turn free-text symptoms into a structured triage result.

Uses the Anthropic Claude API and requests a strict JSON object (structured output).
Falls back to a deterministic stub when LLM_STUB_MODE is set, so tests and CI run
without network access or API keys.
"""
import json

from app.config import get_settings
from app.schemas import TriageResult

settings = get_settings()

_SYSTEM_PROMPT = (
    "You are a clinical intake triage assistant. Given a patient's reported symptoms, "
    "classify urgency and route them. Respond with ONLY a JSON object with keys: "
    '"urgency_level" (one of: emergency, urgent, routine, self_care), '
    '"recommended_department" (short string), and "summary" (one sentence). '
    "You are not a diagnosis; err toward caution on ambiguous, high-risk symptoms."
)


def _stub(symptoms: str) -> TriageResult:
    text = symptoms.lower()
    if any(k in text for k in ("chest", "breath", "stroke", "bleeding", "unconscious")):
        return TriageResult(
            urgency_level="emergency",
            recommended_department="Emergency Department",
            summary="High-risk symptoms reported; immediate evaluation recommended.",
        )
    return TriageResult(
        urgency_level="routine",
        recommended_department="Primary Care",
        summary="Non-urgent symptoms; routine primary care follow-up suggested.",
    )


def triage(symptoms: str) -> TriageResult:
    if settings.llm_stub_mode or not settings.anthropic_api_key:
        return _stub(symptoms)

    # Imported lazily so the package isn't required in stub/CI mode.
    from anthropic import Anthropic

    client = Anthropic(api_key=settings.anthropic_api_key)
    message = client.messages.create(
        model=settings.anthropic_model,
        max_tokens=400,
        system=_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": symptoms}],
    )
    raw = message.content[0].text.strip()
    data = json.loads(raw)
    return TriageResult(**data)
