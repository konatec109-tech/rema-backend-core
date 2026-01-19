import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 1. On récupère l'URL de Render. Si elle n'existe pas, on utilise SQLite par défaut.
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")

# 2. Le petit correctif magique pour PostgreSQL sur Render
if SQLALCHEMY_DATABASE_URL and SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace("postgres://", "postgresql://", 1)

# 3. Si aucune URL n'est trouvée (cas de ton PC local), on crée une base SQLite
if not SQLALCHEMY_DATABASE_URL:
    SQLALCHEMY_DATABASE_URL = "sqlite:///./rema.db"

# 4. Configuration du moteur
connect_args = {}
if "sqlite" in SQLALCHEMY_DATABASE_URL:
    connect_args = {"check_same_thread": False}

engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# La fonction que tes routers utilisent
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()