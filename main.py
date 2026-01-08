import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.database import engine, Base
from app.routers import auth, users, transactions

# --- 1. INITIALISATION DE LA BASE (Crée la table users_industrial) ---
Base.metadata.create_all(bind=engine)

# --- 2. CONFIG API ---
app = FastAPI(title="REMA INDUSTRIAL API", version="3.0.0")

# --- 3. SÉCURITÉ CORS (Vital pour mobile) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 4. ROUTES (LE CORRECTIF EST LÀ) ---
# 👇 On ajoute le préfixe /auth pour correspondre à Flutter
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])

# Les autres routes
app.include_router(users.router, tags=["Users"])
app.include_router(transactions.router, tags=["Transactions"])

@app.get("/")
def health_check():
    return {"status": "REMA ONLINE", "version": "V3.0 GOZEM READY"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)