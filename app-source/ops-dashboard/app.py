"""
ops-dashboard

Frontend minimale pensato per essere proiettato in sala operativa.
Mostra lo stato delle segnalazioni leggendole da command-api tramite
il Service Kubernetes (mai tramite IP di Pod).
"""

import os

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


@app.get("/")
def dashboard():
    incidents = []
    error = None
    try:
        resp = httpx.get(f"{COMMAND_API_URL}/incidents", timeout=5.0)
        if resp.status_code == 200:
            incidents = resp.json()
        else:
            error = f"command-api ha risposto {resp.status_code}"
    except httpx.HTTPError as exc:
        error = f"command-api non raggiungibile: {exc}"
    return render_template("index.html", incidents=incidents, error=error)


@app.get("/api/incidents")
def api_incidents():
    resp = httpx.get(f"{COMMAND_API_URL}/incidents", timeout=5.0)
    return jsonify(resp.json()), resp.status_code


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
