# SentinelGrid

SentinelGrid è un progetto AWS EKS orientato a microservizi per la gestione e la sorveglianza di applicazioni containerizzate in produzione. L’architettura prevede un cluster EKS con namespace `prod`, deployment di microservizi, storage persistente, cronjob per processi batch e integrazione con ECR, CodeBuild e CI/CD.

## Panoramica architettura

- Cluster EKS con namespace `prod`
- Microservizi:
  - `beacon-api`
  - `command-api`
  - `ops-dashboard`
  - `triage-worker`
- Registry immagini: Amazon ECR
- Pipeline CI/CD: GitHub → CodeBuild → ECR → Kubernetes
- Storage: EBS via PVC/StorageClass
- Monitoring: CloudWatch Logs
- Job/cronjob: `triage-worker` per task schedulati

---

## Prerequisiti

Prima di iniziare, assicurati di avere installato e configurato correttamente:

- AWS CLI
- Terraform
- kubectl
- Accesso AWS con privilegi sufficienti
- Un account AWS con permessi per:
  - EKS
  - ECR
  - IAM
  - VPC
  - CloudWatch Logs
  - EC2 / ELB / EBS

Controlla installazione e versioni:

```bash
aws --version
terraform version
kubectl version --client
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

## Deploy da zero

### 1) Clonare il repository e preparare il workspace

```bash
git clone <repo-url>
cd SentinelGrid
ls -la
```

### 2) Provisioning infrastruttura con Terraform

Entra nella cartella Terraform e inizializza il backend/provider:

```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform validate
terraform fmt
terraform plan
terraform apply -auto-approve
```

Se il progetto usa ambienti multipli:

```bash
terraform workspace list
terraform workspace select dev
terraform plan
terraform apply -auto-approve
```

Verifica che l’infrastruttura venga creata correttamente:
- VPC
- EKS cluster
- NodeGroups
- IAM roles
- ECR repositories
- Security groups
- IAM policies

---

### 3) Configurazione kubeconfig per il cluster EKS

Dopo il provisioning, aggiorna il file di configurazione di kubectl:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name <cluster-name> \
  --profile <profile-name>
```

Verifica il contesto Kubernetes:

```bash
kubectl config get-contexts
kubectl get nodes
```

---

### 4) Deploy applicativo con pipeline CI/CD

Il flusso consigliato è:

1. Push del codice su Git
2. Trigger pipeline CI/CD
3. CodeBuild:
   - installa dipendenze
   - costruisce le immagini Docker
   - tagga le immagini con hash Git o branch
   - push su Amazon ECR
4. Manifest Kubernetes applicati automaticamente
5. Deployment del namespace `prod`

Esempio di struttura pipeline:

```yaml
version: 0.2

phases:
  install:
    commands:
      - echo "Install dependencies"
      - pip install --upgrade pip

  pre_build:
    commands:
      - echo "Logging in to Amazon ECR"
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

  build:
    commands:
      - echo "Building Docker images"
      - docker build -t $REPOSITORY_URI:$IMAGE_TAG .
      - docker push $REPOSITORY_URI:$IMAGE_TAG

  post_build:
    commands:
      - echo "Build completed"
      - printf '%s\n' "$REPOSITORY_URI:$IMAGE_TAG" > imageTag.txt
```

In genere il deployment finale avviene tramite:
- CodePipeline + CodeBuild
- Helm o `kubectl apply -f k8s/`
- GitOps con manifest in repository

---

### 5) Verifica stato dei pod

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

Se tutto è corretto, il comando atteso è:

```bash
kubectl get pods -n prod
```

Output tipico:

```bash
NAME                              READY   STATUS    RESTARTS   AGE
beacon-api-xxxx-xxxx              1/1     Running   0          2m
command-api-xxxx-xxxx            1/1     Running   0          2m
ops-dashboard-xxxx-xxxx          1/1     Running   0          2m
triage-worker-xxxx-xxxx          1/1     Completed 0          5m
```

---

## Flusso di ripristino dopo `terraform destroy`

Se preferisci non modificare Terraform per ora ed eseguire un `terraform destroy` seguito da `terraform apply`, questa è la sequenza esatta da eseguire per sistemare il cluster ricreato.

