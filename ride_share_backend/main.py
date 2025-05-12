# Install required packages
# pip install fastapi uvicorn sqlalchemy passlib python-jose[cryptography] python-multipart

from fastapi import FastAPI, Depends, HTTPException, status, Query
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel
from starlette import status as starlette_status

# Database imports
from database import get_db, Base, engine
import models

# Create tables
Base.metadata.create_all(bind=engine)

app = FastAPI()

# Security
SECRET_KEY = "YOUR_SECRET_KEY"  # Generate a secure random key in production
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

# Models
class UserCreate(BaseModel):
    name: str
    email: str
    password: str

class DriverCreate(BaseModel):
    name: str
    email: str
    password: str
    license_number: str
    vehicle_type: str
    vehicle_number: str

class UserLogin(BaseModel):
    email: str
    password: str

class DriverLogin(BaseModel):
    email: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
    user_type: str

class TokenData(BaseModel):
    email: Optional[str] = None
    user_type: Optional[str] = None

class RideCreate(BaseModel):
    pickup: str
    destination: str
    departure_time: Optional[datetime] = None
    max_participants: int = 4
    distance: Optional[float] = None
    fare: Optional[float] = None  # Optional manual fare

# Helper functions
def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def authenticate_user(db, email: str, password: str):
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        return False
    if not verify_password(password, user.password):
        return False
    return user

def authenticate_driver(db, email: str, password: str):
    driver = db.query(models.Driver).filter(models.Driver.email == email).first()
    if not driver:
        return False
    if not verify_password(password, driver.password):
        return False
    return driver

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        user_type: str = payload.get("user_type")
        if email is None or user_type is None:
            raise credentials_exception
        token_data = TokenData(email=email, user_type=user_type)
    except JWTError:
        raise credentials_exception
    
    if user_type == "driver":
        user = db.query(models.Driver).filter(models.Driver.email == token_data.email).first()
    else:
        user = db.query(models.User).filter(models.User.email == token_data.email).first()
    
    if user is None:
        raise credentials_exception
    return user

