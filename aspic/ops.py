"""
Kubernetes related functionality. Mostly about KOPF, listen to configs and trigger Helmfile upgrade
"""
import datetime
import logging
import os, os.path
from typing import Any, Dict, List

import kopf
import kopf._cogs.structs.bodies
import kopf._core.actions.execution

import threading
import pykube, yaml

@kopf.on.startup()
def _startup(settings: kopf.OperatorSettings, logger, **_) -> None:
  profile = os.environ.get('PROFILE', 'dev')
  if profile == 'prod':
    settings.admission.server = kopf.WebhookServer(
      addr='0.0.0.0',
      host='aspic-operator.aspic-operator.svc',
      port=8282,
      insecure=False,
      cafile='/var/aspic/certs/ca.crt', # or cadata, or capath.
      certfile='/var/aspic/certs/tls.crt',
      pkeyfile='/var/aspic/certs/tls.key'
    )
  elif profile == 'dev':
    settings.admission.server = kopf.WebhookServer(
      addr='0.0.0.0',
      port=8282,
      cadump='selfsigned.pem'
    )
    settings.admission.server.host = 'host.docker.internal'
    settings.admission.managed = 'webhook.aspic.io'

  settings.posting.level = logging.getLevelName(os.environ.get("LOG_LEVEL", "DEBUG"))
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

def create_pod(**kwargs):
    pod_data = yaml.safe_load(f"""
        apiVersion: v1
        kind: Pod
        spec:
          containers:
          - name: shell
            image: busybox
            command: ["sh", "-x", "-c", "sleep 5"]
    """)
    kopf.adopt(pod_data)
    kopf.label(pod_data, {'config.aspic.io/managed': 'true'})

    api = pykube.HTTPClient(pykube.KubeConfig.from_env())
    pod = pykube.Pod(api, pod_data)
    pod.create()
    api.session.close()


@kopf.on.create("config.aspic.io", "v1beta1", "update-streams")
def create_update_stream(logger, **kwargs):
  logger.info("Create UpdateStream...")
  #create_pod(**kwargs)

@kopf.on.delete("config.aspic.io", "v1beta1", "update-streams")
def delete_update_stream(logger, **kwargs):
  logger.info("Delete UpdateStream...")

@kopf.on.validate("config.aspic.io", "v1beta1", "update-streams",
  id="update-streams", operation="CREATE"
)
def validate_update_streams(
  spec: kopf.Spec,
  warnings: List[str],
  **_: Any
):
  if spec.get('customerId') == '1234567890':
    warnings.append("The customerId value is invalid.")
    raise kopf.AdmissionError("customerId must be valid...", code=400)

@kopf.on.mutate("pods",
  id="mutate-pods", operation="CREATE",
  labels={"config.aspic.io/managed":"true"}
)
def mutate_pods(
  spec: kopf.Spec,
  patch: kopf.Patch,
  dryrun: bool,
  logger: kopf.Logger,
  **_: Any,
) -> kopf.Patch:
  logger.debug("mutate pods - Patch: %s", str(patch))

  return patch

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
      ))


  thread = threading.Thread(target=kopf_thread, kwargs=dict(
    ready_flag=ready_flag,
    stop_flag=stop_flag,
  ))
  thread.start()
  ready_flag.wait()
