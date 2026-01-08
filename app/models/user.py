from sqlalchemy import Boolean, Column, Integer, String, Float, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    # 👇 ON REPART À ZÉRO AVEC UNE TABLE PROPRE
    __tablename__ = "users_industrial"

    id = Column(Integer, primary_key=True, index=True)
    
    # Identité
    phone_number = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    
    # 💰 L'ARGENT (CRITIQUE POUR GOZEM)
    balance = Column(Float, default=50000.0)
    offline_reserved_amount = Column(Float, default=0.0)
    
    role = Column(String, default="user")
    created_at = Column(DateTime(timezone=True), server_default=func.now())