import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.database import engine, Base
from app.routers import auth, users, transactions
from app import models

# --- 1. INITIALISATION DE LA BASE ---
# Cette ligne crée les tables (users_industrial, etc.) 
# dans PostgreSQL dès que le serveur démarre sur Render.
Base.metadata.create_all(bind=engine)

# --- 2. CONFIGURATION DE L'API ---
app = FastAPI(
    title="REMA INDUSTRIAL API", 
    description="Backend de gestion de Cash Numérique et Synchronisation Offline",
    version="3.0.0"
)

# --- 3. SÉCURITÉ CORS ---
# Vital pour permettre à ton application Flutter (Android/iOS) 
# d'appeler ton API sans être bloquée par la sécurité navigateur/système.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 4. INCLUSION DES ROUTEURS ---
# Authentification (Login/Signup)
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])

# Utilisateurs (Solde, Recharge Offline, Synchronisation)
app.include_router(users.router, tags=["Users"])

# Transactions (Historique)
app.include_router(transactions.router, prefix="/transactions", tags=["Transactions"])

# --- 5. TEST DE SANTÉ ---
@app.get("/")
def health_check():
    return {
        "status": "REMA ONLINE", 
        "database": "PostgreSQL Connected",
        "version": "V3.0 GOZEM READY"
    }

# --- 6. ☢️ ROUTE D'URGENCE POUR RESET LA DB (GRATUIT) ☢️ ---
# Appelle cette URL depuis ton navigateur pour effacer et recréer les tables
@app.get("/force-reset-db-secret-key-123")
def force_reset_database():
    try:
        # 1. On détruit tout (Drop tables)
        Base.metadata.drop_all(bind=engine)
        # 2. On reconstruit tout à neuf (Create tables)
        Base.metadata.create_all(bind=engine)
        return {"message": "✅ BASE DE DONNÉES RÉINITIALISÉE AVEC SUCCÈS ! Tu peux relancer l'inscription."}
    except Exception as e:
        return {"error": f"Erreur lors du reset: {str(e)}"}

# --- 7. LANCEMENT DU SERVEUR ---
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)