### 1) Ricreazione infrastruttura

```bash
terraform apply -auto-approve
aws eks update-kubeconfig --region eu-west-1 --name sentinelgrid-eks-cluster
```

### 2) Abilitazione OIDC e creazione ServiceAccount IAM (IRSA)

Esegue direttamente questo comando prima del deploy dell’app:

```bash
eksctl utils associate-iam-oidc-provider --cluster sentinelgrid-eks-cluster --approve --region eu-west-1

eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster sentinelgrid-eks-cluster \
  --role-name AmazonEKS_EBS_CSI_DriverRole_SentinelGrid \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --override-existing-serviceaccounts \
  --approve \
  --region eu-west-1
```

### 3) Installazione dell’add-on EBS legato al ruolo

```bash
aws eks create-addon \
  --cluster-name sentinelgrid-eks-cluster \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::889276611436:role/AmazonEKS_EBS_CSI_DriverRole_SentinelGrid \
  --region eu-west-1
```

### 4) Registrazione accesso per CodePipeline/CodeBuild

```bash
export PIPELINE_ROLE_ARN=$(aws codepipeline get-pipeline --name $(aws codepipeline list-pipelines --region eu-west-1 --query "pipelines[?contains(name, 'Sentinel')].name | [0]" --output text) --region eu-west-1 --query "pipeline.roleArn" --output text)

aws eks create-access-entry --cluster-name sentinelgrid-eks-cluster --principal-arn $PIPELINE_ROLE_ARN --region eu-west-1
aws eks associate-access-policy --cluster-name sentinelgrid-eks-cluster --principal-arn $PIPELINE_ROLE_ARN --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --region eu-west-1
```

> Nota: questa sequenza è utile quando si vuole ripristinare rapidamente il cluster senza modificare la configurazione Terraform attuale, ma mantiene il corretto setup di storage, IRSA e accessi di pipeline.

---

## Destroy / Cleanup (zero costi AWS)

Per evitare costi inutili, esegui i passaggi in ordine.

### Step 1: Eliminazione namespace K8s

Questo rilasciano ELB, EBS e altri asset cloud collegati al namespace `prod`:

```bash
kubectl delete ns prod
```

Verifica la rimozione:

```bash
kubectl get ns
kubectl get pvc -A
kubectl get svc -A
```

---

### Step 2: Svuotamento repository ECR via CLI

Elenca le immagini presenti:

```bash
aws ecr describe-repositories --region us-east-1
aws ecr list-images --repository-name <repo-name> --region us-east-1
```

Cancella tutte le immagini:

```bash
aws ecr batch-delete-image \
  --repository-name <repo-name> \
  --region us-east-1 \
  --image-ids "$(aws ecr list-images --repository-name <repo-name> --region us-east-1 --query 'imageIds[*]' --output json)"
```

Alternativa più controllata:

```bash
aws ecr list-images --repository-name <repo-name> --region us-east-1 --query 'imageIds[*]' --output json > images.json
aws ecr batch-delete-image --repository-name <repo-name> --region us-east-1 --image-ids file://images.json
```

Se necessario, elimina poi il repository:

```bash
aws ecr delete-repository \
  --repository-name <repo-name> \
  --region us-east-1 \
  --force
```

---

### Step 3: Distruzione infrastruttura Terraform

Nel percorso della configurazione Terraform:

```bash
cd terraform
terraform destroy -auto-approve
```

Se usi workspace multipli:

```bash
terraform workspace select dev
terraform destroy -auto-approve
```

---

### Step 4: Cleanup contesto locale kubectl

Rimuovi il contesto e il cluster dal file `kubeconfig` locale:

```bash
kubectl config current-context
kubectl config delete-context <cluster-name>
kubectl config delete-cluster <cluster-name>
kubectl config unset current-context
```

Verifica che venga pulito:

```bash
kubectl config get-contexts
kubectl config view --minify
```

---

## Troubleshooting & errori comuni

### Errore 1: Tag immagine errato `invalid reference format` in CodeBuild

