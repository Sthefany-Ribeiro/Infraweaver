# Observabilidade

Stack instalada via Helm no namespace `monitoring` do EKS.

## Componentes

- **Prometheus** — coleta métricas do cluster e pods
- **Grafana** — dashboards em tempo real
- **Alertmanager** — gerenciamento de alertas
- **kube-state-metrics** — métricas de estado dos recursos K8s
- **node-exporter** — métricas dos nodes EC2

## Instalação

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm upgrade --install prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=SuaSenha \
  --set prometheus.prometheusSpec.retention=7d \
  --wait --timeout 10m
```

## Acesso ao Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 8080:80
```

Acessa: http://localhost:8080  
Usuário: `admin`

## Dashboards importados

- `15760` — Kubernetes / Views / Pods
- `6417` — Kubernetes / Views / Namespaces

## Métricas capturadas em produção

| Métrica | Valor |
|---------|-------|
| Pods running | 2 |
| CPU por pod | ~0.08% |
| RAM por pod | ~13 MiB |
| Nodes | 2x t3.medium Ready |
