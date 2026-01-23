from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

# --- 1. L'OBJET TRANSACTION (Conforme Doc Section 8.1) ---
class TransactionItem(BaseModel):
    # [Doc] Identifiants & Version
    uuid: str           # Tx_UUID (16 octets)
    protocol_ver: int = 1 # Protocol_Ver (1 octet)
    
    # [Doc] Sécurité & Anti-Rejeu
    nonce: str          # Nonce_Cryptographique (24 octets) - CRUCIAL
    timestamp: int      # Timestamp_UTC (8 octets)
    
    # [Doc] Identité
    sender_pk: str      # Clé publique pour vérification
    receiver_pk: Optional[str] = "" 
    
    # [Doc] Valeur (Atomicité)
    # 🔥 CRITIQUE : INT OBLIGATOIRE (Pas de Float). 
    # 5000 FCFA = 5000. Si on gère les centimes, 500000.
    amount: int         
    currency: int = 952 # Code ISO 4217 (XOF)
    
    # [Doc] Preuve
    signature: str      # Ed25519_Signature (64 octets)
    checksum: Optional[str] = None # Integrity_Checksum

    type: str = "OFFLINE_PAYMENT"

# --- 2. LA RÉPONSE API ---
class TransactionResponse(BaseModel):
    id: int
    transaction_uuid: str
    sender_pk: str
    receiver_pk: str
    amount: int         # <-- INT ICI AUSSI
    status: str
    synced_at: Optional[datetime]
    
    class Config:
        from_attributes = True 

# --- 3. PAYLOAD SIGNÉ ---
class SignedPayload(BaseModel):
    payload: str
    signature: str

# --- 4. LE PAQUET BATCH (Pour la synchro) ---
class TransactionBatchRequest(BaseModel):
    batch_id: str
    device_id: str
    count: int
    sync_timestamp: str
    transactions: List[TransactionItem]