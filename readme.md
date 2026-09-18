# SentinelGrid

SentinelGrid è un progetto AWS EKS orientato a microservizi per la gestione e la sorveglianza delle segnalazioni e dei servizi applicativi in produzione. L’architettura prevede un cluster EKS con namespace `prod`, deployment di microservizi, storage persistente, cronjob per processi batch e integrazione con ECR, CodeBuild, CodePipeline, Terraform e Kubernetes.

## 1. Obiettivo del progetto

Il progetto vuole dimostrare un’architettura cloud-native su AWS con:

- cluster Kubernetes su Amazon EKS
- microservizi containerizzati
- registry immagini su Amazon ECR
- pipeline CI/CD con AWS CodePipeline e CodeBuild
- storage persistente con EBS via CSI driver
- gestione di config e secret in Kubernetes
- automazione con Terraform per il provisioning della base infrastrutturale

---

## 2. Architettura

### Componenti principali

- `beacon-api`: API principale per la gestione delle segnalazioni
- `command-api`: API per orchestrare chiamate e comunicazioni tra servizi
- `ops-dashboard`: dashboard web per visualizzare lo stato e i dati dell’applicazione
- `triage-worker`: cronjob per task periodici e analisi batch
- EKS cluster + ECR repository + VPC + security groups + IAM roles

### Topologia logica

```text
GitHub
  │
  ▼
CodePipeline / CodeBuild
  │
  ▼
Amazon ECR
  │
  ▼
Amazon EKS (namespace prod)
  ├── beacon-api
  ├── command-api
  ├── ops-dashboard
  └── triage-worker (CronJob)
```

---

## 3. Prerequisiti

Prima di iniziare, assicurati di avere installato e configurato correttamente:

- AWS CLI
- Terraform
- kubectl
- eksctl
- accesso AWS con privilegi sufficienti
- account AWS con permessi per:
  - EKS
  - ECR
  - IAM
  - VPC
  - EC2
  - ELB / ALB
  - EBS
  - CloudWatch Logs
  - CodeBuild / CodePipeline

Controlla le versioni installate:

```bash
aws --version
terraform version
kubectl version --client
eksctl version
```

Configura il profilo AWS:

```bash
aws configure
# oppure
aws sso login --profile <profile-name>

export AWS_PROFILE=<profile-name>
export AWS_REGION=eu-west-1
```

---

## 4. Deploy da zero

### 4.1. Clonare il repository

```bash
git clone <repo-url>
cd ProgettoFinale
ls -la
```

### 4.2. Alternativa rapida: usare lo script di deploy

Se vuoi un flusso più veloce e guidato, puoi usare lo script già presente nel repository: `deploy.sh`.

La logica è semplice: ti basta entrare nella cartella corretta del progetto, modificare la cartella dell'ambiente all'interno ed  avviare lo script. I percorsi all’interno dello script sono relativi alla cartella del repository, quindi non serve modificare manualmente più file per farli puntare al corretto posizionamento.

```bash
cd ProgettoFinale
chmod +x deploy.sh
./deploy.sh
```

Cosa fa automaticamente lo script:

- entra nella cartella Terraform (`terraform/environments/prod`)
- inizializza il backend remoto con `backend.hcl`
- esegue `terraform plan` e `terraform apply -auto-approve`
- aggiorna il kubeconfig locale del cluster EKS
- attende che i nodi siano pronti
- esegue `git add`, `git commit` e `git push` per triggerare la pipeline
- attende il rollout di `ops-dashboard` nel namespace `prod`
- mostra l’URL del Load Balancer generato dal servizio

Questa modalità è utile quando vuoi partire rapidamente e lasciare che il progetto gestisca i percorsi locali in modo automatico, configurando solo la cartella di lavoro del repository e il contesto AWS attivo.

### 4.3. Configurazione del backend Terraform

Il backend S3 è necessario per mantenere lo stato Terraform remoto.

File `backend.hcl` di esempio:

```hcl
bucket       = "sentinelgrid-tfstate"
key          = "prod/terraform.tfstate"
region       = "eu-west-1"
encrypt      = true
use_lockfile = true
```

Comando di inizializzazione:

```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
```

