from fastapi import APIRouter, status, HTTPException, Depends
from sqlalchemy.orm import Session
from app.core import database 
from app import models, schemas, utils, oauth2 # <--- C'est souvent oauth2 qui manque

router = APIRouter(
    prefix="/users",
    tags=["Users"]
)

# ==============================================================================
# 1. INSCRIPTION (Sign Up)
# ==============================================================================
@router.post("/", status_code=status.HTTP_201_CREATED, response_model=schemas.UserResponse)
def create_user(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    
    # A. Vérification si le numéro existe déjà
    existing_user = db.query(models.User).filter(models.User.phone_number == user.phone_number).first()
    if existing_user:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Ce numéro existe déjà.")

    # B. Hachage du mot de passe (Sécurité)
    hashed_pwd = utils.hash(user.password)
    
    # C. Création de l'utilisateur
    # ⚠️ IMPORTANT : On ne fait pas **user.dict() car models.User attend 'hashed_password', pas 'password'
    new_user = models.User(
        phone_number=user.phone_number,
        full_name=user.full_name,
        hashed_password=hashed_pwd, # On insère le hash ici
        
        # --- BONUS TEST ARCHITECTE ---
        # On donne 50.000 FCFA dès l'inscription pour faciliter ta démo ce soir
        balance=50000.0,
        offline_reserved_amount=0.0
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user

# ==============================================================================
# 2. VOIR SON PROFIL
# ==============================================================================
@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_profile(current_user: models.User = Depends(oauth2.get_current_user)):
    return current_user

# ==============================================================================
# 3. DEVICE BINDING (RECHARGEMENT OFFLINE)
# ==============================================================================
@router.post("/offline/activate")
def activate_offline_mode(
    amount: float,
    db: Session = Depends(database.get_db),
    # ✅ SÉCURITÉ JWT ACTIVÉE : On exige un token valide ici
    current_user: models.User = Depends(oauth2.get_current_user)
):
    """
    SÉCURISATION DES FONDS (Fund Locking).
    Nécessite le Token JWT envoyé par Flutter.
    """
    
    # ÉTAPE A : Calcul de la vérité financière
    # Disponible = Ce que j'ai TOTAL - Ce que j'ai déjà mis dans ma poche offline
    available_funds = current_user.balance - current_user.offline_reserved_amount
    
    # On ajoute une petite tolérance (0.01) pour les calculs flottants
    if amount > (available_funds + 0.01):
        raise HTTPException(
            status_code=400, 
            detail=f"Fonds insuffisants. Solde total: {current_user.balance}, mais disponible en ligne: {available_funds}."
        )

    # ÉTAPE B : Le Verrouillage (Commit)
    # On augmente la réserve. L'argent est maintenant "sorti" du système en ligne.
    current_user.offline_reserved_amount += amount
    db.commit()

    print(f"✅ SUCCÈS : {current_user.full_name} a verrouillé {amount} FCFA pour usage Offline.")

    return {
        "status": "OFFLINE_READY",
        "reserved_amount": current_user.offline_reserved_amount,
        "message": "Fonds sécurisés et transférés virtuellement au Secure Element."
    }