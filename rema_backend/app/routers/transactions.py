import nacl.signing
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError 
from app.core.database import get_db

from app.models.transaction import Transaction
from app.models.user import User

# 🔥 CORRECTION IMPORT : On utilise le bon nom défini dans le schéma
from app.schemas.transaction import TransactionBatchRequest

router = APIRouter(prefix="/transactions", tags=["Transactions"])

# 🔥 CORRECTION TYPE : batch est de type TransactionBatchRequest
@router.post("/sync")
def sync_batch_transactions(batch: TransactionBatchRequest, db: Session = Depends(get_db)):
    print(f"📥 Batch de {len(batch.transactions)} txs")
    
    report = {"processed": 0, "failed": 0, "errors": [], "status": "partial_success"}
    
    merchant = db.query(User).filter(User.public_key == batch.merchant_pk).first()
    if not merchant:
        raise HTTPException(status_code=404, detail="Marchand introuvable")

    for tx in batch.transactions:
        try:
            # Idempotence
            exists = db.query(Transaction).filter(Transaction.transaction_uuid == tx.uuid).first()
            if exists: continue 

            # Anti-Rejeu
            nonce_exists = db.query(Transaction).filter(Transaction.nonce == tx.nonce).first()
            if nonce_exists: continue

            # Accounting
            sender = db.query(User).filter(User.public_key == tx.sender_pk).first()
            if sender: sender.offline_reserved_atomic -= tx.amount
            merchant.balance_atomic += tx.amount

            # Création
            new_tx = Transaction(
                transaction_uuid=tx.uuid,
                protocol_ver=tx.protocol_ver,
                sender_pubk_hash=tx.sender_pk, 
                receiver_pubk_hash=batch.merchant_pk,
                amount_atomic=tx.amount,       
                currency_code=tx.currency,
                nonce=tx.nonce,
                signature=tx.signature,
                timestamp=tx.timestamp,
                status="COMPLETED",
                is_offline_synced=True,
                metadata_blob=tx.metadata 
            )

            try:
                db.add(new_tx)
                db.commit() 
                report["processed"] += 1
            except IntegrityError:
                db.rollback() 
                continue 

        except Exception as e:
            report["failed"] += 1
            report["errors"].append({"uuid": tx.uuid, "msg": str(e)})

    report["status"] = "success" if report["failed"] == 0 else "partial_success"
    return report