Nota:
- il bucket S3 deve esistere
- la regione deve corrispondere alla regione AWS di deploy
- `dynamodb_table` o lock table va configurato se usato

### 4.4. Provisioning infrastruttura con Terraform

Entra nella cartella Terraform e inizializza lo stato remoto:

```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
terraform validate
terraform fmt
terraform plan
terraform apply -auto-approve
```

Se vuoi usare altri ambienti, apri la cartella del relativo ambiente e ripeti i comandi:

```bash
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan
terraform apply -auto-approve
```

Verifica che la base infrastrutturale sia stata creata:

- VPC
- subnet pubbliche/private
- security groups
- IAM roles
- EKS cluster
- node group
- repository ECR

### 4.5. Configurazione kubeconfig

Dopo il provisioning del cluster EKS:

```bash
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name sentinelgrid-eks-cluster \
  --profile <profile-name>
```

Verifica il contesto Kubernetes:

```bash
kubectl config get-contexts
kubectl get nodes
```

### 4.6. Deploy applicativo tramite pipeline CI/CD

Il flusso consigliato è:

1. push del codice su GitHub
2. trigger della pipeline
3. CodeBuild compila le immagini Docker
4. immagini pushate su Amazon ECR
5. Kubernetes applica i manifest del namespace `prod`

Esempio di buildspec:

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Logging in to Amazon ECR"
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

  build:
    commands:
      - echo "Building Docker image"
      - docker build -t $REPOSITORY_URI:$IMAGE_TAG .
      - docker push $REPOSITORY_URI:$IMAGE_TAG
```

### 4.7. Verifica dei pod

Dopo il deploy, verifica che i microservizi siano online nel namespace `prod`:

```bash
kubectl get ns
kubectl get pods -n prod
kubectl get svc -n prod
kubectl get deployments -n prod
kubectl get cronjobs -n prod
```

Controllo dettagliato:

```bash
kubectl describe pod <pod-name> -n prod
kubectl logs <pod-name> -n prod
```

Output atteso:

```bash
NAME                              READY   STATUS    RESTARTS   AGE
beacon-api-xxxx-xxxx               1/1     Running   0          2m
command-api-xxxx-xxxx              1/1     Running   0          2m
command-api-yyyy-yyyy              1/1     Running   0          2m
ops-dashboard-xxxx-xxxx            1/1     Running   0          2m
ops-dashboard-yyyy-yyyy            1/1     Running   0          2m
triage-worker-xxxx-xxxx            1/1     Completed 0          5m
```

---

## 5. Personalizzazione di variabili e manifest

### 5.1. File `terraform.tfvars`

Un esempio di file `terraform.tfvars` personalizzabile:

```hcl
environment   = "prod"
aws_region    = "eu-west-1"
CentroDiCosto = "CloudLab_Campus"
vpc_cidr      = "10.0.0.0/16"

subnets = {
  "public-1" = {
    cidr = "10.0.1.0/24"
    az   = "eu-west-1a"
  }
  "public-2" = {
    cidr = "10.0.2.0/24"
    az   = "eu-west-1b"
  }
  "private-1" = {
    cidr = "10.0.10.0/24"
    az   = "eu-west-1a"
  }
  "private-2" = {
    cidr = "10.0.11.0/24"
    az   = "eu-west-1b"
  }
}
```

### 5.2. ConfigMap e Secret Kubernetes

I manifest Kubernetes possono essere resi personalizzabili con variabili di ambiente

Esempio ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${CONFIGMAP_NAME}
  namespace: ${K8S_NAMESPACE}
data:
  APP_ENV: "${APP_ENV}"
  LOG_LEVEL: "${LOG_LEVEL}"
  BEACON_API_URL: "${BEACON_API_URL}"
  COMMAND_API_URL: "${COMMAND_API_URL}"
```

Esempio Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${SECRET_NAME}
  namespace: ${K8S_NAMESPACE}
type: Opaque
stringData:
  API_KEY: "${API_KEY}"
  BEACON_API_KEY: "${BEACON_API_KEY}"
