from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core import database
from app import models
from pydantic import BaseModel

router = APIRouter(prefix="/users")

# --- MODÈLES POUR LES REQUÊTES (Validation des données) ---
class RechargeRequest(BaseModel):
    phone: str
    amount: float

class SyncRequest(BaseModel):
    sender_phone: str
    amount: float
    tx_id: str

# --- 1. VOIR LE SOLDE (Cloud vs Offline) ---
# Utile pour afficher "Banque: 40.000F | Coffre: 10.000F" sur Flutter
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

# --- 2. RECHARGER LE TÉLÉPHONE (Cloud -> Offline) ---
# Déduit du solde principal pour mettre dans le coffre offline
@router.post("/recharge-offline")
def recharge_offline(req: RechargeRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == req.phone).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")

    # Calcul du solde réellement dispo sur le cloud
    available_online = user.balance - user.offline_reserved_amount
    
    if available_online < req.amount:
        raise HTTPException(status_code=400, detail="Solde Cloud insuffisant")
    
    # On augmente la réserve (l'argent est bloqué pour le offline)
    user.offline_reserved_amount += req.amount
    db.commit()
    
    return {
        "status": "success", 
        "message": f"{req.amount} F transférés vers le coffre offline",
        "new_offline_vault": user.offline_reserved_amount
    }

# --- 3. SYNCHRONISATION (Marchand -> Cloud) ---
# Le marchand envoie la preuve, le serveur déduit définitivement
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

# --- 4. RÉCUPÉRATION MANUELLE (En cas de perte du tel) ---
# On remet la réserve à zéro et on rend l'argent au solde cloud
@router.post("/emergency-refund/{phone}")
def emergency_refund(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    amount_to_return = user.offline_reserved_amount
    user.offline_reserved_amount = 0
    # On ne touche pas à user.balance car l'argent y est déjà, 
    # il est juste libéré de sa réserve.
    
    db.commit()
    return {"status": "refunded", "amount_returned": amount_to_return}