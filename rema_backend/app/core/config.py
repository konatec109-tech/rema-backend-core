import os
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    # NOM DU PROJET
    PROJECT_NAME: str = "REMA API"
    
    # SECURITE
    # (Garde ta clé secrète actuelle si tu l'as changée, sinon utilise celle-ci pour le dev)
    SECRET_KEY: str = os.getenv("SECRET_KEY", "remplacez_moi_par_une_cle_ultra_securisee_et_longue")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # CONFIGURATION API
    API_V1_STR: str = "/api/v1"  # C'est important pour ton fichier deps.py

    # CORS (Cross-Origin Resource Sharing)
    # C'est ici qu'on autorise le frontend (Flutter) à parler au backend
    # Pour le dev, on met "*" (tout le monde) ou localhost.
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:8000",
        "http://localhost:3000", # Souvent utilisé par React/Web
        "*" # Autorise tout le monde (utile pour tester avec le mobile en dev)
    ]

    class Config:
        env_file = ".env"
        # Cette option permet de gérer les majuscules/minuscules
        case_sensitive = True

settings = Settings()