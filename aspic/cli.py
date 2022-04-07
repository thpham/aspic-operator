"""
Entry point for ASPIC CLI
"""

from typing import Optional
from fastapi import FastAPI

from api.api_v1.api import api_router
from core.config import settings

import click
import uvicorn
import threading

stop_flag = threading.Event()

app = FastAPI(
  title=settings.PROJECT_NAME, openapi_url=f"{settings.API_V1_STR}/openapi.json"
)
app.include_router(api_router, prefix=settings.API_V1_STR)

@click.group(
  name="aspic",
  context_settings=dict(
    auto_envvar_prefix="ASPIC",
  ),
)
def main() -> None:
  """Main entry point"""

@main.command(
  context_settings=dict(

  )
)
@click.option(
  "--api", is_flag=True, default=False, help="Start API server"
)
@click.option("--watch-namespaces", help="Kubernetes namespaces to watch (comma separated).")
def operator(
  api: bool, watch_namespaces: Optional[str]
) -> None:
  """ Start ASPIC Operator"""
  from ops import run_kopf
  run_kopf(watch_namespaces.split(","), stop_flag)

  if api:
    # Run web server
    uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
  else:
    import signal, time

    def handler(signum, frame):
      stop_flag.set()
      exit(1)

    signal.signal(signal.SIGINT, handler)

    while True:
      time.sleep(5)


@app.get("/health")
async def health_check():
  return {"status": "ok"}

channels = {}

@app.on_event("startup")
async def startup_event():
  channels["stable"]    = {"version": "v1.9.3"}
  channels["candidate"] = {"version": "v2.0.0-rc3"}
  channels["develop"]   = {"version": "v2.2.1-dev"}

@app.on_event("shutdown")
def shutdown_event():
  stop_flag.set()
