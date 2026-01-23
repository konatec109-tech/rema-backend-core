import uuid
import time
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, or_
from app.core import database
from app import models
from pydantic import BaseModel

router = APIRouter(prefix="/users", tags=["Users"])

# --- MODÈLES Pydantic ---
class RechargeRequest(BaseModel):
    amount: int  # 🔥 INT (Atomic Unit)
    phone: str 

class RecoverRequest(BaseModel):
    phone: str
    pin: str # Pour authentifier la demande critique

# --- 1. VOIR LE SOLDE ---
@router.get("/{phone}/balance")
def get_balance(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    # Calcul du solde disponible en ligne (Atomic)
    online_balance = user.balance_atomic - user.offline_reserved_atomic
    
    return {
        "full_name": user.full_name,
        "balance_atomic": online_balance,
        "offline_vault_atomic": user.offline_reserved_atomic
    }

# --- 2. RECHARGER LE TÉLÉPHONE (Cash-In) ---
@router.post("/recharge-offline")
def recharge_offline(req: RechargeRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == req.phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")

    # Vérif Solde
    available_online = user.balance_atomic - user.offline_reserved_atomic
    
    if available_online < req.amount:
        raise HTTPException(status_code=400, detail="Solde insuffisant")
    
    # A. Verrouillage des fonds
    user.offline_reserved_atomic += req.amount

    # B. Trace Audit (Sender = BANK_SYSTEM)
    recharge_tx = models.Transaction(
        transaction_uuid=str(uuid.uuid4()),
        protocol_ver=1,
        sender_pubk_hash="BANK_SYSTEM",       
        receiver_pubk_hash=user.public_key,   
        amount_atomic=req.amount, # 🔥 INT
        nonce=str(uuid.uuid4()),
        signature="SYSTEM_AUTHORIZED",
        timestamp=int(time.time() * 1000),
        status="COMPLETED",
        is_offline_synced=False # Ce n'est pas une transaction mobile, c'est serveur
    )
    db.add(recharge_tx)
    db.commit()
    
    return {
        "status": "success", 
        "new_offline_vault": user.offline_reserved_atomic
    }

# --- 3. AUDIT MATHÉMATIQUE (LA ROUTE QUI SAUVE LA VIE) ---
# Permet de savoir combien d'argent se trouve PROBABLEMENT dans le téléphone
@router.get("/{phone}/audit")
def audit_user_integrity(phone: str, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # A. SOMME DES RECHARGEMENTS (Tout l'argent entré dans le téléphone)
    # On cherche toutes les tx venant du système vers cet utilisateur
    total_loaded = db.query(func.sum(models.Transaction.amount_atomic))\
        .filter(models.Transaction.receiver_pubk_hash == user.public_key)\
        .filter(models.Transaction.sender_pubk_hash == "BANK_SYSTEM")\
        .scalar() or 0

    # B. SOMME DES DÉPENSES (Tout l'argent sorti et synchronisé par les marchands)
    # On cherche toutes les tx signées par cet utilisateur
    total_spent = db.query(func.sum(models.Transaction.amount_atomic))\
        .filter(models.Transaction.sender_pubk_hash == user.public_key)\
        .scalar() or 0

    # C. LE SOLDE THÉORIQUE (Ce qu'il doit rester dans le téléphone s'il n'a pas volé)
    theoretical_remaining = total_loaded - total_spent

    return {
        "user": user.full_name,
        "audit_report": {
            "total_loaded_in_phone": total_loaded,
            "total_spent_sync": total_spent,
            "should_have_remaining": theoretical_remaining,
            "current_reserved_server_side": user.offline_reserved_atomic,
            "discrepancy": user.offline_reserved_atomic - theoretical_remaining
        }
    }

# --- 4. RÉCUPÉRATION APRÈS PERTE (Emergency Recovery) ---
@router.post("/recover-lost-device")
def recover_lost_device(req: RecoverRequest, db: Session = Depends(database.get_db)):
    # 1. Auth simple (à renforcer avec SMS/OTP en prod)
    user = db.query(models.User).filter(models.User.phone_number == req.phone).first()
    if not user: # ou check PIN
         raise HTTPException(status_code=403, detail="Accès refusé")

    # 2. Exécution de l'Audit Interne
    total_loaded = db.query(func.sum(models.Transaction.amount_atomic))\
        .filter(models.Transaction.receiver_pubk_hash == user.public_key)\
        .filter(models.Transaction.sender_pubk_hash == "BANK_SYSTEM")\
        .scalar() or 0

    total_spent = db.query(func.sum(models.Transaction.amount_atomic))\
        .filter(models.Transaction.sender_pubk_hash == user.public_key)\
        .scalar() or 0
        
    theoretical_remaining = total_loaded - total_spent
    
    # Sécurité : On ne peut pas rembourser moins que 0
    refund_amount = max(0, theoretical_remaining)

    # 3. Mouvements de fonds (Restitution)
    # On considère que le "reserved" (l'argent dans le tel perdu) est récupéré
    user.offline_reserved_atomic = 0 
    
    # Note: Dans un système parfait, 'balance_atomic' contient déjà tout.
    # 'offline_reserved' n'était qu'un marqueur de risque.
    # En le remettant à 0, l'argent redevient "Disponible Online".
    
    # 4. Sécurité : Blacklist de l'ancien Device
    user.is_blacklisted = True # L'ancien téléphone ne pourra plus jamais synchroniser
    
    # On peut aussi invalider sa Public Key actuelle pour forcer une nouvelle génération
    # user.public_key = "REVOKED_" + user.public_key 

    db.commit()

    return {
        "status": "success",
        "message": "Appareil déclaré perdu. Fonds restaurés sur le solde online.",
        "refunded_amount": refund_amount,
        "new_online_balance": user.balance_atomic
    }
    
# --- 5. DIFFUSION DE LA LISTE NOIRE (CRL) ---
# Les marchands appellent ça chaque matin ou à chaque sync
@router.get("/security/blacklist")
def get_global_blacklist(db: Session = Depends(database.get_db)):
    # On récupère toutes les clés publiques des comptes marqués "is_blacklisted"
    # (Ce flag a été mis à True par la route /recover-lost-device)
    banned_users = db.query(models.User.public_key)\
        .filter(models.User.is_blacklisted == True)\
        .all()
    
    # On renvoie une liste simple de chaînes de caractères
    return [user.public_key for user in banned_users]