import nacl.signing
import nacl.exceptions
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app import models
# On importe le schema qu'on vient de créer
from app.schemas.transaction import TransactionBatchRequest 

router = APIRouter(
    prefix="/transactions",
    tags=["Transactions"]
)

# --- LA BONNE LOGIQUE DE VÉRIFICATION (CORRIGÉE) ---
def verify_ed25519_signature(tx_data):
    try:
        # CRITIQUE : On reconstruit la chaîne EXACTEMENT comme sur le mobile (transaction.dart)
        # Format : "$id|$senderPk|$amount|$timestamp"
        original_message = f"{tx_data.id}|{tx_data.sender_pk}|{tx_data.amount}|{tx_data.timestamp}"
        
        # Encodage en bytes
        message_bytes = original_message.encode('utf-8')
        
        # Clé de vérification (La clé publique de l'émetteur)
        verify_key = nacl.signing.VerifyKey(bytes.fromhex(tx_data.sender_pk))
        
        # Le verdict mathématique
        verify_key.verify(message_bytes, bytes.fromhex(tx_data.signature))
        
        return True # Signature authentique
    except (nacl.exceptions.BadSignatureError, ValueError) as e:
        print(f"❌ FRAUDE DÉTECTÉE : {e}")
        return False

# --- L'AUTOROUTE DE CLEARING ---
@router.post("/sync/batch")
def sync_batch_transactions(batch: TransactionBatchRequest, db: Session = Depends(get_db)):
    report = {"processed": 0, "failed": 0, "errors": []}
    
    # ✅ CORRECTION ICI : On utilise 'batch.transactions' au lieu de 'batch.payload'
    # C'est le nom standard défini dans Pydantic.
    for tx in batch.transactions:
        
        # 1. Anti-Doublon (Idempotency)
        exists = db.query(models.Transaction).filter(models.Transaction.transaction_uuid == tx.id).first()
        if exists:
            continue

        # 2. Vérification Crypto (La Boîte Noire)
        if not verify_ed25519_signature(tx):
            report["failed"] += 1
            report["errors"].append({"id": tx.id, "msg": "Signature Invalide"})
            continue

        # 3. Enregistrement
        new_tx = models.Transaction(
            transaction_uuid=tx.id,
            sender_pk=tx.sender_pk,
            receiver_pk=tx.receiver_pk,
            amount=tx.amount,
            status="COMPLETED",
            signature=tx.signature
        )
        db.add(new_tx)
        report["processed"] += 1
        
    db.commit()
    return report