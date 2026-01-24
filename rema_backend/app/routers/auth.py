from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm
from app.core import database
from app import schemas, models, utils, oauth2

router = APIRouter(prefix="/auth", tags=["Authentication"])

# --- INSCRIPTION (SIGNUP) ---
@router.post('/signup', status_code=status.HTTP_201_CREATED)
def signup(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    
    # 1. Vérification doublon
    # CORRECTION : On utilise user.phone_number au lieu de user.phone
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ce numéro est déjà utilisé")

    # 2. VÉRIFICATION CRITIQUE : On s'assure que le mobile a envoyé sa clé
    if not user.public_key or len(user.public_key) < 10:
        raise HTTPException(status_code=400, detail="Clé publique (Identity) manquante")

    # 3. Création de l'utilisateur avec la VRAIE clé du mobile
    new_user = models.User(
        phone_number=user.phone_number, # <--- CORRIGÉ ICI
        pin_hash=user.pin_hash,  
        full_name=user.full_name,
        public_key=user.public_key, # <--- ON SAUVEGARDE LA VRAIE CLÉ ICI
        role=user.role,
        device_hardware_id=user.device_hardware_id, # <--- AJOUTÉ (Important pour la sécurité)
        balance=50000.0, # Bonus de bienvenue
        offline_reserved_amount=0.0
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {
        "message": "Inscription réussie",
        "user_id": new_user.id,
        "balance": new_user.balance
    }

# --- CONNEXION (LOGIN) ---
@router.post('/login')
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    
    user = db.query(models.User).filter(models.User.phone_number == user_credentials.username).first()
    
    if not user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")
    
    # Comparaison simple du PIN (Pour la démo)
    if user.pin_hash != user_credentials.password:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Code PIN incorrect")
    
    token = oauth2.create_access_token(data={"user_id": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}