from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm
from app.core import database
from app import schemas, models, utils, oauth2

router = APIRouter()

# --- INSCRIPTION (SIGNUP) ---
@router.post('/signup', status_code=status.HTTP_201_CREATED, response_model=schemas.UserResponse)
def signup(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    
    # 1. Vérification doublon
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ce numéro est déjà utilisé")

    # 2. GESTION DU HASH (Correction du crash 72 bytes)
    # Puisque Flutter envoie déjà un hash Ed25519 (très long), 
    # on le stocke directement pour éviter que Bcrypt ne crash.
    stored_password = user.pin_hash 

    # 3. Création de l'utilisateur
    new_user = models.User(
        phone_number=user.phone,
        hashed_password=stored_password, # On stocke la clé Ed25519
        full_name=user.full_name,
        role=user.role,
        balance=50000.0 # Bonus Gozem Ready !
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

# --- CONNEXION (LOGIN) ---
@router.post('/login', response_model=schemas.Token)
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    # On cherche l'utilisateur par son numéro (username dans OAuth2)
    user = db.query(models.User).filter(models.User.phone_number == user_credentials.username).first()
    
    # Correction de la vérification : On compare directement les deux hashs longs
    if not user or user.hashed_password != user_credentials.password:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Identifiants invalides"
        )
    
    # Création du token
    token = oauth2.create_access_token(data={"user_id": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}