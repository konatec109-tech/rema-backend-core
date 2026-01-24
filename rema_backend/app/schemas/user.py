from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- INPUT : Ce que l'App envoie pour s'inscrire ---
class UserCreate(BaseModel):
    phone_number: str 
    full_name: str
    pin_hash: str
    public_key: str
    # Optionnel pour éviter le crash si l'app ne l'envoie pas
    device_hardware_id: Optional[str] = "unknown_device" 
    role: str = "USER"

# --- OUTPUT : Ce que le serveur répond ---
class UserOut(BaseModel):
    id: int
    phone_number: str
    full_name: str
    balance: float
    created_at: datetime

    class Config:
        from_attributes = True

# --- INPUT : Login ---
class UserLogin(BaseModel):
    phone_number: str
    pin: str