Sintomo:
- Il build di CodeBuild fallisce con messaggio del tipo:
  - `invalid reference format`
  - `repository name must be lowercase`
  - `invalid tag format`

Causa:
- `$CODEBUILD_SOURCE_VERSION` non restituisce sempre l’hash Git corretto.
- In alcuni setup (es. GitHub App o source provider diversi), il valore restituito può essere un ARN o un riferimento diverso dal commit SHA.
- La pipeline usa quel valore come tag immagine (`:arn:...` o stringhe non valide), causando il fallimento del push verso ECR.

Soluzione:
- Usare un fallback robusto che trasformi in SHA Git reale quando `CODEBUILD_SOURCE_VERSION` è un ARN.
- Se l’ARN viene restituito, eseguire un `git rev-parse HEAD` per ottenere un tag valido.

Snippet YAML di fallback per `buildspec.yml`:

````yaml
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
      - echo "Building image"
      - docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG .
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO:$IMAGE_TAG
````

Best practice:
- Evita di usare `CODEBUILD_SOURCE_VERSION` come tag diretto senza normalizzazione.
- Preferisci `git rev-parse HEAD` se il repository è git-based.
- Mantieni sempre tag in formato valido come `a1b2c3d4e5f6`.

---

### Errore 2: StorageClass incompatibile (`gp2` AWS vs `standard` Minikube) e blocco a cascata dei Readiness Probe

Sintomo:
- PVC in `Pending`
- Pod in `CrashLoopBackOff`
- Deployment in `Ready = 0/1` o `ContainerCreating`
- Readiness Probe continua a fallire perché il volume non viene montato correttamente
- In ambiente locale Minikube si vede `standard`, mentre su EKS default è `gp2`

Causa:
- Il manifest dei PVC o dei `values.yaml` usa un StorageClass non valido nel target cluster.
- Su Minikube: `standard`
- Su AWS EKS: `gp2` oppure un StorageClass custom
- Se il pod richiede un volume persistente che non viene provisionato, si blocca il readiness e tutti i servizi dipendenti non diventano pronti.

Soluzione:
- Verifica il StorageClass disponibile:

```bash
kubectl get storageclass
kubectl describe pvc <pvc-name> -n prod
```

- Allineare il `storageClassName` al cluster di destinazione.

Esempio corretto per EKS:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: beacon-data
  namespace: prod
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 10Gi
```

Esempio per Minikube:

```yaml
spec:
  storageClassName: standard
```

Se il cluster non usa StorageClass dinamico:
- rimuovere `storageClassName` oppure usare uno valido
- verificare se il PVC è stato creato correttamente
- verificare i `ReadinessProbe` e il mount path

---

### Errore 3: Permessi CloudWatch Logs disabilitati su CodeBuild (`ACCESS_DENIED`)

Sintomo:
- CodeBuild fallisce durante l’esecuzione
- Log in CloudWatch non disponibili
- Errori del tipo:
  - `AccessDeniedException`
  - `User is not authorized to perform logs:CreateLogStream`
  - `User is not authorized to perform logs:PutLogEvents`

Causa:
- Il ruolo IAM assegnato al progetto CodeBuild non ha policy sufficienti per scrivere log su CloudWatch Logs.

Soluzione:
- Aggiungere una policy IAM inline o managed al ruolo di CodeBuild.

Policy IAM inline consigliata:

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

Collegare la policy al servizio IAM usato dal progetto CodeBuild e riavviare la build.

Verifica con:

```bash
aws iam list-attached-role-policies --role-name <codebuild-role-name>
```

---

### Errore 4: Pods del CronJob (`triage-worker`) vanno in `NotFound` dopo il completamento

Sintomo:
- I pod del cronjob finiscono il lavoro e poi scompaiono
- `kubectl get pods -n prod` mostra `NotFound` o il pod non è più disponibile dopo l’esecuzione
- Il job è completato ma si vuole recuperare l’ultimo pod per leggere i log

Causa:
- Kubernetes CronJob cancella automaticamente i pod completati dopo il completamento del job, per mantenere lo stato di clean-up.
- Il nome del pod è dinamico e non sempre immediatamente evidente.

Soluzione:
- Recuperare l’ultimo pod usando `jsonpath`
- Leggere i log dell’ultimo pod completato

Comando per ottenere l’ultimo pod del cronjob:

```bash
kubectl get pods -n prod \
  --sort-by=.metadata.creationTimestamp \
  -l app=triage-worker \
  -o jsonpath='{.items[-1:].metadata.name}{"\n"}'
