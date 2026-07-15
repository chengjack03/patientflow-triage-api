"""Relational data model (SQLAlchemy ORM)."""
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String, Text

from app.database import Base


class IntakeRecord(Base):
    """One patient-intake submission and its AI-generated triage result."""

    __tablename__ = "intake_records"

    id = Column(Integer, primary_key=True, index=True)
    patient_reference = Column(String(64), index=True, nullable=False)
    reported_symptoms = Column(Text, nullable=False)
    urgency_level = Column(String(16), index=True, nullable=False)
    recommended_department = Column(String(64), nullable=False)
    summary = Column(Text, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
