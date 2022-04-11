from fastapi import APIRouter

from api.api_v1.endpoints import channels

api_router = APIRouter()
api_router.include_router(channels.router, prefix="/channels", tags=["channels"])
