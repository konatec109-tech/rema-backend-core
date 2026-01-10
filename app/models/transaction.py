# app/models/transaction.py
from sqlalchemy import Column, Integer, String, Float, Boolean, BigInteger
from app.core.database import Base

class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True, index=True)
    transaction_uuid = Column(String, unique=True, index=True)
    
    sender_pk = Column(String, index=True)
    receiver_pk = Column(String, index=True)
    amount = Column(Float)
    
    # Colonnes Audit
    type = Column(String, default="PAYMENT") 
    timestamp = Column(BigInteger)           
    status = Column(String, default="COMPLETED")
    signature = Column(String, nullable=True) 
    is_offline_synced = Column(Boolean, default=False)