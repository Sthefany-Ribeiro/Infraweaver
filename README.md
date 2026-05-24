# InfraWeaver

> Plataforma de self-service de infraestrutura — provisiona ambientes completos na AWS com um único comando.

![CI](https://github.com/Sthefany-Ribeiro/Infraweaver/actions/workflows/ci.yml/badge.svg)
![Deploy](https://github.com/Sthefany-Ribeiro/Infraweaver/actions/workflows/deploy.yml/badge.svg)

---

## Stack

| Camada | Tecnologia |
|--------|-----------|
| App | Node.js + Express |
| Container | Docker + Docker Compose |
| Orquestração | Kubernetes (EKS) |
| IaC | Terraform (modular) |
| Config Management | Ansible |
| Package Manager K8s | Helm |
| CI/CD | GitHub Actions |
| Cloud | AWS (ECR, EKS, RDS, VPC, NAT Gateway) |

---

## Arquitetura

```
GitHub Push
     │
     ▼
GitHub Actions ── CI ──► test → build → push ECR
     │
     ▼
GitHub Actions ── Deploy ──► helm upgrade → EKS
     │
     ▼
Internet → ALB → Ingress → Service → Pods (EKS)
                                          │
                                          ▼
                                   RDS PostgreSQL
```

---

## Estrutura do Repositório

```
infraweaver/
├── app/
│   ├── src/
│   │   ├── index.js          # Entry point da API
│   │   └── routes.js         # Endpoints REST
│   ├── tests/
│   │   └── app.test.js       # Testes Jest + Supertest
│   ├── Dockerfile            # Imagem Node.js Alpine
│   └── package.json
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/              # VPC, subnets, IGW, NAT
│   │   ├── eks/              # Cluster + node group + IAM
│   │   └── rds/              # PostgreSQL + subnet group + SG
│   └── envs/
│       ├── dev/              # Backend S3 + tfvars dev
│       ├── staging/
│       └── prod/
│
├── ansible/
│   ├── roles/
│   │   ├── bootstrap/        # kubectl, helm, kubeconfig
│   │   └── app-deploy/       # Deploy via Helm
│   ├── inventory/
│   │   ├── dev.ini
│   │   └── staging.ini
│   └── playbook.yml
│
├── helm/
│   └── infraweaver/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           └── ingress.yaml
│
└── .github/
    └── workflows/
        ├── ci.yml            # Test + Build + Push ECR
        └── deploy.yml        # Helm deploy no EKS
```

---

## Pré-requisitos

- AWS CLI configurado (`aws configure`)
- Terraform >= 1.0
- kubectl
- Helm >= 3.0
- Ansible >= 2.16
- Docker

---

## Como usar

### 1. Clonar o repositório

```bash
git clone https://github.com/Sthefany-Ribeiro/Infraweaver.git
cd Infraweaver
```

### 2. Criar backend do Terraform

```bash
# Bucket S3 para state
aws s3api create-bucket \
  --bucket infraweaver-tfstate-<seu-account-id> \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

# Tabela DynamoDB para lock
aws dynamodb create-table \
  --table-name infraweaver-tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-west-2
```

### 3. Provisionar infraestrutura

```bash
cd terraform/envs/dev
terraform init
terraform plan
terraform apply
```

Recursos criados:
- VPC com 2 subnets públicas e 2 privadas
- NAT Gateway
- EKS Cluster (Kubernetes 1.31) com 2x t3.medium
- RDS PostgreSQL 15.12 (db.t3.micro)

### 4. Configurar kubectl

```bash
aws eks update-kubeconfig \
  --name infraweaver-dev \
  --region us-west-2

kubectl get nodes
```

### 5. Bootstrap com Ansible

```bash
ansible-playbook ansible/playbook.yml \
  -i ansible/inventory/dev.ini \
  --tags bootstrap \
  -v
```

O playbook instala kubectl, Helm e configura o kubeconfig automaticamente.

### 6. Build e push da imagem

```bash
# Criar repositório ECR
aws ecr create-repository \
  --repository-name infraweaver \
  --region us-west-2

# Autenticar e fazer push
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS \
  --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

docker build -t infraweaver ./app
docker tag infraweaver:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/infraweaver:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/infraweaver:latest
```

### 7. Deploy da aplicação

```bash
kubectl create namespace infraweaver

helm upgrade --install infraweaver helm/infraweaver \
  --namespace infraweaver \
  --wait --timeout 5m

kubectl get pods -n infraweaver
```

### 8. Destruir infraestrutura

```bash
cd terraform/envs/dev
terraform destroy
```

> **Importante**: sempre destrua a infra quando não estiver usando para evitar custos desnecessários.

---

## CI/CD

O pipeline é composto por dois workflows:

### ci.yml — disparado a cada push na `main`

```
push → main
  └── test (Node.js, Jest)
        └── build (Docker build + push ECR)
```

### deploy.yml — disparado após CI com sucesso

```
CI success
  └── update-kubeconfig
        └── helm upgrade → EKS
              └── kubectl get pods (verificação)
```

### Secrets necessários no GitHub

| Secret | Descrição |
|--------|-----------|
| `AWS_ACCESS_KEY_ID` | Access key da AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret key da AWS |
| `AWS_ACCOUNT_ID` | ID da conta AWS |

---

## Decisões técnicas

### Terraform vs Ansible

O Terraform gerencia recursos **imutáveis** — VPC, EKS, RDS, IAM. São recursos que raramente mudam e cuja criação/destruição é controlada via state.

O Ansible gerencia **configuração** — instalação de ferramentas nos nodes, kubeconfig, deploy da aplicação. São operações idempotentes que podem rodar múltiplas vezes com segurança.

### Helm

Gerencia releases Kubernetes com suporte a rollback, versionamento e sobrescrita de values por ambiente. Um único chart serve dev, staging e prod com values diferentes.

### Backend remoto S3 + DynamoDB

O state do Terraform fica no S3 com versionamento habilitado. O DynamoDB garante lock de estado — impede que dois `terraform apply` rodem simultaneamente em equipe.

### Módulos Terraform

Cada módulo (vpc, eks, rds) é reutilizável entre ambientes. O env `dev` passa variáveis diferentes do `prod` — como `multi_az = true` apenas em produção.

---

## API Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/health` | Health check |
| GET | `/api/environments` | Lista ambientes |
| POST | `/api/environments` | Cria ambiente |
| DELETE | `/api/environments/:id` | Destroi ambiente |

### Exemplo

```bash
# Health check
curl http://localhost:3000/health

# Criar ambiente
curl -X POST http://localhost:3000/api/environments \
  -H "Content-Type: application/json" \
  -d '{"name": "dev-test", "type": "development"}'

# Listar ambientes
curl http://localhost:3000/api/environments
```

---

## Custo estimado (ambiente dev, us-west-2)

| Recurso | Instância | Custo/hora |
|---------|-----------|-----------|
| EKS Control Plane | — | $0.10 |
| Nodes (x2) | t3.medium | $0.083 |
| RDS | db.t3.micro | $0.017 |
| NAT Gateway | — | $0.045 |
| **Total** | | **~$0.25/hora** |

---

## Autor

**Sthefany Ribeiro**
[GitHub](https://github.com/Sthefany-Ribeiro) · [LinkedIn](https://linkedin.com/in/sthefany-ribeiro)
