from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- ENTRÉE (Ce que Flutter envoie) ---
class UserCreate(BaseModel):
    phone: str
    pin_hash: str
    full_name: Optional[str] = None
    role: str = "user"
    public_key: str  # <--- AJOUT CRUCIAL : On exige la clé du téléphone

# --- SORTIE (Ce que Flutter reçoit) ---
class UserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: Optional[str]
    is_active: bool
    created_at: datetime
    
    # INDISPENSABLE POUR L'AFFICHAGE
    balance: float      
    
    class Config:
        from_attributes = True