"""
beacon-api

Servizio di ingestion per SentinelGrid.
Riceve le segnalazioni di emergenza dalle unita' sul campo, le salva su
storage persistente e le rende disponibili agli altri servizi.

Questo e' l'unico componente che scrive dati in modo permanente:
se il Pod viene riavviato, le segnalazioni non devono andare perse.
"""

import json
import os
import time
import uuid
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

app = FastAPI(title="beacon-api")

DATA_FILE = Path(os.environ.get("DATA_FILE", "/data/incidents.jsonl"))
BEACON_API_KEY = os.environ.get("BEACON_API_KEY", "changeme")

VALID_TYPES = {"medical", "fire", "accident", "other"}


class IncidentIn(BaseModel):
    type: str
    location: str
    description: str
    unit: str


class IncidentPatch(BaseModel):
    status: Optional[str] = None
    priority: Optional[int] = None


def _check_key(x_api_key: Optional[str]):
    if x_api_key != BEACON_API_KEY:
        raise HTTPException(status_code=401, detail="API key non valida o mancante")


def _ensure_data_file():
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    if not DATA_FILE.exists():
        DATA_FILE.touch()


def _read_all():
    _ensure_data_file()
    incidents = []
    with DATA_FILE.open("r") as f:
        for line in f:
            line = line.strip()
            if line:
                incidents.append(json.loads(line))
    return incidents


def _write_all(incidents):
    _ensure_data_file()
    with DATA_FILE.open("w") as f:
        for incident in incidents:
            f.write(json.dumps(incident) + "\n")


@app.get("/healthz")
def healthz():
    # Liveness: il processo e' vivo, non verifica dipendenze esterne.
    return {"status": "alive"}


@app.get("/readyz")
def readyz():
    # Readiness: verifica che lo storage sia scrivibile.
    try:
        _ensure_data_file()
        with DATA_FILE.open("a"):
            pass
        return {"status": "ready"}
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"storage non disponibile: {exc}")


@app.post("/incidents")
def create_incident(incident: IncidentIn, x_api_key: Optional[str] = Header(default=None)):
    _check_key(x_api_key)

    if incident.type not in VALID_TYPES:
        raise HTTPException(status_code=400, detail=f"type deve essere uno tra {VALID_TYPES}")

    incidents = _read_all()
    new_incident = {
        "id": str(uuid.uuid4())[:8],
        "type": incident.type,
        "location": incident.location,
        "description": incident.description,
        "unit": incident.unit,
        "status": "open",
        "priority": None,
        "reported_at": time.time(),
    }
    incidents.append(new_incident)
    _write_all(incidents)
    return new_incident


@app.get("/incidents")
def list_incidents(status: Optional[str] = None, x_api_key: Optional[str] = Header(default=None)):
    _check_key(x_api_key)
    incidents = _read_all()
    if status:
        incidents = [i for i in incidents if i.get("status") == status]
    return incidents


@app.patch("/incidents/{incident_id}")
def patch_incident(incident_id: str, patch: IncidentPatch, x_api_key: Optional[str] = Header(default=None)):
    _check_key(x_api_key)
    incidents = _read_all()
    for incident in incidents:
        if incident["id"] == incident_id:
            if patch.status is not None:
                incident["status"] = patch.status
            if patch.priority is not None:
                incident["priority"] = patch.priority
            _write_all(incidents)
            return incident
    raise HTTPException(status_code=404, detail="incidente non trovato")
