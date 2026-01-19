import nacl.signing
import nacl.exceptions
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app import models
from pydantic import BaseModel
from typing import List

router = APIRouter(prefix="/transactions", tags=["Transactions"])

# --- SCHEMAS (Pour valider ce que le mobile envoie) ---
class SingleTransaction(BaseModel):
    id: str             # UUID
    sender_pk: str      # Clé publique expéditeur
    amount: float       # Montant
    timestamp: int      # Timestamp
    phone: str          # Téléphone expéditeur (AJOUTÉ)
    target_name: str    # Nom du marchand (AJOUTÉ)
    signature: str      # La preuve Hex

class BatchSyncRequest(BaseModel):
    merchant_pk: str        # Clé publique du marchand qui sync
    transactions: List[SingleTransaction]

# --- VÉRIFICATION CRYPTO ---
def verify_ed25519_signature(tx: SingleTransaction):
    try:
        # ⚠️ CRUCIAL : Doit être IDENTIQUE byte-pour-byte au string Dart
        # Dart: "$myPk|${amount.toInt()}|$timestamp|$myPhone|$targetName"
        
        # On force le montant en entier comme le fait le Dart (.toInt())
        amount_int = int(tx.amount) 
        
        original_message = f"{tx.sender_pk}|{amount_int}|{tx.timestamp}|{tx.phone}|{tx.target_name}"
        
        print(f"🔍 Checking: {original_message}") # Debug
        
        verify_key = nacl.signing.VerifyKey(bytes.fromhex(tx.sender_pk))
        verify_key.verify(original_message.encode('utf-8'), bytes.fromhex(tx.signature))
        return True
    except Exception as e:
        print(f"❌ FRAUDE SIGNATURE: {e}")
        return False

# --- ROUTE DE SYNCHRONISATION ---
@router.post("/sync")
def sync_batch_transactions(batch: BatchSyncRequest, db: Session = Depends(get_db)):
    report = {"processed": 0, "failed": 0, "new_balance": 0.0, "errors": []}
    
    # 1. Identifier le Marchand (Celui qui synchronise)
    merchant = db.query(models.User).filter(models.User.public_key == batch.merchant_pk).first()
    if not merchant:
        raise HTTPException(status_code=404, detail="Marchand introuvable")

    for tx in batch.transactions:
        # A. Anti-Doublon (Si déjà traité, on passe)
        exists = db.query(models.Transaction).filter(models.Transaction.transaction_uuid == tx.id).first()
        if exists:
            continue

        # B. Vérification Crypto (Le Juge de Paix)
        if not verify_ed25519_signature(tx):
            report["failed"] += 1
            report["errors"].append({"id": tx.id, "msg": "Signature Falsifiée"})
            continue

        # C. Exécution du transfert (Settlement)
        # On trouve le client (Sender)
        sender = db.query(models.User).filter(models.User.public_key == tx.sender_pk).first()
        
        if sender:
            # On vide son coffre virtuel (Offline Vault)
            # On prend le min pour ne pas aller en négatif s'il a triché ailleurs
            deduction = min(sender.offline_reserved_amount, tx.amount)
            sender.offline_reserved_amount -= deduction
            
            # On met à jour son solde global (optionnel selon ta logique comptable)
            # sender.balance -= tx.amount 
        
        # On crédite le Marchand (Vrai argent disponible)
        merchant.balance += tx.amount

        # D. Archivage
        new_tx = models.Transaction(
            transaction_uuid=tx.id,
            sender_pk=tx.sender_pk,
            receiver_pk=batch.merchant_pk,
            amount=tx.amount,
            type="PAYMENT_OFFLINE_SYNC",
            timestamp=tx.timestamp,
            status="COMPLETED",
            signature=tx.signature,
            is_offline_synced=True
        )
        db.add(new_tx)
        report["processed"] += 1
        
    db.commit()
    db.refresh(merchant)
    
    # Retourne le nouveau solde réel du marchand
    report["new_balance"] = merchant.balance
    return report