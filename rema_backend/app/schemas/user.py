from pydantic import BaseModel, Field
from datetime import datetime

class UserCreate(BaseModel):
    phone_number: str = Field(..., description="Format international sans +")
    pin_hash: str
    full_name: str
    role: str = "user"
    public_key: str 
    device_hardware_id: str

class UserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: str
    is_active: bool = True
    created_at: datetime
    balance_atomic: int      
    offline_reserved_atomic: int 

    class Config:
        from_attributes = True

# 🔥 CORRECTION CRITIQUE POUR LA RECHARGE
# Flutter envoie: { "amount": X, "phone": Y }
# Donc ici, on doit avoir 'phone', PAS 'phone_number'
class RechargeRequest(BaseModel):
    amount: int
    phone: str

class RecoverRequest(BaseModel):
    phone: str
    pin: str