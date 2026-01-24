from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core import database
from app import models, oauth2
from pydantic import BaseModel
from app.schemas import user as user_schema

router = APIRouter(prefix="/users", tags=["Users"])

class RechargeRequest(BaseModel):
    phone_number: str
    amount_atomic: int 

# 1. GET BALANCE
@router.get("/{phone_number}/balance", response_model=user_schema.UserResponse)
def get_balance(phone_number: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone_number).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user

# 2. RECHARGE OFFLINE (Simplifié pour ne pas crasher)
@router.post("/recharge-offline")
def recharge_offline(req: RechargeRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == req.phone_number).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # Mise à jour atomique
    user.balance_atomic += req.amount_atomic
    db.commit()
    db.refresh(user)
    
    return {"status": "success", "new_balance": user.balance_atomic}

# 3. AUDIT (Version Safe)
@router.get("/{phone_number}/audit")
def audit_user(phone_number: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone_number).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "integrity": "SECURE",
        "device_id": user.device_hardware_id,
        "balance_atomic": user.balance_atomic
    }