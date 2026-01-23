from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

# --- 1. ENTRÉE : CRÉATION DE COMPTE (Ce que le mobile envoie) ---
class UserCreate(BaseModel):
    phone_number: str = Field(..., description="Format international unique (ex: +225...)")
    pin_hash: str
    full_name: str
    role: str = "user"
    
    # [Doc Section 4.2] Clé Publique (Ancrage de confiance)
    # Le mobile DOIT envoyer sa clé publique lors de l'inscription.
    public_key: str 
    
    # [Doc Section 5.1] Device Binding
    # On lie le compte à l'empreinte matérielle du téléphone.
    device_hardware_id: str

# --- 2. SORTIE : AFFICHAGE COMPTE (Ce que le mobile reçoit) ---
class UserResponse(BaseModel):
    id: int
    phone_number: str
    full_name: str
    is_active: bool = True
    created_at: datetime
    
    # [Doc Section 8.1] SOLDE EN ENTIER (Atomic)
    # Le mobile recevra 50000 (pour 500 FCFA si centimes) ou 500.
    # C'est le mobile qui décidera d'ajouter la virgule visuelle, pas le serveur.
    balance_atomic: int      

    class Config:
        from_attributes = True # Remplace 'orm_mode' dans Pydantic v2