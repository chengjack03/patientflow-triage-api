"""Patient intake + triage endpoints."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import models, schemas
from app.database import get_db
from app.llm import triage

router = APIRouter(prefix="/intake", tags=["intake"])


@router.post("", response_model=schemas.IntakeResponse, status_code=201)
def create_intake(payload: schemas.IntakeRequest, db: Session = Depends(get_db)):
    """Accept reported symptoms, run LLM triage, persist, and return the result."""
    result = triage(payload.reported_symptoms)
    record = models.IntakeRecord(
        patient_reference=payload.patient_reference,
        reported_symptoms=payload.reported_symptoms,
        urgency_level=result.urgency_level,
        recommended_department=result.recommended_department,
        summary=result.summary,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("/{record_id}", response_model=schemas.IntakeResponse)
def get_intake(record_id: int, db: Session = Depends(get_db)):
    record = db.get(models.IntakeRecord, record_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Intake record not found")
    return record
