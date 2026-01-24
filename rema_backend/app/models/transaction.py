from sqlalchemy import Column, Integer, String, BigInteger, Boolean, LargeBinary
from sqlalchemy.sql import func
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    # --- IDENTIFIANTS ET MÉTA-DONNÉES (HEADER) ---
    id = Column(Integer, primary_key=True, index=True)
    
    # [Doc Section 8.1] Protocol_Ver (1 octet)
    protocol_ver = Column(Integer, default=1, nullable=False)

    # [Doc Section 4.3] UUID v4 (16 octets)
    transaction_uuid = Column(String(36), unique=True, index=True, nullable=False)

    # --- CRYPTOGRAPHIE & IDENTITÉ (BODY) ---
    sender_pubk_hash = Column(String, index=True, nullable=False)
    receiver_pubk_hash = Column(String, index=True, nullable=False)

    # [Doc Section 8.1] Amount_Atomic (8 octets - uint64)
    # Stocké en BigInteger.
    amount_atomic = Column(BigInteger, nullable=False)
    
    # [Doc Section 8.1] Currency Code (2 octets - ISO 4217)
    currency_code = Column(Integer, default=952, nullable=False)

    # [Doc Section 4.3 & 8.1] Nonce Cryptographique (24 octets)
    nonce = Column(String, unique=True, nullable=False)

    # --- SÉCURITÉ & PREUVE (FOOTER) ---
    # [Doc Section 4.1 & 8.1] Ed25519 Signature (64 octets)
    signature = Column(String, nullable=False)

    # [Doc Section 8.1] Integrity Checksum (CRC32)
    integrity_checksum = Column(String, nullable=True)

    # --- ÉTAT SYSTÈME (INTERNE) ---
    timestamp = Column(BigInteger, default=func.now())
    
    status = Column(String, default="COMPLETED", index=True)

    is_offline_synced = Column(Boolean, default=False)
    
    is_flagged_suspicious = Column(Boolean, default=False)

    # 🔥 [NOUVEAU] LA COLONNE B2B POUR VISA / FEDAPAY / NSIA
    # C'est ici qu'on stockera leurs "Order IDs" ou références clients
    # On utilise un String qui contiendra du JSON (ex: '{"order_id": "123"}')
    metadata_blob = Column(String, nullable=True, default="{}")