# Routes
@app.post("/register", response_model=dict)
def register_user(user: UserCreate, db: Session = Depends(get_db)):
    # Check if email already exists
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Create new user
    hashed_password = get_password_hash(user.password)
    db_user = models.User(
        name=user.name,
        email=user.email,
        password=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    
    return {"message": "User registered successfully"}

@app.post("/join-ride/{ride_id}", response_model=dict)
def join_ride(
    ride_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Check if ride exists
        ride = db.query(models.RideRequest).filter(models.RideRequest.id == ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")
        
        # Check if user is not already the creator
        if ride.user_id == current_user.id:
            raise HTTPException(status_code=400, detail="You cannot join your own ride")
        
        # Check if user has already joined this ride
        existing_participant = db.query(models.RideParticipant).filter(
            models.RideParticipant.ride_id == ride_id,
            models.RideParticipant.user_id == current_user.id
        ).first()
        
        if existing_participant:
            raise HTTPException(status_code=400, detail="You have already joined this ride")
        
        # Optional: Add a maximum participant limit
        if ride.participant_count >= 4:  # Assuming 4 is the maximum
            raise HTTPException(status_code=400, detail="Ride is already full")
        
        # Create new participant record
        new_participant = models.RideParticipant(
            ride_id=ride_id,
            user_id=current_user.id
        )
        db.add(new_participant)
        
        # Increment participant count
        ride.participant_count += 1
        
        db.commit()
        
        return {
            "message": "Successfully joined the ride",
            "ride_id": ride_id,
            "participant_count": ride.participant_count
        }
        
    except HTTPException as he:
        raise he
    except Exception as e:
        db.rollback()
        print(f"Error joining ride: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to join ride: {str(e)}")
    
@app.post("/leave-ride/{ride_id}", response_model=dict)
def leave_ride(
    ride_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Check if ride exists
        ride = db.query(models.RideRequest).filter(models.RideRequest.id == ride_id).first()
        if not ride:
            raise HTTPException(status_code=404, detail="Ride not found")
        
        # Check if user is the creator (creators can't leave their own ride)
        if ride.user_id == current_user.id:
            raise HTTPException(status_code=400, detail="Ride creators cannot leave their own ride")
        
        # Check if user has actually joined this ride
        participant = db.query(models.RideParticipant).filter(
            models.RideParticipant.ride_id == ride_id,
            models.RideParticipant.user_id == current_user.id
        ).first()
        
        if not participant:
            raise HTTPException(status_code=400, detail="You haven't joined this ride")
        
        # Remove participant record
        db.delete(participant)
        
        # Decrement participant count
        if ride.participant_count > 1:  # Ensure we don't go below 1
            ride.participant_count -= 1
        
        db.commit()
        
        return {
            "message": "Successfully left the ride",
            "ride_id": ride_id,
            "participant_count": ride.participant_count
        }
        
    except HTTPException as he:
        raise he
    except Exception as e:
        db.rollback()
        print(f"Error leaving ride: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to leave ride: {str(e)}")

@app.get("/user/rides")
async def get_user_rides(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Get rides created by the user
    created_rides = db.query(models.RideRequest).filter(models.RideRequest.user_id == current_user.id).all()
    
    # Get rides joined by the user
    joined_rides_query = (
        db.query(models.RideRequest)
        .join(models.RideParticipant, models.RideParticipant.ride_id == models.RideRequest.id)
        .filter(models.RideParticipant.user_id == current_user.id)
    )
    joined_rides = joined_rides_query.all()
    
    # Combine and deduplicate rides
    all_rides = list(set(created_rides + joined_rides))
    
    result = []
    for ride in all_rides:
        # Get creator details
        creator = db.query(models.User).filter(models.User.id == ride.user_id).first()
        
        # Get driver details if assigned
        driver = ride.driver
        
        # Get participants count
        participants_count = db.query(models.RideParticipant).filter(
            models.RideParticipant.ride_id == ride.id
        ).count()
        
        ride_info = {
            "id": ride.id,
            "pickup": ride.pickup,
            "destination": ride.destination,
            "created_at": ride.created_at,
            "departure_time": ride.departure_time,
            "status": ride.status,
            "distance": ride.distance,
            "fare": {
                "amount": ride.fare
            },
            "is_creator": ride.user_id == current_user.id,
            "creator": {
                "id": creator.id,
                "name": creator.name,
                "email": creator.email
            },
            "participant_count": participants_count + 1,  # +1 for the creator
            "driver": {
                "id": driver.id,
                "name": driver.name,
                "vehicle_type": driver.vehicle_type,
                "vehicle_number": driver.vehicle_number
            } if driver else None
        }
        result.append(ride_info)
    
    return {"rides": result}

@app.get("/user/joined-rides")
async def get_user_joined_rides(current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Find all rides where the user is a participant
    joined_rides_query = (
        db.query(models.RideRequest)
        .join(models.RideParticipant, models.RideParticipant.ride_id == models.RideRequest.id)
        .filter(models.RideParticipant.user_id == current_user.id)
    )
    
    joined_rides = joined_rides_query.all()
    
    # Get the joined_at timestamp for each ride
    result = []
    for ride in joined_rides:
        participant = db.query(models.RideParticipant).filter(
            models.RideParticipant.ride_id == ride.id,
            models.RideParticipant.user_id == current_user.id
        ).first()
        
        # Get the ride creator's name
        creator = db.query(models.User).filter(models.User.id == ride.user_id).first()
        
        result.append({
            "id": ride.id,
            "pickup": ride.pickup,
            "destination": ride.destination,
            "created_at": ride.created_at,
            "departure_time": ride.departure_time,  # Include departure time
            "joined_at": participant.created_at if participant else None,
            "creator_name": creator.name if creator else "Unknown",
            "participant_count": ride.participant_count,
            "status": "active"  # You can add more status logic here
        })
    
    return {"rides": result}

@app.get("/match-rides")
def match_rides(
    pickup: str,
    destination: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        # Find all ride requests with similar pickup and destination
        matched_rides = db.query(models.RideRequest).filter(
            models.RideRequest.pickup == pickup,
            models.RideRequest.destination == destination,
            models.RideRequest.user_id != current_user.id  # Exclude current user's rides
        ).all()
        
        # Get user details and participation status for each ride
        result = []
        for ride in matched_rides:
            user = db.query(models.User).filter(models.User.id == ride.user_id).first()
            
            # Check if current user has joined this ride
            has_joined = db.query(models.RideParticipant).filter(
                models.RideParticipant.ride_id == ride.id,
                models.RideParticipant.user_id == current_user.id
            ).first() is not None
            
            result.append({
                "id": ride.id,
                "user_name": user.name if user else "Unknown",
                "pickup": ride.pickup,
                "destination": ride.destination,
                "departure_time": ride.departure_time,  # Include departure time
                "participant_count": ride.participant_count,
                "has_joined": has_joined
            })
        
        return {"matches": result}
    except Exception as e:
        print(f"Error in match_rides: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get matched rides: {str(e)}"
        )

@app.post("/register/driver", response_model=dict)
def register_driver(driver: DriverCreate, db: Session = Depends(get_db)):
    # Check if email already exists
    db_driver = db.query(models.Driver).filter(models.Driver.email == driver.email).first()
    if db_driver:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Check if license number already exists
    db_driver = db.query(models.Driver).filter(models.Driver.license_number == driver.license_number).first()
    if db_driver:
        raise HTTPException(status_code=400, detail="License number already registered")
    
    # Check if vehicle number already exists
    db_driver = db.query(models.Driver).filter(models.Driver.vehicle_number == driver.vehicle_number).first()
    if db_driver:
        raise HTTPException(status_code=400, detail="Vehicle number already registered")
    
    # Create new driver
    hashed_password = get_password_hash(driver.password)
    db_driver = models.Driver(
        name=driver.name,
        email=driver.email,
        password=hashed_password,
        license_number=driver.license_number,
        vehicle_type=driver.vehicle_type,
        vehicle_number=driver.vehicle_number
    )
    db.add(db_driver)
    db.commit()
    db.refresh(db_driver)
    
    return {"message": "Driver registered successfully"}

@app.post("/login/user", response_model=Token)
def login_user(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email, "user_type": "user"}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "user_type": "user"}

@app.post("/login/driver", response_model=Token)
def login_driver(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    driver = authenticate_driver(db, form_data.username, form_data.password)
    if not driver:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": driver.email, "user_type": "driver"}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer", "user_type": "driver"}

@app.post("/ride-request")
def create_ride_request(
    request: RideCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Parse the departure time if provided
    departure_time = request.departure_time
    
    # Make distance optional
    distance = request.distance
    
    # Require manual fare input
    if request.fare is None:
        raise HTTPException(
            status_code=400,
            detail="Fare amount is required"
        )
    
    # Create new ride with default status
    new_ride = models.RideRequest(
        user_id=current_user.id,
        pickup=request.pickup,
        destination=request.destination,
        departure_time=departure_time,
        status="pending",
        participant_count=1,
        distance=distance,
        fare=request.fare
    )
    db.add(new_ride)
    db.commit()
    db.refresh(new_ride)
    
    # Get creator details
    creator = db.query(models.User).filter(models.User.id == current_user.id).first()
    
    # Get participants count
    participants_count = db.query(models.RideParticipant).filter(
        models.RideParticipant.ride_id == new_ride.id
    ).count()
    
    # Get participants details
    participants = []
    participants_query = (
        db.query(models.RideParticipant, models.User)
        .join(models.User, models.User.id == models.RideParticipant.user_id)
        .filter(models.RideParticipant.ride_id == new_ride.id)
    )
    
    for participant, user in participants_query:
        participants.append({
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "joined_at": participant.created_at
        })
    
    # Return full ride details
    return {
        "id": new_ride.id,
        "pickup": new_ride.pickup,
        "destination": new_ride.destination,
        "departure_time": new_ride.departure_time,
        "created_at": new_ride.created_at,
        "status": new_ride.status,
        "distance": new_ride.distance,
        "fare": {
            "amount": new_ride.fare
        },
        "creator": {
            "id": creator.id,
            "name": creator.name,
            "email": creator.email
        },
        "participant_count": participants_count + 1,  # +1 for the creator
        "participants": participants,
        "driver": None,  # No driver assigned yet
        "can_join": True,  # Others can join
        "can_leave": False,  # Creator can't leave
        "can_cancel": True  # Creator can cancel
    }

@app.get("/ride/{ride_id}")
async def get_ride_details(
    ride_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if ride exists
    ride = db.query(models.RideRequest).filter(models.RideRequest.id == ride_id).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    # Get creator details
    creator = db.query(models.User).filter(models.User.id == ride.user_id).first()
    
    # Get participants
    participants_query = (
        db.query(models.RideParticipant, models.User)
        .join(models.User, models.User.id == models.RideParticipant.user_id)
        .filter(models.RideParticipant.ride_id == ride_id)
    )
    
    participants = []
    for participant, user in participants_query:
        participants.append({
            "id": user.id,
            "name": user.name,
            "joined_at": participant.created_at
        })
    
    # Check if current user is the creator
    is_creator = ride.user_id == current_user.id
    
    # Check if current user has joined this ride
    has_joined = db.query(models.RideParticipant).filter(
        models.RideParticipant.ride_id == ride_id,
        models.RideParticipant.user_id == current_user.id
    ).first() is not None
    
    return {
        "ride": {
            "id": ride.id,
            "pickup": ride.pickup,
            "destination": ride.destination,
            "created_at": ride.created_at,
            "departure_time": ride.departure_time,
            "participant_count": ride.participant_count,
            "creator_name": creator.name if creator else "Unknown",
            "is_creator": is_creator,
            "has_joined": has_joined
        },
        "participants": participants
    }


@app.delete("/ride/{ride_id}")
async def delete_ride(
    ride_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Check if ride exists
    ride = db.query(models.RideRequest).filter(models.RideRequest.id == ride_id).first()
    if not ride:
        raise HTTPException(status_code=404, detail="Ride not found")
    
    # Check if user is the creator of the ride
    if ride.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="You can only delete rides you created")
    
    # Delete all participants first (to maintain referential integrity)
    db.query(models.RideParticipant).filter(models.RideParticipant.ride_id == ride_id).delete()
    
    # Delete the ride
    db.delete(ride)
    db.commit()
    
    return {"message": "Ride deleted successfully"}

@app.get("/available-rides")
async def get_available_rides(
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only drivers can view available rides"
        )
    
    # Get all pending rides that haven't been assigned to any driver
    available_rides = db.query(models.RideRequest).filter(
        models.RideRequest.status == "pending",
        models.RideRequest.driver_id.is_(None)
    ).all()
    
    result = []
    for ride in available_rides:
        # Get the creator's details
        creator = db.query(models.User).filter(models.User.id == ride.user_id).first()
        
        # Get current participants count
        participants_count = db.query(models.RideParticipant).filter(
            models.RideParticipant.ride_id == ride.id
        ).count()
        
        result.append({
            "id": ride.id,
            "pickup": ride.pickup,
            "destination": ride.destination,
            "departure_time": ride.departure_time,
            "created_at": ride.created_at,
            "creator_name": creator.name if creator else "Unknown",
            "creator_email": creator.email if creator else "Unknown",
            "participant_count": participants_count + 1,  # +1 for the creator
            "status": ride.status
        })
    
    return {"available_rides": result}

@app.post("/accept-ride/{ride_id}")
async def accept_ride(
    ride_id: int,
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only drivers can accept rides"
        )
    
    # Check if ride exists and is available
    ride = db.query(models.RideRequest).filter(
        models.RideRequest.id == ride_id,
        models.RideRequest.status == "pending",
        models.RideRequest.driver_id.is_(None)
    ).first()
    
    if not ride:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ride not found or not available"
        )
    
    # Check if driver is available
    if not current_user.is_available:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Driver is not available"
        )
    
    # Assign ride to driver
    ride.driver_id = current_user.id
    ride.status = "accepted"
    current_user.is_available = False
    
    db.commit()
    
    # Get creator details
    creator = db.query(models.User).filter(models.User.id == ride.user_id).first()
    
    # Get participants count
    participants_count = db.query(models.RideParticipant).filter(
        models.RideParticipant.ride_id == ride.id
    ).count()
    
    return {
        "message": "Ride accepted successfully",
        "ride": {
            "id": ride.id,
            "pickup": ride.pickup,
            "destination": ride.destination,
            "created_at": ride.created_at,
            "departure_time": ride.departure_time,
            "status": ride.status,
            "creator": {
                "id": creator.id,
                "name": creator.name,
                "email": creator.email
            },
            "participant_count": participants_count + 1,  # +1 for the creator
            "driver": {
                "id": current_user.id,
                "name": current_user.name,
                "vehicle_type": current_user.vehicle_type,
                "vehicle_number": current_user.vehicle_number
            }
        }
    }

@app.post("/complete-ride/{ride_id}")
async def complete_ride(
    ride_id: int,
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only drivers can complete rides"
        )
    
    # Check if ride exists and is assigned to this driver
    ride = db.query(models.RideRequest).filter(
        models.RideRequest.id == ride_id,
        models.RideRequest.driver_id == current_user.id,
        models.RideRequest.status == "accepted"
    ).first()
    
    if not ride:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ride not found or not assigned to you"
        )
    
    # Mark ride as completed and make driver available again
    ride.status = "completed"
    current_user.is_available = True
    
    db.commit()
    
    return {
        "message": "Ride marked as completed successfully",
        "ride_id": ride.id,
        "driver_id": current_user.id
    }

@app.post("/cancel-ride/{ride_id}")
async def cancel_ride(
    ride_id: int,
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only drivers can cancel rides"
        )
    
    # Check if ride exists and is assigned to this driver
    ride = db.query(models.RideRequest).filter(
        models.RideRequest.id == ride_id,
        models.RideRequest.driver_id == current_user.id,
        models.RideRequest.status == "accepted"
    ).first()
    
    if not ride:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ride not found or not assigned to you"
        )
    
    # Mark ride as pending and make driver available again
    ride.status = "pending"  # Changed from "cancelled" to "pending"
    ride.driver_id = None  # Remove driver assignment
    current_user.is_available = True
    
    db.commit()
    
    return {
        "message": "Ride cancelled successfully and made available for other drivers",
        "ride_id": ride.id,
        "driver_id": current_user.id
    }

@app.get("/driver/my-rides")
async def get_driver_rides(
    status: Optional[str] = Query(None, description="Filter by ride status (pending, accepted, completed)"),
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=starlette_status.HTTP_403_FORBIDDEN,
            detail="Only drivers can view their rides"
        )
    
    # Base query for driver's rides
    query = db.query(models.RideRequest).filter(
        models.RideRequest.driver_id == current_user.id
    )
    
    # Apply status filter if provided
    if status:
        if status not in ["pending", "accepted", "completed"]:
            raise HTTPException(
                status_code=starlette_status.HTTP_400_BAD_REQUEST,
                detail="Invalid status. Must be one of: pending, accepted, completed"
            )
        query = query.filter(models.RideRequest.status == status)
    
    # Get all rides
    rides = query.all()
    
    result = []
    for ride in rides:
        # Get the creator's details
        creator = db.query(models.User).filter(models.User.id == ride.user_id).first()
        
        # Get current participants count
        participants_count = db.query(models.RideParticipant).filter(
            models.RideParticipant.ride_id == ride.id
        ).count()
        
        # Get participants details
        participants = []
        participants_query = (
            db.query(models.RideParticipant, models.User)
            .join(models.User, models.User.id == models.RideParticipant.user_id)
            .filter(models.RideParticipant.ride_id == ride.id)
        )
        
        for participant, user in participants_query:
            participants.append({
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "joined_at": participant.created_at
            })
        
        ride_info = {
            "id": ride.id,
            "pickup": ride.pickup,
            "destination": ride.destination,
            "departure_time": ride.departure_time,
            "created_at": ride.created_at,
            "status": ride.status,
            "distance": ride.distance,
            "fare": {
                "amount": ride.fare
            },
            "creator": {
                "id": creator.id,
                "name": creator.name,
                "email": creator.email
            },
            "participant_count": participants_count + 1,  # +1 for the creator
            "participants": participants,
            "driver": {
                "id": current_user.id,
                "name": current_user.name,
                "vehicle_type": current_user.vehicle_type,
                "vehicle_number": current_user.vehicle_number
            },
            "can_complete": ride.status == "accepted",
            "can_cancel": ride.status == "accepted"
        }
        result.append(ride_info)
    
    # Sort rides by status and creation time
    status_order = {"pending": 0, "accepted": 1, "completed": 2}
    result.sort(key=lambda x: (status_order.get(x["status"], 3), x["created_at"]))
    
    return {
        "total_rides": len(result),
        "active_rides": sum(1 for ride in result if ride["status"] == "accepted"),
        "completed_rides": sum(1 for ride in result if ride["status"] == "completed"),
        "rides": result
    }

@app.get("/driver/availability")
async def check_driver_availability(
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only drivers can check availability"
        )
    
    # Check if driver has any active rides
    active_rides = db.query(models.RideRequest).filter(
        models.RideRequest.driver_id == current_user.id,
        models.RideRequest.status == "accepted"
    ).count()
    
    return {
        "is_available": current_user.is_available,
        "has_active_rides": active_rides > 0,
        "active_rides_count": active_rides,
        "can_toggle_availability": active_rides == 0  # Can only toggle if no active rides
    }

@app.post("/driver/toggle-availability")
async def toggle_driver_availability(
    current_user: models.Driver = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify that the current user is a driver
    if not isinstance(current_user, models.Driver):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only drivers can toggle availability"
        )
    
    # Check if driver has any active rides
    active_rides = db.query(models.RideRequest).filter(
        models.RideRequest.driver_id == current_user.id,
        models.RideRequest.status == "accepted"
    ).count()
    
    if active_rides > 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot toggle availability while having active rides"
        )
    
    # Toggle availability
    current_user.is_available = not current_user.is_available
    db.commit()
    
    return {
        "message": "Availability status updated successfully",
        "is_available": current_user.is_available
    }
