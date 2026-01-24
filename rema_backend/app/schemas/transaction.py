from pydantic import BaseModel
from typing import List, Optional

# ✅ SingleTransaction
class SingleTransaction(BaseModel):
    uuid: str           
    protocol_ver: int   
    nonce: str          
    timestamp: int      
    sender_pk: str      
    receiver_pk: str    
    amount: int         
    currency: int       
    signature: str      
    type: str = "OFFLINE_PAYMENT"
    metadata: Optional[str] = "{}" 

# ✅ CORRECTION NOM : TransactionBatchRequest (C'est ce que ton serveur cherche !)
class TransactionBatchRequest(BaseModel):
    merchant_pk: str        
    batch_id: str
    device_id: str
    count: int
    sync_timestamp: str
    transactions: List[SingleTransaction]

# ✅ AJOUT : Ces classes sont souvent requises par d'autres fichiers (oauth2)
class TransactionResponse(BaseModel):
    status: str
    message: str

class SignedPayload(BaseModel):
    payload: str
    signature: str