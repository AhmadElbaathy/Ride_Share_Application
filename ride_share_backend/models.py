from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Boolean, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    is_driver = Column(Boolean, default=False)  # Add this field to identify drivers

    # Relationships
    rides = relationship("RideRequest", back_populates="creator")

class Driver(Base):
    __tablename__ = "drivers"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password = Column(String)
    license_number = Column(String, unique=True)
    vehicle_type = Column(String)
    vehicle_number = Column(String, unique=True)
    is_available = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    rides = relationship("RideRequest", back_populates="driver")

class RideRequest(Base):
    __tablename__ = "ride_requests"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    driver_id = Column(Integer, ForeignKey("drivers.id"), nullable=True)
    pickup = Column(String)
    destination = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    departure_time = Column(DateTime, nullable=True)
    participant_count = Column(Integer, default=1)
    status = Column(String, default="pending", nullable=False)  # Ensure status has a default value and cannot be null
    distance = Column(Float, nullable=True)  # Distance in kilometers
    fare = Column(Float, nullable=True)  # Manual fare amount
    
    # Relationships
    creator = relationship("User", back_populates="rides")
    driver = relationship("Driver", back_populates="rides")
    participants = relationship("RideParticipant", back_populates="ride")

    def __init__(self, **kwargs):
        super(RideRequest, self).__init__(**kwargs)
        if self.status is None:
            self.status = "pending"  # Ensure status is set even if not provided

class RideParticipant(Base):
    __tablename__ = "ride_participants"

    id = Column(Integer, primary_key=True, index=True)
    ride_id = Column(Integer, ForeignKey("ride_requests.id"))
    user_id = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    ride = relationship("RideRequest", back_populates="participants")
    user = relationship("User")