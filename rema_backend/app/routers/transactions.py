import nacl.signing
import nacl.exceptions
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app import models
from pydantic import BaseModel
from typing import List

# IMPORTANT : Le prefix définit l'URL. Ici -> /transactions
router = APIRouter(prefix="/transactions", tags=["Transactions"])

# --- MODÈLES (DOIVENT MATCHER DART EXACTEMENT) ---
class SingleTransaction(BaseModel):
    id: str             
    sender_pk: str      
    amount: float       
    timestamp: int      
    phone: str          
    target_name: str    
    signature: str      

class BatchSyncRequest(BaseModel):
    merchant_pk: str        
    transactions: List[SingleTransaction]

# --- VERIFICATION CRYPTO ---
def verify_ed25519_signature(tx: SingleTransaction):
    try:
        # Reconstitution exacte du message signé en Dart
        # "$myPk|${amount.toInt()}|$timestamp|$myPhone|$targetName"
        amount_int = int(tx.amount) 
        original_message = f"{tx.sender_pk}|{amount_int}|{tx.timestamp}|{tx.phone}|{tx.target_name}"
        
        # Conversion Hex -> Bytes (C'est ici que ça plante si on envoie BANK_SYSTEM)
        pub_key_bytes = bytes.fromhex(tx.sender_pk)
        
        verify_key = nacl.signing.VerifyKey(pub_key_bytes)
        verify_key.verify(original_message.encode('utf-8'), bytes.fromhex(tx.signature))
        return True
    except Exception as e:
        print(f"❌ SIGNATURE INVALIDE ({tx.id}): {e}")
        return False

# --- ROUTE SYNC ---
@router.post("/sync")
def sync_batch_transactions(batch: BatchSyncRequest, db: Session = Depends(get_db)):
    print(f"📥 Reçu Batch Sync de {batch.merchant_pk} : {len(batch.transactions)} txs")
    
    report = {"processed": 0, "failed": 0, "new_balance": 0.0, "errors": []}
    
    # 1. Identifier le Marchand (Celui qui reçoit l'argent dans le cloud)
    merchant = db.query(models.User).filter(models.User.public_key == batch.merchant_pk).first()
    if not merchant:
        raise HTTPException(status_code=404, detail="Marchand introuvable (PK inconnue)")

    for tx in batch.transactions:
        # A. Anti-Doublon
        exists = db.query(models.Transaction).filter(models.Transaction.transaction_uuid == tx.id).first()
        if exists:
            print(f"⏩ Déjà traitée: {tx.id}")
            continue

        # B. Vérification Crypto
        if not verify_ed25519_signature(tx):
            report["failed"] += 1
            report["errors"].append({"id": tx.id, "msg": "Signature invalide"})
            continue

        # C. Transfert Comptable
        # On cherche l'envoyeur pour débiter son "Compte Offline" (le Shadow Balance)
        sender = db.query(models.User).filter(models.User.public_key == tx.sender_pk).first()
        
        if sender:
            # On met à jour son état offline théorique
            sender.offline_reserved_amount -= tx.amount
        
        # On crédite le marchand RÉELLEMENT sur son compte courant
        merchant.balance += tx.amount

        # D. Enregistrement en base
        new_tx = models.Transaction(
            transaction_uuid=tx.id,
            sender_pk=tx.sender_pk,
            receiver_pk=batch.merchant_pk,
            amount=tx.amount,
            type="PAYMENT_OFFLINE_SYNC", # Type clair pour les stats
            timestamp=tx.timestamp,
            status="COMPLETED",
            signature=tx.signature,
            is_offline_synced=True
        )
        db.add(new_tx)
        report["processed"] += 1
        
    db.commit()
    db.refresh(merchant)
    
    report["new_balance"] = merchant.balance
    return report