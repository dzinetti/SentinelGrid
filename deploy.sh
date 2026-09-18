#!/usr/bin/env bash
set -e

echo "=== 1. Deploy Infrastruttura con Terraform ==="
cd terraform/environments/prod

terraform init -backend-config="backend.hcl"
terraform plan
terraform apply -auto-approve

echo "=== 2. Aggiornamento Kubeconfig Locale ==="
aws eks update-kubeconfig --region eu-west-1 --name sentinelgrid-eks-cluster

echo "=== 3. Attesa stabilizzazione Nodi EKS ==="
echo "In attesa che i nodi del cluster siano pronti (Ready)..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo "=== 4. Trigger della Pipeline CI/CD via Git Push ==="
cd ../../../

git add .
git commit -m "chore: trigger codepipeline deployment" --allow-empty
git push origin esandragan

echo "=== 5. Attesa rollout deployment Kubernetes ==="
echo "In attesa che la CodePipeline aggiorni il deployment ops-dashboard..."
# Timeout esteso a 10m per dare tempo alla pipeline AWS di completare la build
kubectl rollout status deployment/ops-dashboard -n prod --timeout=600s

echo "=== 6. URL del Load Balancer ==="
LB_HOST=""
while [ -z "$LB_HOST" ]; do
  echo "Recupero dell'EXTERNAL-IP della dashboard in corso..."
  LB_HOST=$(kubectl get svc ops-dashboard -n prod -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -z "$LB_HOST" ] && sleep 5
done

echo ""
echo "===================================================="
echo " Application Access URL:"
echo " http://$LB_HOST:8080"
echo "===================================================="