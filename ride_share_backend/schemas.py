from pydantic import BaseModel

class RideRequestBase(BaseModel):
    pickup: str
    destination: str
    user_name: str

class RideRequestCreate(RideRequestBase):
    pass

class RideRequest(RideRequestBase):
    id: int

    class Config:
        orm_mode = True
