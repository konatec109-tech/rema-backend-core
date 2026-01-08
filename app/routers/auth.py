from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm

# Import de tes modules internes
from app.core import database
from app import schemas, models, utils, oauth2

router = APIRouter(tags=['Authentication'])

# 👇👇👇 C'EST CETTE FONCTION QUI MANQUAIT ! 👇👇👇
@router.post('/signup', status_code=status.HTTP_201_CREATED)
def signup(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    
    # 1. Vérifier si le numéro existe déjà
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ce numéro est déjà inscrit")

    # 2. Hacher le PIN (Sécurité)
    hashed_pin = utils.hash(user.pin_hash)
    user.pin_hash = hashed_pin # On remplace le PIN clair par le hash

    # 3. Sauvegarder dans la base de données
    # Attention : On mappe les champs du JSON vers le modèle SQL
    new_user = models.User(
        phone_number=user.phone,     # Adapte selon ton models.py (souvent phone_number)
        hashed_password=hashed_pin,  # Adapte selon ton models.py
        full_name=user.full_name,
        role=user.role
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # 4. On retourne l'utilisateur créé (avec le solde par défaut)
    # Ton rema_pay.dart attend un champ 'balance', assure-toi que ton schema UserOut l'a
    return new_user

# 👆👆👆 FIN DE L'AJOUT 👆👆👆


@router.post('/login', response_model=schemas.Token)
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):

    user = db.query(models.User).filter(models.User.phone_number == user_credentials.username).first()

    if not user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")

    if not utils.verify(user_credentials.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")

    access_token = oauth2.create_access_token(data={"user_id": str(user.id)})

    return {"access_token": access_token, "token_type": "bearer"}