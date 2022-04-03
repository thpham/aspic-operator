"""
Entry point for ASPIC CLI
"""

from typing import Optional

import click
import uvicorn

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
  from api import app, stop_flag

  if k8s:
    from k8s import run_kopf
    run_kopf(k8s_namespace, stop_flag)

  # Run web server
  uvicorn.run(app, host="0.0.0.0", port=8080, log_level="info")
