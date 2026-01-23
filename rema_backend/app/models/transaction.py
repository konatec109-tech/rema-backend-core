from sqlalchemy import Column, Integer, String, BigInteger, Boolean, LargeBinary
from sqlalchemy.sql import func
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    # --- IDENTIFIANTS ET MÉTA-DONNÉES (HEADER) ---
    id = Column(Integer, primary_key=True, index=True)
    
    # [Doc Section 8.1] Protocol_Ver (1 octet)
    # Permet de gérer les futures mises à jour du SDK sans casser les vieux téléphones.
    protocol_ver = Column(Integer, default=1, nullable=False)

    # [Doc Section 4.3] UUID v4 (16 octets)
    # Identifiant unique universel pour l'idempotence.
    transaction_uuid = Column(String(36), unique=True, index=True, nullable=False)

    # --- CRYPTOGRAPHIE & IDENTITÉ (BODY) ---
    # [Doc Section 8.1] Sender/Receiver PubK Hash (32 octets)
    # On ne stocke pas la clé publique entière, mais son empreinte (Hash) pour la confidentialité.
    sender_pubk_hash = Column(String, index=True, nullable=False)
    receiver_pubk_hash = Column(String, index=True, nullable=False)

    # [Doc Section 8.1] Amount_Atomic (8 octets - uint64)
    # ATTENTION : Stocké en BigInteger (Centimes). 
    # Exemple : Pour 5000 FCFA, on stocke 500000. JAMAIS DE FLOAT.
    amount_atomic = Column(BigInteger, nullable=False)
    
    # [Doc Section 8.1] Currency Code (2 octets - ISO 4217)
    # Ex: 952 pour XOF. Important pour le futur Cross-Border.
    currency_code = Column(Integer, default=952, nullable=False)

    # [Doc Section 4.3 & 8.1] Nonce Cryptographique (24 octets)
    # CRUCIAL : Empêche le "Replay Attack". 
    # C'est ce nombre aléatoire qui rend la signature unique même pour le même montant.
    nonce = Column(String, unique=True, nullable=False)

    # --- SÉCURITÉ & PREUVE (FOOTER) ---
    # [Doc Section 4.1 & 8.1] Ed25519 Signature (64 octets)
    # La preuve mathématique irréfutable (Non-répudiation).
    signature = Column(String, nullable=False)

    # [Doc Section 8.1] Integrity Checksum (CRC32)
    # Pour vérification rapide de l'intégrité avant le check crypto lourd.
    integrity_checksum = Column(String, nullable=True)

    # --- ÉTAT SYSTÈME (INTERNE) ---
    # Timestamp UTC (Horodatage précis à la milliseconde)
    timestamp = Column(BigInteger, default=func.now())
    
    # Statut de la transaction (PENDING, COMPLETED, FAILED, CLAWBACK)
    status = Column(String, default="COMPLETED", index=True)

    # [Doc Section 6.1] Indicateur de synchronisation différée
    # True = Donnée remontée au serveur central / False = Encore en tampon local
    is_offline_synced = Column(Boolean, default=False)
    
    # [Doc Section 7.1] Flag pour audit forensique (ex: terminal volé)
    is_flagged_suspicious = Column(Boolean, default=False)