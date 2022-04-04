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
    auto_envvar_prefix="ASPIC",
  )
)
@click.option(
  "--k8s", is_flag=True, default=False, help="Enable Kubernetes integration"
)
@click.option("--k8s-namespace", default="default", help="Kubernetes namespace to listen")
def service(
  k8s: bool, k8s_namespace: Optional[str]
) -> None:
  """ Start Aspic API Service """
  if k8s:
    from k8s import run_kopf
    run_kopf(k8s_namespace, stop_flag)

  # Run web server
  uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")

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
