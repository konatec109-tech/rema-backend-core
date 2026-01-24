from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

# --- INPUT (Ce que le mobile envoie) ---
class UserCreate(BaseModel):
    # ATTENTION : C'est bien "phone_number" ici
    phone_number: str = Field(..., description="Format international")
    pin_hash: str
    full_name: str
    role: str = "user"
    public_key: str 
    device_hardware_id: str

# --- OUTPUT (Ce que le mobile reçoit) ---
class UserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: str
    is_active: bool = True
    created_at: datetime
    balance_atomic: int      

    class Config:
        from_attributes = True