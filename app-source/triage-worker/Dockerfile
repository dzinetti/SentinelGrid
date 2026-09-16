FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY worker.py .

# TODO: questo Dockerfile non ha ancora un comando di avvio.
# Aggiungere l'istruzione che esegue worker.py con python3.

CMD ["python3", "worker.py"]