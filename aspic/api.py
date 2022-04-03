from fastapi import FastAPI
import threading

app       = FastAPI()
stop_flag = threading.Event()

@app.get("/health")
async def health_check():
  return {"status": "ok"}

@app.on_event("shutdown")
def shutdown_event():
  stop_flag.set()

channels = {}

@app.on_event("startup")
async def startup_event():
  channels["stable"]    = {"version": "v1.9.3"}
  channels["candidate"] = {"version": "v2.0.0-rc3"}
  channels["develop"]   = {"version": "v2.2.1-dev"}

@app.get("/apis/v1/channels/{channel_id}")
async def read_channel_v1(channel_id: str):
  return channels[channel_id]
