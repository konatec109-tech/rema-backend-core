from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core import database
from typing import List

# Import des modèles et schémas
from app.models.user import User 
from app.schemas.user import RechargeRequest, RecoverRequest, UserResponse

router = APIRouter(prefix="/users", tags=["Users"])

# --- 1. VOIR LE SOLDE ---
@router.get("/{phone}/balance")
def get_balance(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(User).filter(User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    return {
        "full_name": user.full_name,
        "balance_atomic": user.balance_atomic,         # Solde BANQUE
        "offline_vault_atomic": user.offline_reserved_atomic # Solde TÉLÉPHONE (Sync)
    }

# --- 2. RECHARGER LE TÉLÉPHONE (Correction Mathématique) ---
@router.post("/recharge-offline")
def recharge_offline(req: RechargeRequest, db: Session = Depends(database.get_db)):
    user = db.query(User).filter(User.phone_number == req.phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    if req.amount <= 0:
        raise HTTPException(status_code=400, detail="Montant invalide")
    
    # 🔥 CORRECTION CRITIQUE ICI 🔥
    # Avant: On ajoutait partout (Création d'argent magique)
    # Maintenant: On retire de la Banque (-) pour mettre dans le Téléphone (+)
    
    if user.balance_atomic < req.amount:
        raise HTTPException(status_code=400, detail="Solde bancaire insuffisant")

    user.balance_atomic -= req.amount          # On débit la Banque
    user.offline_reserved_atomic += req.amount # On crédit le "Vault" du téléphone

    db.commit()
    db.refresh(user)
    
    # On renvoie le nouveau solde BANQUE pour que l'app se mette à jour
    return {"status": "success", "new_online_balance": user.balance_atomic}

# --- 3. SÉCURITÉ : BLACKLIST ---
@router.get("/security/blacklist", response_model=List[str])
def get_security_blacklist(db: Session = Depends(database.get_db)):
    return []

# --- 4. RÉCUPÉRATION ---
@router.post("/recover-lost-device")
def recover_lost_device(req: RecoverRequest, db: Session = Depends(database.get_db)):
    user = db.query(User).filter(User.phone_number == req.phone).first()
    if not user: 
         raise HTTPException(status_code=403, detail="Accès refusé")
    
    # En cas de perte, on remet l'argent offline vers online (si possible)
    # Pour l'instant, on reset juste le offline pour éviter le vol
    user.offline_reserved_atomic = 0 
    db.commit()
    return {"status": "success"}