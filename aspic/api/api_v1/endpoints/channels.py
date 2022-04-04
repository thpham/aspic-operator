from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordBearer

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@router.get("/{channel_id}")
async def read_channel(
  channel_id: str,
  token: str = Depends(oauth2_scheme)
):
  return channels[channel_id]
