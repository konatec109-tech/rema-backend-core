from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm

# 👇 LA CORRECTION EST ICI (On importe database depuis app.core)
from app.core import database
from app import schemas, models, utils, oauth2

router = APIRouter(tags=['Authentication'])

@router.post('/login', response_model=schemas.Token)
def login(user_credentials: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):

    # 1. On cherche l'utilisateur par son téléphone (username = phone_number)
    user = db.query(models.User).filter(models.User.phone_number == user_credentials.username).first()

    if not user:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")

    # 2. On vérifie le mot de passe
    if not utils.verify(user_credentials.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Identifiants invalides")

    # 3. On crée le JWT
    # On convertit l'ID en string pour éviter tout bug de sérialisation
    access_token = oauth2.create_access_token(data={"user_id": str(user.id)})

    return {"access_token": access_token, "token_type": "bearer"}