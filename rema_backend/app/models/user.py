from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    
    # Identifiants
    phone_number = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=False)
    pin_hash = Column(String, nullable=False)
    public_key = Column(String, nullable=False)
    role = Column(String, default="USER")
    
    # --- LES AJOUTS QUI CORRIGENT L'ERREUR ---
    device_hardware_id = Column(String, nullable=True)
    balance = Column(Float, default=50000.0, nullable=False)
    offline_reserved_amount = Column(Float, default=0.0, nullable=False)
    # -----------------------------------------

    created_at = Column(DateTime(timezone=True), server_default=func.now())