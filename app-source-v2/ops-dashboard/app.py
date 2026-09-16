"""
ops-dashboard (v2)

Aggiornamento richiesto per il progetto: aggiunge un contatore delle
segnalazioni per tipo, sia nella pagina del cruscotto sia come endpoint
JSON dedicato.

Questo file sostituisce app-source/ops-dashboard/app.py quando il team
decide di applicare l'aggiornamento. Il resto del progetto (Dockerfile,
requirements.txt, manifest Kubernetes) non cambia: e' un aggiornamento
puramente applicativo, pensato apposta per passare attraverso la pipeline
senza toccare infrastruttura o deploy a mano.
"""

import os
from collections import Counter

import httpx
from flask import Flask, jsonify, render_template

app = Flask(__name__)

COMMAND_API_URL = os.environ.get("COMMAND_API_URL", "http://command-api:8080")


@app.get("/healthz")
def healthz():
    return {"status": "alive"}


@app.get("/readyz")
def readyz():
    try:
        resp = httpx.get(f"{COMMAND_API_URL}/healthz", timeout=2.0)
        if resp.status_code == 200:
            return {"status": "ready"}
        return {"status": "not ready"}, 503
    except httpx.HTTPError as exc:
        return {"status": "not ready", "error": str(exc)}, 503


def _fetch_incidents():
    resp = httpx.get(f"{COMMAND_API_URL}/incidents", timeout=5.0)
    resp.raise_for_status()
    return resp.json()


def _counts_by_type(incidents):
    counter = Counter(i.get("type", "other") for i in incidents)
    # Includiamo sempre tutti i tipi noti, anche a zero, cosi' il
    # cruscotto non "salta" una colonna quando non ci sono segnalazioni.
    for known_type in ("medical", "fire", "accident", "other"):
        counter.setdefault(known_type, 0)
    return dict(counter)


@app.get("/")
def dashboard():
    incidents = []
    counts = {}
    error = None
    try:
        incidents = _fetch_incidents()
        counts = _counts_by_type(incidents)
    except httpx.HTTPError as exc:
        error = f"command-api non raggiungibile: {exc}"
    return render_template("index.html", incidents=incidents, counts=counts, error=error)


@app.get("/api/incidents")
def api_incidents():
    resp = httpx.get(f"{COMMAND_API_URL}/incidents", timeout=5.0)
    return jsonify(resp.json()), resp.status_code


@app.get("/api/stats")
def api_stats():
    try:
        incidents = _fetch_incidents()
    except httpx.HTTPError as exc:
        return jsonify({"error": str(exc)}), 502
    return jsonify(_counts_by_type(incidents))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
