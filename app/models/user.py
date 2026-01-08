from sqlalchemy import Boolean, Column, Integer, String, Float, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users v2"

    id = Column(Integer, primary_key=True, index=True)
    
    # --- IDENTITÉ ---
    phone_number = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    
    # --- GESTION FINANCIÈRE ---
    # 👇 LE CHANGEMENT EST ICI : On met 50000.0 par défaut !
    balance = Column(Float, default=50000.0)
    
    # Le Verrouillage Offline
    offline_reserved_amount = Column(Float, default=0.0)
    
    role = Column(String, default="user")
    created_at = Column(DateTime(timezone=True), server_default=func.now())