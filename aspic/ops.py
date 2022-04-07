"""
Kubernetes related functionality. Mostly about KOPF, listen to configs and trigger Helmfile upgrade
"""
import datetime
import logging
import os, os.path
from typing import Any, Dict

import dataclasses
import kopf
import kopf._cogs.structs.bodies
import kopf._core.actions.execution

import threading
import yaml

@kopf.on.startup()
def _startup(settings: kopf.OperatorSettings, logger: kopf._core.actions.execution.Logger, **_) -> None:
  #settings.admission.server = kopf.WebhookAutoServer() # kopf.WebhookServer(addr='0.0.0.0',insecure=True, port=8181)
  #settings.admission.managed = 'config.aspic.io'
  
  settings.posting.level = logging.getLevelName(os.environ.get("LOG_LEVEL", "INFO"))
  settings.peering.standalone = True
  settings.persistence.finalizer = 'config.aspic.io/finalizer'
  settings.persistence.progress_storage = kopf.AnnotationsProgressStorage(prefix='config.aspic.io')
  settings.persistence.diffbase_storage = kopf.AnnotationsDiffBaseStorage(
    prefix='config.aspic.io',
    key='last-handled-configuration',
  )
  settings.networking.error_backoffs = [10, 20, 30]
  settings.batching.error_delays = [10, 20, 30]
  logger.info("Aspic Operator started")
  logger.debug("Start date: %s", datetime.datetime.now())

# for liveness probe
@kopf.on.probe(id='health_check')
def health_check(**kwargs):
  return {"status": "ok"}

@kopf.on.login()
def login(**kwargs):
  token = '/var/run/secrets/kubernetes.io/serviceaccount/token'
  if os.path.isfile(token):
    logging.debug("found serviceaccount token: login via service account in kubernetes")
    return kopf.login_with_service_account(**kwargs)
  logging.debug("login via client")
  return kopf.login_via_client(**kwargs)


@dataclasses.dataclass()
class CustomContext:
  create_tpl: str
  delete_tpl: str

  def __copy__(self) -> "CustomContext":
    return self


@kopf.on.create("config.aspic.io", "v1beta1", "update-streams")
def create_project(memo: CustomContext, logger, **kwargs):
  logger.info(memo.create_tpl.format(**kwargs))

@kopf.on.delete("config.aspic.io", "v1beta1", "update-streams")
def delete_project(memo: CustomContext, logger, **kwargs):
  logger.info(memo.delete_tpl.format(**kwargs))

#@kopf.on.validate("config.aspic.io", "v1beta1", "update-streams")
def validate_customer_id(spec, warnings: list[str], **_):
  if spec.get('customerId') == '1234567890':
    warnings.append("The customerId value is invalid.")

#@kopf.on.mutate("config.aspic.io", "v1beta1", "update-streams")
def ensure_default_customer_id(spec, patch, **_):
  if 'customerId' not in spec:
    patch.spec['customerId'] = '1234567890'

def run_kopf(watch_namespaces, stop_flag: threading.Event):

  import asyncio
  import contextlib

  ready_flag = threading.Event()

  def kopf_thread(
    ready_flag: threading.Event,
    stop_flag: threading.Event,
  ):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    with contextlib.closing(loop):

      kopf.configure(verbose=True) # log formatting

      loop.run_until_complete(kopf.operator(
        clusterwide=False,
        namespaces=watch_namespaces,
        ready_flag=ready_flag,
        stop_flag=stop_flag,
        liveness_endpoint="http://0.0.0.0:8181/health",
        memo=kopf.Memo(
          create_tpl="Create: {name} update-stream.",
          delete_tpl="Delete: {name} update-stream.",
        ),
      ))


  thread = threading.Thread(target=kopf_thread, kwargs=dict(
    ready_flag=ready_flag,
    stop_flag=stop_flag,
  ))
  thread.start()
  ready_flag.wait()
