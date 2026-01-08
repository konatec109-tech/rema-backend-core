from passlib.context import CryptContext

# On configure le contexte pour être plus flexible
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash(password: str):
    # 👇 LA CORRECTION : Si la clé est trop longue (Ed25519), 
    # on prend les 72 premiers caractères pour ne pas faire crash Bcrypt
    if len(password) > 71:
        password = password[:71]
    return pwd_context.hash(password)

def verify(plain_password, hashed_password):
    if len(plain_password) > 71:
        plain_password = plain_password[:71]
    return pwd_context.verify(plain_password, hashed_password)