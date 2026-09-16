"""
command-api

Servizio usato dagli operatori di centrale per consultare e gestire le
segnalazioni raccolte da beacon-api. Non ha storage proprio: si appoggia
sempre a beacon-api, raggiunto tramite il nome del Service Kubernetes
(mai tramite IP del Pod).
"""

import os
from typing import Optional

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="command-api")

BEACON_API_URL = os.environ.get("BEACON_API_URL", "http://beacon-api:8080")
BEACON_API_KEY = os.environ.get("BEACON_API_KEY", "changeme")


class StatusPatch(BaseModel):
    status: str


def _headers():
    return {"X-API-Key": BEACON_API_KEY}


@app.get("/healthz")
def healthz():
    return {"status": "alive"}


@app.get("/readyz")
def readyz():
    # Readiness reale: command-api non serve a nulla se non riesce a
    # raggiungere beacon-api, quindi lo verifichiamo attivamente.
    try:
        resp = httpx.get(f"{BEACON_API_URL}/readyz", timeout=2.0)
        if resp.status_code == 200:
            return {"status": "ready"}
        raise HTTPException(status_code=503, detail="beacon-api non pronto")
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=503, detail=f"beacon-api non raggiungibile: {exc}")


@app.get("/incidents")
def list_incidents(status: Optional[str] = None):
    params = {"status": status} if status else {}
    try:
        resp = httpx.get(f"{BEACON_API_URL}/incidents", params=params, headers=_headers(), timeout=5.0)
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"errore contattando beacon-api: {exc}")
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    incidents = resp.json()
    for incident in incidents:
        incident["assigned_unit"] = incident.get("unit")
    return incidents


@app.patch("/incidents/{incident_id}/status")
def update_status(incident_id: str, patch: StatusPatch):
    try:
        resp = httpx.patch(
            f"{BEACON_API_URL}/incidents/{incident_id}",
            json={"status": patch.status},
            headers=_headers(),
            timeout=5.0,
        )
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=502, detail=f"errore contattando beacon-api: {exc}")
    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)
    return resp.json()