```

### 5.3. Namespace e ambiente personalizzabili

Se fai un deploy in un ambiente differente, bisogna mantenere i file manifest e i valori coerenti con lo stesso nome di namespace e i corrispondenti valori di configurazione.

---

## 6. Destroy / Cleanup (zero costi AWS)

Per evitare costi inutili, esegui i passaggi in ordine.

### 6.1. Eliminare namespace K8s

```bash
kubectl delete ns prod
```

Verifica la rimozione:

```bash
kubectl get ns
kubectl get pvc -A
kubectl get svc -A
```

### 6.2. Distruggere l’infrastruttura Terraform

```bash
cd terraform/environments/prod
terraform destroy -auto-approve
```

### 6.3. Cleanup contesto locale kubectl

```bash
kubectl config current-context
kubectl config delete-context <cluster-name>
kubectl config delete-cluster <cluster-name>
kubectl config unset current-context
```

---

## 7. Troubleshooting & errori comuni

### Errore 1: Tag immagine errato `invalid reference format` in CodeBuild

Sintomo:
- build fallisce con `invalid reference format`
- repo tag non valido

Causa:
- `$CODEBUILD_SOURCE_VERSION` può restituire un ARN invece di un hash Git

Soluzione:

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Preparing image tag..."
      - |
        export SOURCE_VERSION="${CODEBUILD_SOURCE_VERSION}"
        if echo "$SOURCE_VERSION" | grep -q '^arn:'; then
          echo "Detected ARN source version; using Git HEAD instead"
          export IMAGE_TAG="$(git rev-parse HEAD | cut -c1-12)"
        else
          export IMAGE_TAG="${SOURCE_VERSION:0:12}"
        fi
        echo "IMAGE_TAG=$IMAGE_TAG"

  build:
    commands:
      - docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG .
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
```

---

### Errore 2: StorageClass incompatibile (`gp2` vs `standard`)

Sintomo:
- PVC in `Pending`
- pod in `CrashLoopBackOff`
- readiness probe fallisce

Causa:
- StorageClass incompatibile tra cluster locale e cluster AWS

Soluzione:

```bash
kubectl get storageclass
kubectl describe pvc <pvc-name> -n prod
```

Esempio EKS:

```yaml
spec:
  storageClassName: gp2
```

Esempio Minikube:

```yaml
spec:
  storageClassName: standard
```

---

### Errore 3: Permessi CloudWatch Logs disabilitati su CodeBuild (`ACCESS_DENIED`)

Sintomo:
- CodeBuild fallisce durante l’esecuzione
- log non visibili

Causa:
- ruolo IAM del progetto CodeBuild senza permessi `logs:*`

Policy esempio:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

---

### Errore 4: CronJob `triage-worker` finisce in `NotFound`

Sintomo:
- il pod del cronjob scompare dopo il completamento

Causa:
- Kubernetes rimuove i pod completati dopo il job

Soluzione:

```bash
kubectl get pods -n prod \
  --sort-by=.metadata.creationTimestamp \
  -l app=triage-worker \
  -o jsonpath='{.items[-1:].metadata.name}{"\n"}'

kubectl logs -n prod \
  "$(kubectl get pods -n prod --sort-by=.metadata.creationTimestamp -l app=triage-worker -o jsonpath='{.items[-1:].metadata.name}')"
```

---

### Errore 5: Backend Terraform S3 non inizializzato o configurato in modo incoerente

Sintomo:
- `terraform init` fallisce
- `No valid credential sources found`
- `AccessDenied`
- `NoSuchBucket`

Causa:
- backend remote non inizializzato correttamente oppure credenziali AWS mancanti

Soluzione:

```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
aws sts get-caller-identity
aws s3 ls
```

---

## 8. Comandi utili di verifica

### Verifica cluster e nodi

```bash
kubectl get nodes
kubectl get all -n prod
kubectl get ns
```

### Verifica servizi e deployment

```bash
kubectl get deployments -n prod
kubectl get svc -n prod
kubectl get ingress -A
```

### Verifica PVC e storage

```bash
kubectl get pvc -n prod
kubectl get pv
kubectl describe pvc <pvc-name> -n prod
```

### Verifica eventi

```bash
kubectl get events -n prod --sort-by=.metadata.creationTimestamp
```