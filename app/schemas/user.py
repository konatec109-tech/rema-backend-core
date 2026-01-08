from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- CE QUE L'APPLI ENVOIE (ENTRÉE) ---
class UserCreate(BaseModel):
    phone: str          # Flutter envoie "phone"
    pin_hash: str       # Flutter envoie "pin_hash"
    full_name: Optional[str] = None
    role: str = "user"

# --- CE QUE LE SERVEUR RÉPOND (SORTIE) ---
class UserResponse(BaseModel):
    id: int
    phone_number: str   # En base de données, ça s'appelle phone_number
    full_name: Optional[str]
    is_active: bool
    created_at: datetime
    balance: float      # Les 50 000 F !
    
    class Config:
        from_attributes = True