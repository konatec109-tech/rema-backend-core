from sqlalchemy import Boolean, Column, Integer, String, Float, DateTime
from sqlalchemy.sql import func
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    
    # --- IDENTITÉ ---
    phone_number = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    
    # --- GESTION FINANCIÈRE (AJOUT ARCHITECTE) ---
    
    # 1. Le Solde TOTAL (La Vérité)
    # C'est l'argent total que possède l'utilisateur. 
    # Exemple : 10.000 FCFA.
    balance = Column(Float, default=0.0)
    
    # 2. Le Verrouillage Offline (La Sécurité Paranoïaque)
    # C'est la partie du solde qui est "sortie" dans un téléphone.
    # Si balance = 10.000 et offline_reserved_amount = 5.000,
    # alors il ne reste que 5.000 utilisables en ligne.
    offline_reserved_amount = Column(Float, default=0.0)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())