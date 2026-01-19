import uuid
import time
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func # Nécessaire pour les sommes (SUM)
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

# --- 2. RECHARGER LE TÉLÉPHONE (Avec Historique pour Audit) ---
@router.post("/recharge-offline")
def recharge_offline(req: RechargeRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == req.phone).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")

    # Vérification du solde réel disponible
    available_online = user.balance - user.offline_reserved_amount
    
    if available_online < req.amount:
        raise HTTPException(status_code=400, detail="Solde Cloud insuffisant")
    
    # A. Verrouillage des fonds
    user.offline_reserved_amount += req.amount

    # B. CRUCIAL : CRÉATION DE LA TRACE (Pour l'audit futur)
    # On enregistre que de l'argent est entré dans le téléphone
    # On utilise "BANK_SYSTEM" comme expéditeur pour dire que ça vient du Cloud
    recharge_tx = models.Transaction(
        transaction_uuid=str(uuid.uuid4()),
        sender_pk="BANK_SYSTEM",       
        receiver_pk=user.public_key,   
        amount=req.amount,
        type="RECHARGE_OFFLINE",       # Type spécifique pour le filtre
        timestamp=int(time.time() * 1000),
        status="COMPLETED",
        is_offline_synced=False        # C'est une action Online
    )
    db.add(recharge_tx)
    
    db.commit()
    
    return {
        "status": "success", 
        "message": "Transfert vers coffre réussi",
        "new_offline_vault": user.offline_reserved_amount,
        "new_online_balance": user.balance - user.offline_reserved_amount
    }

# --- 3. AUDIT DE SÉCURITÉ (La fameuse logique de calcul) ---
# Appelle cette route si un utilisateur perd son téléphone
@router.get("/{phone}/audit-security")
def audit_user_offline_status(phone: str, db: Session = Depends(database.get_db)):
    """
    Recalcule combien le client devrait avoir en offline 
    en se basant sur tout son historique (Entrées - Sorties).
    """
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # 1. SOMME DES RECHARGES (Argent ENTRÉ dans le téléphone)
    total_loaded = db.query(func.sum(models.Transaction.amount))\
        .filter(models.Transaction.receiver_pk == user.public_key)\
        .filter(models.Transaction.type == "RECHARGE_OFFLINE")\
        .scalar() or 0.0

    # 2. SOMME DES DÉPENSES (Argent SORTI et synchronisé)
    total_spent = db.query(func.sum(models.Transaction.amount))\
        .filter(models.Transaction.sender_pk == user.public_key)\
        .scalar() or 0.0

    # 3. LE VERDICT (Combien il doit rester logiquement)
    theoretical_remaining = total_loaded - total_spent

    return {
        "user": user.full_name,
        "audit_report": {
            "total_loaded_in_phone": total_loaded,
            "total_spent_sync": total_spent,
            "should_have_remaining": theoretical_remaining,
            "current_reserved_amount": user.offline_reserved_amount,
            "can_be_refunded": theoretical_remaining
        }
    }

# --- 4. RÉCUPÉRATION MANUELLE (Urgence / Remise à zéro) ---
@router.post("/emergency-refund/{phone}")
def emergency_refund(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    amount_to_return = user.offline_reserved_amount
    user.offline_reserved_amount = 0
    
    db.commit()
    return {"status": "refunded", "amount_returned": amount_to_return}