from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core import database
from app import models
import uvicorn
import os
# On importe tes routeurs
from app.routers import auth, users, transactions 

# Création des tables au démarrage
# NOUVELLE VERSION (On pointe directement sur database.py)
# Au lieu de : models.Base.metadata.create_all(bind=database.engine)
database.Base.metadata.create_all(bind=database.engine)
app = FastAPI(title="REMA Backend Core")

# --- SÉCURITÉ CORS ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Tout ouvert pour le dev
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- BRANCHEMENT DES ROUTEURS ---
# On les inclut SANS préfixe ici, car ils ont déjà leur préfixe interne.
# (auth.py a "/auth", transactions.py a "/transactions", etc.)

app.include_router(auth.router)          # Gère /auth/signup, /auth/login
app.include_router(users.router)         # Gère /users/...
app.include_router(transactions.router)  # Gère /transactions/...

# --- ROUTE DE TEST ---
@app.get("/")
def root():
    return {"status": "REMA Backend Online", "version": "1.0.0"}

# --- ROUTE DE RESET (Urgence) ---
@app.get("/force-reset-db-secret-key-123")
def reset_database():
    models.Base.metadata.drop_all(bind=database.engine)
    models.Base.metadata.create_all(bind=database.engine)
    return {"status": "Database Reset Successful"}


if __name__ == "__main__":
    # Render donne le port via une variable d'environnement PORT
    port = int(os.environ.get("PORT", 10000))
    # On lance le serveur sur 0.0.0.0 pour qu'il soit accessible de l'extérieur
    uvicorn.run(app, host="0.0.0.0", port=port)