```

Comando per leggere i log dell’ultimo pod:

```bash
kubectl logs -n prod \
  "$(kubectl get pods -n prod --sort-by=.metadata.creationTimestamp -l app=triage-worker -o jsonpath='{.items[-1:].metadata.name}')"
```

Per vedere l’ultimo job:

```bash
kubectl get jobs -n prod
kubectl describe job <job-name> -n prod
```

Se vuoi mantenere la cronologia dei log per debugging, usa:
- `kubectl get events -n prod --sort-by=.metadata.creationTimestamp`
- `kubectl logs --previous <pod-name> -n prod`

---

### Errore 5: Backend Terraform S3 non inizializzato o configurato in modo incoerente

Sintomo:
- `terraform init` fallisce oppure si blocca sul backend S3
- `terraform plan` e `terraform apply` non riescono a collegarsi allo stato remoto
- Si vedono messaggi del tipo:
  - `Error: Backend configuration changed`
  - `No valid credential sources found`
  - `AccessDenied`
  - `NoSuchBucket`
  - `error configuring S3 Backend: no valid credentials`
  - `Failed to get existing workspaces: access denied`

Causa:
- Il backend Terraform è stato definito in `versions.tf` tramite `backend "s3" {}` ma non è stato inizializzato correttamente con i parametri del file `backend.hcl`.
- In pratica, il problema non è il contenuto di `terraform.tfvars`, ma la configurazione del backend remoto e dell’accesso AWS.
- Tra le cause più comuni:
  - bucket S3 non esiste
  - bucket S3 non è in regione corretta
  - profile AWS o credenziali non configurati
  - lock table assente o permessi insufficienti
  - `terraform init` eseguito senza `-backend-config=backend.hcl`

Esempio di configurazione attesa nel backend:

```hcl
bucket       = "sentinelgrid-tfstate"
key          = "prod/terraform.tfstate"
region       = "eu-west-1"
encrypt      = true
use_lockfile = true
```

Soluzione:
- Assicurarsi che il bucket S3 esista e che il nome coincidida con il file `backend.hcl`.
- Verificare la regione AWS corretta.
- Eseguire `terraform init` passando il file di configurazione del backend:

```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
```

- Verifica dei credenziali AWS:

```bash
aws sts get-caller-identity
aws s3 ls
```

- Se si usa un profilo diverso:

```bash
export AWS_PROFILE=<profile-name>
export AWS_REGION=eu-west-1
```

- Eseguire la validazione finale:

```bash
terraform validate
terraform plan
```

Best practice:
- usare sempre `terraform init -backend-config=backend.hcl` quando il backend è remoto
- tenere separati backend per ambiente (`dev`, `prod`, `stage`)
- assicurarsi che il bucket e la lock table siano creati prima del primo `init`
- non usare `terraform.tfvars` come soluzione al problema del backend: è un problema di stato remoto e auth AWS, non di valori applicativi

---

## Comandi utili di verifica

### Verifica cluster e nodi

```bash
kubectl get nodes
kubectl get all -n prod
kubectl get ns
```

### Verifica deployment e servizi

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

---

## Checklist finale

Prima di dichiarare il progetto pronto in produzione, verifica:

- [ ] Terraform eseguito correttamente
- [ ] Cluster EKS accessibile tramite `kubectl`
- [ ] Namespace `prod` creato
- [ ] Pod in `Running`
- [ ] Service e LoadBalancer creati
- [ ] ECR repository con immagini pushate
- [ ] CodeBuild/CodePipeline configurati
- [ ] CloudWatch Logs abilitati
- [ ] StorageClass compatibile con il cluster
- [ ] CronJob `triage-worker` eseguito correttamente
- [ ] Cleanup procedure pronte per zero costi

---

## Personalizzazione di backend, variabili e secret

Questa sezione serve a rendere il progetto facilmente personalizzabile senza modificare i file di configurazione già in uso, ma mantenendo un pattern chiaro da adattare in base all’ambiente e alle credenziali di deployment.

### 1) Backend Terraform (`backend.hcl`)

Il backend S3 è il punto di partenza per la persistenza dello stato Terraform. È consigliabile personalizzare bucket, regione e chiave di stato in base al team o all’ambiente.

Esempio di file `backend.hcl`:

```hcl
bucket       = "sentinelgrid-tfstate"
key          = "prod/terraform.tfstate"
region       = "eu-west-1"
encrypt       = true
use_lockfile = true
```

Comando di inizializzazione:

```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
```

Nota:
- `bucket` deve essere un bucket S3 dedicato allo stato Terraform
- `key` permette di separare gli ambienti (`dev`, `prod`, `stage`)
- `region` deve coincidere con la regione AWS di deploy

---

### 2) Variabili Terraform (`terraform.tfvars`)

Le variabili di ambiente dovrebbero essere centralizzate in un file `.tfvars` per semplificare la personalizzazione. In questo modo è possibile adattare il progetto a differenti clienti, team o ambienti senza toccare il codice Terraform.

Esempio `terraform.tfvars`:

```hcl
environment   = "prod"
aws_region    = "eu-west-1"
CentroDiCosto = "CloudLab_Campus"
project_name  = "sentinelgrid"
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

