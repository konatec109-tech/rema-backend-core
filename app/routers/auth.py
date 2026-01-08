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
    if db.query(models.User).filter(models.User.phone_number == user.phone).first():
        raise HTTPException(status_code=400, detail="Numéro déjà utilisé")

    # 2. Hachage du PIN
    hashed_pin = utils.hash(user.pin_hash)

    # 3. Création (Mapping Flutter -> DB)
    new_user = models.User(
        phone_number=user.phone,     # On range 'phone' dans 'phone_number'
        hashed_password=hashed_pin,  # On range le hash
        full_name=user.full_name,
        role=user.role,
        balance=50000.0              # Bonus forcé
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

# --- CONNEXION (LOGIN) ---
@router.post('/login', response_model=schemas.Token)
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.phone_number == user_credentials.username).first()
    
    if not user or not utils.verify(user_credentials.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")
    
    token = oauth2.create_access_token(data={"user_id": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}