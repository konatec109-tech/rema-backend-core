from sqlalchemy import Column, Integer, String, Float, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, unique=True, index=True)
    full_name = Column(String)
    pin_hash = Column(String)
    public_key = Column(String, unique=True, index=True)
    role = Column(String, default="user")
    
    # Soldes
    balance = Column(Float, default=50000.0) # Le fameux bonus
    offline_reserved_amount = Column(Float, default=0.0)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())