from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- ENTRÉE (Ce que Flutter envoie) ---
class UserCreate(BaseModel):
    phone: str          # ✅ Flutter envoie "phone"
    pin_hash: str       # ✅ Flutter envoie "pin_hash"
    full_name: Optional[str] = None
    role: str = "user"

# --- SORTIE (Ce que Flutter reçoit) ---
class UserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: Optional[str]
    is_active: bool
    created_at: datetime
    
    # 👇 INDISPENSABLE POUR L'AFFICHAGE
    balance: float      
    
    class Config:
        from_attributes = True