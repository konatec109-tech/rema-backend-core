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
    
    # 1. Identifier le Marchand (Celui qui synchronise)
    # Pour l'instant, on suppose que le device_id est la Clé Publique du marchand
    merchant = db.query(models.User).filter(models.User.public_key == batch.device_id).first()
    
    # Si on ne trouve pas par clé publique, on essaie de trouver un fallback (optionnel)
    # Note: Dans un vrai système, il faudrait que le marchand soit authentifié via Token.
    
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

        # C. MOUVEMENT D'ARGENT (Le Cœur du Système)
        # Trouver le payeur via sa clé publique
        sender = db.query(models.User).filter(models.User.public_key == tx.sender_pk).first()
        
        if sender:
            # 1. On vide sa réserve (l'argent bloqué est consommé)
            # On vérifie qu'il ne passe pas en négatif (sécurité)
            deduction = min(sender.offline_reserved_amount, tx.amount)
            sender.offline_reserved_amount -= deduction
            
            # 2. On baisse son solde global (L'argent est parti pour de bon)
            sender.balance -= tx.amount
        
        # Créditer le Marchand (si identifié)
        if merchant:
            merchant.balance += tx.amount

        # D. Historique
        new_tx = models.Transaction(
            transaction_uuid=tx.id,
            sender_pk=tx.sender_pk,
            receiver_pk=tx.receiver_pk if tx.receiver_pk else batch.device_id,
            amount=tx.amount,
            status="COMPLETED",
            signature=tx.signature
        )
        db.add(new_tx)
        report["processed"] += 1
        
    db.commit()
    return report