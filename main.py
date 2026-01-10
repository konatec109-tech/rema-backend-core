from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core import database
from app import models

# On importe tes routeurs
from app.routers import auth, users, transactions 

# Création des tables au démarrage
models.Base.metadata.create_all(bind=database.engine)

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