from sqlalchemy import Column, Integer, String, Boolean, BigInteger, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    # --- IDENTITÉ ---
    id = Column(Integer, primary_key=True, index=True)
    
    # [Doc Section 7.3] KYC Fort (Numéro unique)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    
    # [Doc Section 4.2] Clé Publique (Ancrage de confiance)
    # C'est la seule chose que le serveur connaît. La clé privée est dans l'enclave du téléphone.
    public_key = Column(String, unique=True, index=True, nullable=False)
    
    # Sécurité d'accès (Pin Haché pour l'app)
    pin_hash = Column(String, nullable=False)
    role = Column(String, default="user") # user, merchant, admin

    # --- FINANCE (ATOMICITÉ) ---
    # [Doc Section 8.1] INT OBLIGATOIRE (BigInteger).
    # Exemple : 50000 FCFA stockés comme 50000 (ou 5000000 si centimes).
    # JAMAIS DE FLOAT.
    balance_atomic = Column(BigInteger, default=50000, nullable=False) 
    
    # [Doc Section 5.2] Lock-and-Release
    # Montant "séquestré" pendant une transaction offline en attente de synchro.
    offline_reserved_atomic = Column(BigInteger, default=0, nullable=False)

    # --- SÉCURITÉ & DEVICE BINDING ---
    # [Doc Section 5.1] Liaison Matérielle
    # On lie le compte à un ID physique unique du téléphone (IMEI Hash ou Android ID).
    # Si quelqu'un vole les identifiants mais change de téléphone, ça bloque.
    device_hardware_id = Column(String, index=True, nullable=True)

    # [Doc Section 5.3] Compteur Monotone (State Nonce)
    # Empêche le rejeu. On stocke le dernier nonce utilisé.
    last_nonce_used = Column(String, nullable=True)

    # [Doc Section 7.1] Protocole de Révocation (CRL)
    # Si True, le compte est gelé (téléphone volé déclaré).
    is_blacklisted = Column(Boolean, default=False)
    
    # Date de création pour audit LCB-FT
    created_at = Column(DateTime(timezone=True), server_default=func.now())