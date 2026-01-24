from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

# ==============================================================================
# 1. GESTION DES UTILISATEURS (USER)
# ==============================================================================

# Ce que le mobile envoie pour s'inscrire
class UserCreate(BaseModel):
    phone_number: str = Field(..., description="Format international sans +")
    pin_hash: str
    full_name: str
    role: str = "user"
    public_key: str 
    device_hardware_id: str

# Ce que le serveur renvoie (Login / Profil)
class UserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: str
    is_active: bool = True
    created_at: datetime
    
    # 🔥 LES SOLDES
    balance_atomic: int      
    offline_reserved_atomic: int 

    class Config:
        from_attributes = True

# ==============================================================================
# 2. OPÉRATIONS BANCAIRES (ACTIONS USER)
# ==============================================================================

# Pour recharger le téléphone (Cash-In)
class RechargeRequest(BaseModel):
    amount: int  # Montant en centimes (Atomic)
    phone: str   # Identifiant du compte à créditer

# Pour récupérer un compte perdu
class RecoverRequest(BaseModel):
    phone: str
    pin: str