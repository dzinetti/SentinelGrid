"""
triage-worker

Script di elaborazione periodica per SentinelGrid.
Non e' un servizio web: viene eseguito una volta per invocazione e poi
termina. Pensato per essere lanciato da un CronJob Kubernetes.

Ad ogni esecuzione:
1. legge da beacon-api le segnalazioni con status "open";
2. calcola una priorita' (0-100) in base al tipo di emergenza e al
   tempo trascorso dalla segnalazione;
3. scrive la priorita' calcolata su beacon-api.
"""

import os
import sys
import time

import httpx

BEACON_API_URL = os.environ.get("BEACON_API_URL", "http://beacon-api:8080")
BEACON_API_KEY = os.environ.get("BEACON_API_KEY", "changeme")

BASE_SCORE = {
    "medical": 80,
    "fire": 90,
    "accident": 60,
    "other": 40,
}


def _headers():
    return {"X-API-Key": BEACON_API_KEY}


def compute_priority(incident: dict) -> int:
    base = BASE_SCORE.get(incident.get("type"), 40)
    elapsed_minutes = max(0, (time.time() - incident.get("reported_at", time.time())) / 60)
    return int(min(100, base + elapsed_minutes))


def main():
    try:
        resp = httpx.get(
            f"{BEACON_API_URL}/incidents",
            params={"status": "open"},
            headers=_headers(),
            timeout=5.0,
        )
    except httpx.HTTPError as exc:
        print(f"[triage-worker] impossibile contattare beacon-api: {exc}")
        sys.exit(1)

    if resp.status_code != 200:
        print(f"[triage-worker] beacon-api ha risposto {resp.status_code}: {resp.text}")
        sys.exit(1)

    incidents = resp.json()
    print(f"[triage-worker] {len(incidents)} segnalazioni aperte da elaborare")

    for incident in incidents:
        priority = compute_priority(incident)
        patch_resp = httpx.patch(
            f"{BEACON_API_URL}/incidents/{incident['id']}",
            json={"priority": priority},
            headers=_headers(),
            timeout=5.0,
        )
        if patch_resp.status_code == 200:
            print(f"[triage-worker] incidente {incident['id']} -> priorita' {priority}")
        else:
            print(f"[triage-worker] errore aggiornando {incident['id']}: {patch_resp.status_code}")

    print("[triage-worker] elaborazione completata")


if __name__ == "__main__":
    main()
