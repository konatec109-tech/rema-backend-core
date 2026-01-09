from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core import database
from app import models
from pydantic import BaseModel

router = APIRouter(prefix="/users")

# --- MODÈLES DE DONNÉES ---
class RechargeRequest(BaseModel):
    amount: float
    phone: str 

class SyncRequest(BaseModel):
    sender_phone: str
    amount: float
    tx_id: str

# --- 1. VOIR LE SOLDE (Cloud vs Offline) ---
@router.get("/{phone}/balance")
def get_balance(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    # Calcul du solde disponible en ligne
    online_balance = user.balance - user.offline_reserved_amount
    
    return {
        "full_name": user.full_name,
        "online_balance": online_balance,
        "offline_vault": user.offline_reserved_amount
    }

# --- 2. RECHARGER LE TÉLÉPHONE (Standard REMA) ---
# C'est la seule et unique route que le SDK appelle.
@router.post("/recharge-offline")
def recharge_offline(req: RechargeRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == req.phone).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")

    # Vérification du solde réel disponible
    available_online = user.balance - user.offline_reserved_amount
    
    if available_online < req.amount:
        raise HTTPException(status_code=400, detail="Solde Cloud insuffisant")
    
    # Verrouillage des fonds
    user.offline_reserved_amount += req.amount
    db.commit()
    
    return {
        "status": "success", 
        "message": "Transfert vers coffre réussi",
        "new_offline_vault": user.offline_reserved_amount,
        "new_online_balance": user.balance - user.offline_reserved_amount
    }

# --- 3. SYNCHRONISATION (Marchand -> Cloud) ---
@router.post("/sync-payment")
def sync_payment(req: SyncRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == req.sender_phone).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Émetteur non trouvé")

    # Si la réserve offline couvre le paiement
    if user.offline_reserved_amount >= req.amount:
        # 1. On diminue la réserve
        user.offline_reserved_amount -= req.amount
        # 2. On diminue le solde total (l'argent a été dépensé)
        user.balance -= req.amount
        
        db.commit()
        return {"status": "synced", "tx_id": req.tx_id}
    
    raise HTTPException(status_code=400, detail="Erreur de réconciliation : Réserve insuffisante")

# --- 4. RÉCUPÉRATION MANUELLE (Urgence) ---
@router.post("/emergency-refund/{phone}")
def emergency_refund(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    amount_to_return = user.offline_reserved_amount
    user.offline_reserved_amount = 0
    
    db.commit()
    return {"status": "refunded", "amount_returned": amount_to_return}