Se vuoi maggior flessibilità, è consigliabile estendere le variabili con campi come:

```hcl
cluster_version = "1.31"
node_instance_type = "t3.medium"
node_desired_size = 2
node_min_size = 1
node_max_size = 3
project_name = "sentinelgrid"
owner = "platform-team"
```

Questo rende il deployment più facilmente riutilizzabile e mantenibile tra ambienti diversi.

---

### 3) Personalizzazione di ConfigMap e Secret Kubernetes

Anche i manifest Kubernetes possono essere dichiarati in modo configurabile usando placeholder e injection mediante variabili di ambiente, file `.env` o strumenti come `envsubst`/Helm/Kustomize.

Esempio di ConfigMap personalizzabile:

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

Esempio di Secret personalizzabile:

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

Per renderli pronti al deploy, si può usare un approccio come questo:

```bash
export K8S_NAMESPACE=prod
export CONFIGMAP_NAME=sentinel-config
export SECRET_NAME=sentinel-secret
export APP_ENV=prod
export LOG_LEVEL=info
export BEACON_API_URL=http://beacon-api:8080
export COMMAND_API_URL=http://command-api:8080
export API_KEY=my-super-secret-key
export BEACON_API_KEY=my-super-secret-key

envsubst < k8s/configmaps/config.yaml | kubectl apply -f -
envsubst < k8s/secrets/secret.yaml | kubectl apply -f -
```

Best practice:
- non committare secret reali nel repository
- usare GitHub Actions, AWS Secrets Manager o Kubernetes Secrets gestiti centralmente
- separare valori per ambiente (`dev`, `prod`, `stage`)
- usare un file `.env` locale o secret store per le credenziali

---

### 4) Esempio di file `.env` per il deploy

```env
AWS_REGION=eu-west-1
K8S_NAMESPACE=prod
CONFIGMAP_NAME=sentinel-config
SECRET_NAME=sentinel-secret
APP_ENV=prod
LOG_LEVEL=info
BEACON_API_URL=http://beacon-api:8080
COMMAND_API_URL=http://command-api:8080
API_KEY=changeme
BEACON_API_KEY=changeme
```

Questo pattern permette di mantenere configurazione, credenziali e ambiente separati dal codice applicativo e dai manifest Kubernetes.

---

## Conclusione

SentinelGrid è un esempio completo di architettura EKS con microservizi, pipeline CI/CD e best practice DevOps su AWS. L’adozione corretta di Terraform, ECR, CodeBuild, Kubernetes e verifiche di runtime è fondamentale per evitare errori di deploy, problemi di storage e blocchi nei readiness probe. Con la corretta gestione del namespace, del cleanup AWS e dei log di build, il progetto può essere mantenuto in modo stabile e sicuro.
