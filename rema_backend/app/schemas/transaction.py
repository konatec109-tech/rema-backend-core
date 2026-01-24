from pydantic import BaseModel
from typing import List, Optional

# ==============================================================================
# 3. TRANSACTIONS & SYNCHRONISATION (CORE)
# ==============================================================================

# Une transaction unique (Doit matcher le format Flutter)
class SingleTransaction(BaseModel):
    uuid: str           # UUID v4
    protocol_ver: int   # Versioning
    nonce: str          # Anti-Rejeu
    timestamp: int      # Timestamp UTC
    sender_pk: str      # Clé publique émetteur
    receiver_pk: str    # Clé publique du marchand
    amount: int         # 🔥 INT STRICT (Atomic Unit)
    currency: int       # 952 (XOF)
    signature: str      # Preuve Ed25519 (Hex string)
    type: str = "OFFLINE_PAYMENT"
    
    # 🔥 B2B : Le champ pour Visa / FedaPay (OBLIGATOIRE)
    metadata: Optional[str] = "{}" 

# Le carton de transactions (Batch)
class BatchSyncRequest(BaseModel):
    merchant_pk: str        
    batch_id: str
    device_id: str
    count: int
    sync_timestamp: str
    transactions: List[SingleTransaction]