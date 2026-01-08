from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm

# Assure-toi que les imports correspondent à tes dossiers
from app.core import database
from app import schemas, models, utils, oauth2

router = APIRouter(tags=['Authentication'])

# 👇 LA FONCTION SIGNUP (INSCRIPTION) RESTAURÉE
@router.post('/signup', status_code=status.HTTP_201_CREATED, response_model=schemas.UserResponse)
def signup(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    
    # 1. Vérifier si le numéro existe déjà
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ce numéro est déjà inscrit")

    # 2. Hacher le PIN
    hashed_pin = utils.hash(user.password)

    # 3. Créer l'utilisateur (Avec les 50 000 par défaut du models.py)
    new_user = models.User(
        phone_number=user.phone_number,
        hashed_password=hashed_pin,
        full_name=user.full_name,
        role=user.role
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # 4. On renvoie l'utilisateur (avec le champ balance inclus grâce au schéma)
    return new_user

@router.post('/login', response_model=schemas.Token)
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):

    user = db.query(models.User).filter(models.User.phone_number == user_credentials.username).first()

    if not user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")

    if not utils.verify(user_credentials.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")

    access_token = oauth2.create_access_token(data={"user_id": str(user.id)})

    return {"access_token": access_token, "token_type": "bearer"}