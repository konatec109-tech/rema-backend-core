from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# On définit la base : C'est le TELEPHONE qui compte, pas l'email.
class UserBase(BaseModel):
    phone_number: str

class UserCreate(UserBase):
    password: str
    full_name: Optional[str] = None # Utile pour l'affichage "Bonjour Moussa"

class UserResponse(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    
    class Config:
        from_attributes = True