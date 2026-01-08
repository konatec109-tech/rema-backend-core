from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class UserBase(BaseModel):
    phone_number: str

class UserCreate(UserBase):
    password: str # C'est ici que passera le PIN ou le hash
    full_name: Optional[str] = None
    role: str = "user" # On ajoute le rôle par défaut

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    balance: float  # 👈 C'EST ÇA QUI MANQUAIT !
    
    class Config:
        from_attributes = True