"""Pydantic request/response schemas."""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

UrgencyLevel = Literal["emergency", "urgent", "routine", "self_care"]


class IntakeRequest(BaseModel):
    patient_reference: str = Field(..., max_length=64, examples=["patient-00421"])
    reported_symptoms: str = Field(..., min_length=3, examples=["Chest tightness and shortness of breath for 2 hours"])


class TriageResult(BaseModel):
    urgency_level: UrgencyLevel
    recommended_department: str
    summary: str


class IntakeResponse(TriageResult):
    id: int
    patient_reference: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
