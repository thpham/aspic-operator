#!/usr/bin/env python3

import datetime
import logging
import os, os.path
from typing import Any, Dict

import kopf
import kopf._cogs.structs.bodies
import kopf._core.actions.execution

@kopf.on.startup()
def _startup(settings: kopf.OperatorSettings, logger: kopf._core.actions.execution.Logger, **_) -> None:
  settings.posting.level = logging.getLevelName(os.environ.get("LOG_LEVEL", "INFO"))
  settings.peering.standalone = True
  settings.persistence.finalizer = 'core.aspic.io/finalizer'
  settings.persistence.progress_storage = kopf.AnnotationsProgressStorage(prefix='core.aspic.io')
  settings.persistence.diffbase_storage = kopf.AnnotationsDiffBaseStorage(
    prefix='core.aspic.io',
    key='last-handled-configuration',
  )
  settings.networking.error_backoffs = [10, 20, 30]
  settings.batching.error_delays = [10, 20, 30]
  logger.info("Aspic Operator started")
  logger.debug("Start date: %s", datetime.datetime.now())

@kopf.on.login()
def login(**kwargs):
  token = '/var/run/secrets/kubernetes.io/serviceaccount/token'
  if os.path.isfile(token):
    logging.debug("found serviceaccount token: login via pykube in kubernetes")
    return kopf.login_via_pykube(**kwargs)
  logging.debug("login via client")
  return kopf.login_via_client(**kwargs)

@kopf.on.create("core.aspic.io", "v1beta1", "projects")
def create_fn(logger, **kwargs):
  logger.info("new project")

@kopf.on.delete("core.aspic.io", "v1beta1", "projects")
def delete_fn(logger, **kwargs):
  logger.info("delete project")
