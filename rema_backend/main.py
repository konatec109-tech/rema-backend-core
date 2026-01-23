from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core import database
from app import models
import uvicorn
import os

# 👇 VÉRIFIE QUE 'transactions' EST BIEN LÀ (PLURIEL)
from app.routers import auth, users, transactions 

database.Base.metadata.create_all(bind=database.engine)
app = FastAPI(title="REMA Backend Core")

app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
# 👇 VÉRIFIE QUE CETTE LIGNE EST PRÉSENTE
app.include_router(transactions.router) 

@app.get("/")
def root():
    return {"status": "REMA Backend Online", "version": "1.0.1"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 10000))
    uvicorn.run(app, host="0.0.0.0", port=port)