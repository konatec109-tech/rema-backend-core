from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from app.core import database
from app import models
# Assure-toi que tes routers sont bien importés ici
from app.routers import auth, users, transactions 
import uvicorn
import os

# Création initiale des tables (si elles n'existent pas)
database.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="REMA Backend Core", version="1.0.2")

# Configuration CORS (Accepte tout pour le développement)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusion des routes
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(transactions.router) 

@app.get("/")
def root():
    return {
        "status": "REMA Backend Online", 
        "version": "1.0.2",
        "system": "Atomic Int + Ed25519 Security"
    }

# ⚠️ ROUTE DANGEREUSE : RÉINITIALISATION DB
# À utiliser UNIQUEMENT pour nettoyer la base après le changement de type (Float -> Int)
# URL: /sys/dangerous-reset-db?admin_key=REMA_MASTER_RESET_2026
@app.get("/sys/dangerous-reset-db")
def reset_database(admin_key: str):
    SECRET_KEY = "REMA_MASTER_RESET_2026"
    
    if admin_key != SECRET_KEY:
        raise HTTPException(status_code=403, detail="Accès refusé. Clé incorrecte.")

    try:
        # 1. On supprime tout (Drop All)
        database.Base.metadata.drop_all(bind=database.engine)
        
        # 2. On recrée tout propre (Create All)
        database.Base.metadata.create_all(bind=database.engine)
        
        return {
            "status": "success", 
            "message": "♻️ Base de données entièrement réinitialisée (Tables vides & Structures à jour)."
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)