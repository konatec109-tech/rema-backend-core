import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.database import engine, Base
from app.routers import auth, users, transactions
from app import models

# --- INIT DB ---
Base.metadata.create_all(bind=engine)

# --- CONFIG API ---
app = FastAPI(
    title="REMA INDUSTRIAL API",
    version="2.0.0"
)

# --- CORS (CRITIQUE) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- ROUTES ---
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(transactions.router)

# --- HEALTH CHECK ---
@app.get("/")
def health_check():
    return {"status": "REMA ONLINE", "platform": "Render"}

# --- START ---
if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)