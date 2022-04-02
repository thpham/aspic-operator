"""
Entry point for ASPIC CLI
"""

from typing import Optional

import click
import signal

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
  
  from aiohttp import web
  from api import webservice

  if k8s:
    import threading
    from k8s import run_kopf

    stop_flag = threading.Event()

    # On webservice shutdown let's signal Kopf
    async def on_app_shutdown(app):
      stop_flag.set()
    
    #def handle_interrupt(signum, frame):
    #  stop_flag.set()

    #signal.signal(signal.SIGINT, handle_interrupt)

    webservice.on_shutdown.append(on_app_shutdown)

    run_kopf(k8s_namespace, stop_flag)

  # Run web service
  web.run_app(webservice)
