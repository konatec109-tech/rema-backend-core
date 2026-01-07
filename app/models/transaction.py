from sqlalchemy import Column, Integer, String, DateTime, BigInteger
from sqlalchemy.sql import func
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    # 1. IDENTIFIANTS TECHNIQUES
    id = Column(Integer, primary_key=True, index=True) # ID interne de la base (1, 2, 3...)
    
    # 2. LE NONCE (CRITIQUE POUR L'ANTI-REPLAY)
    # C'est l'UUID généré par le téléphone. 
    # On le met en "unique=True" : La base de données REJETTERA physiquement 
    # toute tentative d'insérer deux fois la même transaction. C'est le garde-fou ultime.
    transaction_uuid = Column(String, unique=True, index=True, nullable=False)

    # 3. LES ACTEURS (IDENTITÉS CRYPTO)
    # On ne stocke pas de numéros de téléphone ici, mais les Clés Publiques (Hex).
    sender_pk = Column(String, nullable=False, index=True)
    receiver_pk = Column(String, nullable=False, index=True)

    # 4. L'ARGENT
    # Toujours en Entier (Integer). Pas de virgule flottante.
    amount = Column(Integer, nullable=False)

    # 5. LA PREUVE MATHÉMATIQUE
    # On stocke la signature Ed25519. 
    # En cas d'audit ou de litige ("Je n'ai pas payé !"), on ressort cette signature 
    # et on prouve mathématiquement que c'est faux.
    signature = Column(String, nullable=False)

    # 6. MÉTADONNÉES DE TEMPS
    # created_at_mobile : L'heure déclarée par le téléphone (Timestamp Unix)
    created_at_mobile = Column(BigInteger, nullable=False)
    # synced_at : L'heure réelle où le serveur l'a reçu (Heure Serveur)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())

    # 7. ÉTAT DE LA TRANSACTION
    # STATUS: "PENDING_BANK", "COMPLETED", "FAILED"
    status = Column(String, default="PENDING_BANK")
    
    # Message d'erreur éventuel de la banque (ex: "Solde insuffisant")
    bank_response_message = Column(String, nullable=True)