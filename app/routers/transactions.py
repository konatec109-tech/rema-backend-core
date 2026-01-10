import nacl.signing
import nacl.exceptions
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app import models
from app.schemas.transaction import TransactionBatchRequest 

router = APIRouter(
    prefix="/transactions",
    tags=["Transactions"]
)

def verify_ed25519_signature(tx_data):
    try:
        original_message = f"{tx_data.id}|{tx_data.sender_pk}|{tx_data.amount}|{tx_data.timestamp}"
        verify_key = nacl.signing.VerifyKey(bytes.fromhex(tx_data.sender_pk))
        verify_key.verify(original_message.encode('utf-8'), bytes.fromhex(tx_data.signature))
        return True
    except Exception as e:
        print(f"❌ FRAUDE: {e}")
        return False

@router.post("/sync/batch")
def sync_batch_transactions(batch: TransactionBatchRequest, db: Session = Depends(get_db)):
    report = {"processed": 0, "failed": 0, "errors": []}
    
    # Identifier le Marchand
    merchant = db.query(models.User).filter(models.User.public_key == batch.device_id).first()
    
    for tx in batch.transactions:
        # A. Anti-Doublon
        exists = db.query(models.Transaction).filter(models.Transaction.transaction_uuid == tx.id).first()
        if exists:
            continue

        # B. Vérification Crypto
        if not verify_ed25519_signature(tx):
            report["failed"] += 1
            report["errors"].append({"id": tx.id, "msg": "Signature Invalide"})
            continue

        # C. Mouvements d'argent
        sender = db.query(models.User).filter(models.User.public_key == tx.sender_pk).first()
        
        if sender:
            deduction = min(sender.offline_reserved_amount, tx.amount)
            sender.offline_reserved_amount -= deduction
            sender.balance -= tx.amount
        
        if merchant:
            merchant.balance += tx.amount

        # D. Historique (CORRIGÉ AVEC NOUVELLES COLONNES)
        new_tx = models.Transaction(
            transaction_uuid=tx.id,
            sender_pk=tx.sender_pk,
            receiver_pk=tx.receiver_pk if tx.receiver_pk else batch.device_id,
            amount=tx.amount,
            
            # ✅ On remplit bien les champs d'audit maintenant
            type="PAYMENT_OFFLINE",
            timestamp=tx.timestamp, 
            status="COMPLETED",
            signature=tx.signature,
            is_offline_synced=True
        )
        db.add(new_tx)
        report["processed"] += 1
        
    db.commit()
    
    # E. Renvoi du solde pour mise à jour Flutter
    if merchant:
        db.refresh(merchant)
        report["new_online_balance"] = merchant.balance - merchant.offline_reserved_amount

    return report