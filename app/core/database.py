from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# URL de la base de données (SQLite pour le dev)
SQLALCHEMY_DATABASE_URL = "sqlite:///./rema.db"

# Création du moteur (Engine)
# check_same_thread=False est nécessaire uniquement pour SQLite
engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)

# Création de la Session (L'usine à connexions)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# La classe de base pour tes modèles (User, Transaction, etc.)
Base = declarative_base()

# --- LA FONCTION MANQUANTE (get_db) ---
# C'est elle que tous tes routeurs cherchent !
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()