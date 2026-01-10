from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy.orm import Session
from fastapi.security.oauth2 import OAuth2PasswordRequestForm
from app.core import database
from app import schemas, models, utils, oauth2
import uuid # Nécessaire pour générer la clé publique temporaire

router = APIRouter(prefix="/auth", tags=["Authentication"])

# --- INSCRIPTION (SIGNUP) ---
@router.post('/signup', status_code=status.HTTP_201_CREATED)
def signup(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    
    # 1. Vérification doublon
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Ce numéro est déjà utilisé")

    # 2. Génération Clé Publique (Temporaire)
    # Comme le modèle user.py exige une public_key unique, on en génère une 
    # si le front ne l'envoie pas encore, pour éviter le crash "Null Integrity Error".
    generated_pk = str(uuid.uuid4()).replace("-", "")

    # 3. Création de l'utilisateur
    new_user = models.User(
        phone_number=user.phone,
        # CORRECTION ICI : On utilise le nom exact de la colonne dans user.py
        pin_hash=user.pin_hash,  
        full_name=user.full_name,
        public_key=generated_pk, # Obligatoire selon user.py
        role=user.role,
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
    
    # Correction : On compare user.pin_hash (base) avec user_credentials.password (envoyé par l'app)
    # Pas de bcrypt ici, juste une comparaison de chaînes strictes
    if not user or user.pin_hash != user_credentials.password:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Identifiants invalides"
        )
    
    token = oauth2.create_access_token(data={"user_id": str(user.id)})
    return {"access_token": token, "token_type": "bearer"}