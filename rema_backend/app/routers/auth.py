from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm
from app.core import database
# On suppose que ton fichier oauth2.py est à la racine de app/
from app import oauth2 

# 🔥 IMPORTS CORRIGÉS (Nouvelle Architecture)
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])

# --- INSCRIPTION (SIGNUP) ---
@router.post('/signup', status_code=status.HTTP_201_CREATED, response_model=UserResponse)
def signup(user_in: UserCreate, db: Session = Depends(database.get_db)):
    
    # 1. Vérification doublon (Utilisation directe de User)
    existing_user = db.query(User).filter(User.phone_number == user_in.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ce numéro est déjà utilisé")

    # 2. Vérif Clé Publique
    if not user_in.public_key or len(user_in.public_key) < 10:
        raise HTTPException(status_code=400, detail="Clé publique (Identity) manquante")

    # 3. Création
    new_user = User(
        phone_number=user_in.phone_number,
        pin_hash=user_in.pin_hash,  
        full_name=user_in.full_name,
        public_key=user_in.public_key,
        role=user_in.role,
        device_hardware_id=user_in.device_hardware_id,
        balance_atomic=50000, # Bonus 500 FCFA
        offline_reserved_atomic=0
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

# --- CONNEXION (LOGIN) ---
@router.post('/login')
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    # Utilisation directe de User
    user = db.query(User).filter(User.phone_number == user_credentials.username).first()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")
    
    if user.pin_hash != user_credentials.password:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Code PIN incorrect")
    
    token = oauth2.create_access_token(data={"user_id": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}