# init_db.py
from database import engine, Base
import models

def init_database():
    print("Creating database tables...")
    Base.metadata.drop_all(bind=engine)  # Drop all tables first
    Base.metadata.create_all(bind=engine)  # Create tables based on models
    print("Database tables created successfully!")

if __name__ == "__main__":
    init_database()