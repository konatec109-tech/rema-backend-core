from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

# --- 1. L'OBJET TRANSACTION (Tel qu'envoyé par le mobile) ---
class TransactionItem(BaseModel):
    id: str             # C'est l'UUID (nonce)
    sender_pk: str
    receiver_pk: Optional[str] = "" # Optionnel pour accepter le Hit & Run
    amount: float
    timestamp: int
    type: str = "OFFLINE_PAYMENT"
    signature: str

# --- 2. LA RÉPONSE API (Celle qui manquait et causait l'erreur) ---
# Utilisée quand l'API renvoie une transaction à l'écran
class TransactionResponse(BaseModel):
    id: int
    transaction_uuid: str
    sender_pk: str
    receiver_pk: str
    amount: float
    status: str
    synced_at: Optional[datetime]
    
    class Config:
        from_attributes = True # Pour lire les objets SQLAlchemy

# --- 3. PAYLOAD SIGNÉ (Pour la rétro-compatibilité imports) ---
class SignedPayload(BaseModel):
    payload: str
    signature: str

# --- 4. LE PAQUET BATCH (Pour la synchro) ---
class TransactionBatchRequest(BaseModel):
    batch_id: str
    device_id: str
    count: int
    sync_timestamp: str
    
    # 🔥 CRITIQUE : On renomme 'payload' en 'transactions' 
    # pour coller exactement à ton code Dart (rema_sync.dart)
    transactions: List[TransactionItem]