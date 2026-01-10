from sqlalchemy import Column, Integer, String, Float, Boolean, BigInteger, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    transaction_uuid = Column(String, unique=True, index=True)
    
    sender_pk = Column(String, index=True)
    receiver_pk = Column(String, index=True)
    amount = Column(Float)
    
    # ✅ LES NOUVELLES COLONNES (INDISPENSABLES POUR L'AUDIT)
    type = Column(String, default="PAYMENT") # "RECHARGE_OFFLINE", "PAYMENT_OFFLINE"
    timestamp = Column(BigInteger)           # Stocke l'heure exacte (millisecondes)
    status = Column(String, default="COMPLETED")
    signature = Column(String, nullable=True) 
    is_offline_synced = Column(Boolean, default=False)