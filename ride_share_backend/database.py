from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Database URL (SQLite in this case)
DATABASE_URL = "sqlite:///./test.db"

# Create an engine and a session
engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Add this function to get a database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()