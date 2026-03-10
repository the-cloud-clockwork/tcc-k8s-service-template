# Kubernetes Service Template Helm Chart

A production-ready Helm chart for deploying applications on Kubernetes with advanced multi-deployment, multi-database, and multi-ingress capabilities.

## Brand-Agnostic Design

This chart is designed to be **organization and team agnostic**. It contains no references to specific companies, teams, or brands, making it suitable for adoption by any organization.

### Customization Placeholders

When adopting this chart, update the following placeholders:

**Chart.yaml:**

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `your-org` | Your GitHub organization or company name | `acme-corp`, `my-company` |
| `platform-team@your-org.com` | Maintainer contact email | `devops@acme-corp.com` |

**tasks/helm.py:**

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `your-artifactory.example.com` | Your Artifactory or Helm registry URL | `artifactory.acme-corp.com` |
| `your-org` | Helm repo alias | `acme` |
| `your-org-ephemeral` | Dev/ephemeral Helm repo alias | `acme-ephemeral` |

### Node Selector / Toleration Examples

The `values.yaml` file contains example node selectors and tolerations using `your-team` as a placeholder. Replace with your actual tenant/team names:

```yaml
# Before (placeholder)
nodeSelector:
  tenant: your-team

tolerations:
  - key: "tenant"
    value: "your-team"

# After (customized)
nodeSelector:
  tenant: backend-services

tolerations:
  - key: "tenant"
    value: "backend-services"
```

## 🎯 What Can This Chart Do?

This chart helps you deploy complex Kubernetes applications with:

- **Multiple Deployments** - Master/worker patterns with independent scaling
- **Multiple Databases** - Redis, PostgreSQL, MySQL, MongoDB with custom passwords
- **Multiple Ingresses** - Different entry points with different configurations
- **Auto-scaling** - Per-deployment HPA with custom behavior
- **Secret Management** - Vault integration + external secrets
- **Production-Ready** - PDBs, network policies, monitoring

## 🚀 Quick Examples

### Simple Web Application

```yaml
app:
  name: "my-api"
  image:
    repository: "myregistry/api"
    tag: "1.0.0"
  replicaCount: 3
  container:
    port: 8080

service:
  enabled: true
  port: 80

ingress:
  enabled: true
  hosts:
    - host: "api.example.com"
```

### Master/Worker Queue System

```yaml
# Master (web UI + coordinator)
app:
  name: "n8n"
  replicaCount: 1
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi

# Workers (background processing)
deployments:
  worker:
    enabled: true
    replicaCount: 5
    command: ["n8n", "worker"]
    service:
      enabled: false  # No external access
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 20

# Queue backend
databases:
  queue:
    enabled: true
    type: redis
    resources:
      limits:
        cpu: 6000m
        memory: 6Gi
```

## 💾 Multiple Database StatefulSets

Deploy multiple independent database instances:

```yaml
databases:
  # Redis for queue
  queue:
    enabled: true
    type: redis
    # Uses default REDIS_PASSWORD from secret

    resources:
      limits:
        cpu: 6000m
        memory: 6Gi

    persistence:
      enabled: true
      size: 10Gi
      storageClass: "gp3"

  # Redis for cache (different password)
  cache:
    enabled: true
    type: redis
    passwordSecretKey: "CACHE_PASSWORD"  # Custom password

    resources:
      limits:
        cpu: 2000m
        memory: 2Gi

    persistence:
      enabled: true
      size: 5Gi

  # PostgreSQL database
  postgres:
    enabled: true
    type: postgresql
    passwordSecretKey: "POSTGRES_PASSWORD"

    image:
      repository: postgres
      tag: "15.3"

    env:
      POSTGRES_DB: "myapp"
      POSTGRES_USER: "appuser"

    resources:
      limits:
        cpu: 4000m
        memory: 4Gi

    persistence:
      size: 50Gi
```

### What Gets Created

For each database (e.g., `queue`, `cache`, `postgres`):

**Kubernetes Resources:**
- StatefulSet: `myapp-queue`, `myapp-cache`, `myapp-postgres`
- Services: `myapp-queue`, `myapp-cache`, `myapp-postgres`
- Headless Services: `myapp-queue-headless`, `myapp-cache-headless`
- PVCs: `data-myapp-queue-0`, `data-myapp-cache-0`

**Auto-Generated Environment Variables:**
```bash
# Generic
DATABASE_QUEUE_HOST=myapp-queue.namespace.svc.cluster.local
DATABASE_QUEUE_PORT=6379

# Type-specific
REDIS_QUEUE_HOST=myapp-queue.namespace.svc.cluster.local
REDIS_QUEUE_PORT=6379
REDIS_QUEUE_DB=0

REDIS_CACHE_HOST=myapp-cache.namespace.svc.cluster.local
REDIS_CACHE_PORT=6379
```

**Password Environment Variables:**
```bash
# In queue pod
REDIS_PASSWORD=<from secret key REDIS_PASSWORD>

# In cache pod
CACHE_PASSWORD=<from secret key CACHE_PASSWORD>

# In postgres pod
POSTGRES_PASSWORD=<from secret key POSTGRES_PASSWORD>
```

### Custom Passwords Per Database

Each database can use a different password:

```yaml
databases:
  queue:
    type: redis
    # Uses default: REDIS_PASSWORD

  cache:
    type: redis
    passwordSecretKey: "CACHE_PASSWORD"

  postgres:
    type: postgresql
    passwordSecretKey: "POSTGRES_PRIMARY_PASSWORD"
    passwordSecretName: "custom-secret"  # Optional: different secret
```

**Your Kubernetes Secret:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
data:
  REDIS_PASSWORD: base64_encoded_value
  CACHE_PASSWORD: base64_encoded_different_value
  POSTGRES_PRIMARY_PASSWORD: base64_encoded_another_value
```

**Default Password Keys:**
- Redis: `REDIS_PASSWORD`
- PostgreSQL: `POSTGRES_PASSWORD`
- MySQL: `MYSQL_ROOT_PASSWORD`
- MongoDB: `MONGO_ROOT_PASSWORD`

## 👥 Multi-Deployment Pattern (Master/Worker)

Deploy multiple application deployments with different roles:

```yaml
# Main deployment (master)
app:
  name: "workflow-engine"
  replicaCount: 1

  resources:
    limits:
      cpu: 2000m
      memory: 2Gi

  env:
    variables:
      MODE: "master"
      ENABLE_UI: "true"

service:
  enabled: true  # Master needs external access

# Additional deployments
deployments:
  # Background workers
  worker:
    enabled: true
    role: "worker"
    replicaCount: 5

    command: ["myapp", "worker"]  # Different startup command

    env:
      MODE: "worker"
      ENABLE_UI: "false"

    resources:
      limits:
        cpu: 1000m
        memory: 1Gi

    service:
      enabled: false  # Workers don't need external access

    # Independent auto-scaling
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 20
      targetCPUUtilizationPercentage: 75

    # Independent PDB
    podDisruptionBudget:
      enabled: true
      minAvailable: 1

  # Scheduled jobs processor
  scheduler:
    enabled: true
    role: "scheduler"
    replicaCount: 1

    command: ["myapp", "scheduler"]

    service:
      enabled: false
```

**What Gets Created:**
- Deployment: `myapp` (master)
- Deployment: `myapp-worker` (workers)
- Deployment: `myapp-scheduler` (scheduler)
- Service: `myapp` (routes to master only)
- HPA: `myapp-worker` (if autoscaling enabled)
- PDB: `myapp-worker` (if PDB enabled)

## 🌐 Multiple Ingress Resources

Create multiple entry points with different configurations:

```yaml
# Primary public API
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
  aws:
    subnets: "subnet-xxx,subnet-yyy"
    certificateArn: "arn:aws:acm:..."
  hosts:
    - host: "api.example.com"
      paths:
        - path: /
          pathType: Prefix

# Additional ingresses
additionalIngresses:
  # Internal admin interface (different controller)
  - name: "admin"
    enabled: true
    className: "nginx"
    targetNamespace: "nginx-ingress"  # Deploy to different namespace
    annotations:
      nginx.ingress.kubernetes.io/auth-type: "basic"
    hosts:
      - host: "admin.internal.example.com"
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp  # Can point to different service
                port:
                  number: 80

  # Webhooks endpoint (different ALB)
  - name: "webhooks"
    enabled: true
    className: "alb"
    annotations:
      alb.ingress.kubernetes.io/scheme: "internal"
    aws:
      groupName: "webhooks-alb"  # Separate ALB
      subnets: "subnet-aaa,subnet-bbb"
    hosts:
      - host: "webhooks.internal.example.com"
        paths:
          - path: /webhooks
            pathType: Prefix
```

**What Gets Created:**
- Ingress: `myapp-ingress` (primary, in app namespace)
- Ingress: `myapp-admin-ingress` (in nginx-ingress namespace)
- Ingress: `myapp-webhooks-ingress` (in app namespace)

**Use Cases:**
- Public API + private admin interface
- Multiple domains with different auth
- Different ingress controllers per endpoint
- API + webhooks with different ALBs

## 🔐 Secret Management

### External Secrets (Recommended)

Use secrets created by external tools (Vault, Sealed Secrets, etc.):

```yaml
secrets:
  enabled: true
  external:
    enabled: true
    secretName: "myapp-secrets"
```

### Multiple Secret Sources

```yaml
secrets:
  enabled: true
  external:
    enabled: true
    envFrom:
      - secretRef:
          name: "database-credentials"
      - secretRef:
          name: "api-keys"
      - secretRef:
          name: "oauth-tokens"
```

### Vault Integration

```yaml
secrets:
  enabled: true
  vault:
    enabled: true
    path: "secret/data/apps/myapp"
    secrets:
      - name: "DATABASE_PASSWORD"
        key: "db_password"
```

## 🔄 Auto-Scaling

### Basic Auto-Scaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### Advanced Scaling Behavior

```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      percent: 100  # Can double capacity
      pods: 2       # Add 2 pods at once
      periodSeconds: 15

    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5min
      percent: 20   # Remove max 20% at once
      periodSeconds: 60
```

### Per-Deployment Auto-Scaling

Workers can scale differently than master:

```yaml
# Master - stable
app:
  replicaCount: 2

autoscaling:
  enabled: false

# Workers - aggressive scaling
deployments:
  worker:
    enabled: true
    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 50
      targetCPUUtilizationPercentage: 75
```

## 📊 Environment Variables

### Static Variables

```yaml
env:
  variables:
    ENV: "production"
    LOG_LEVEL: "info"
    API_TIMEOUT: "30"
```

### ConfigMap

```yaml
configMap:
  enabled: true
  data:
    DATABASE_HOST: "db.example.com"
    DATABASE_PORT: "5432"
    REDIS_HOST: "redis.example.com"
    # Auto-generated from databases:
    # REDIS_QUEUE_HOST: "myapp-queue.namespace.svc.cluster.local"
    # REDIS_CACHE_HOST: "myapp-cache.namespace.svc.cluster.local"
```

## 🛡️ Production Features

### Security Context

```yaml
securityContext:
  enabled: true
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

### Pod Disruption Budget

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 2  # Keep 2 pods available during disruptions
```

### Network Policies

```yaml
networkPolicy:
  enabled: true
  policyTypes:
    - Ingress
    - Egress

  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: production
      ports:
        - protocol: TCP
          port: 8080
```

### Monitoring

```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    port: metrics
    path: /metrics
    interval: 30s
```

## 📦 Persistence

### Application Volumes

```yaml
persistence:
  enabled: true
  volumes:
    - name: "data"
      size: "10Gi"
      storageClass: "gp3"
      mountPath: "/data"

    - name: "logs"
      size: "5Gi"
      storageClass: "gp3"
      mountPath: "/var/log/app"
```

### Database Volumes

Automatically created per database:

```yaml
databases:
  postgres:
    persistence:
      enabled: true
      size: 50Gi
      storageClass: "gp3"
      accessMode: ReadWriteOnce
```

## 🎨 Scheduling

### Node Selection

```yaml
nodeSelector:
  kubernetes.io/arch: amd64
  tenant: production
  large: "true"
```

### Tolerations

```yaml
tolerations:
  - key: "tenant"
    operator: "Equal"
    value: "production"
    effect: "NoSchedule"
```

### Per-Database Scheduling

Each database can have different scheduling:

```yaml
databases:
  queue:
    nodeSelector:
      storage: "ssd"
      size: "large"

    tolerations:
      - key: "large"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
```

## 🌍 Cross-Namespace Routing

Deploy ingress in one namespace, service in another:

```yaml
# ExternalName service in nginx-ingress namespace
externalService:
  enabled: true
  name: "myapp-external"
  targetNamespace: "nginx-ingress"
  externalName: "myapp.app-namespace.svc.cluster.local"
  port: 80

# Ingress in nginx-ingress namespace
ingress:
  enabled: true
  targetNamespace: "nginx-ingress"
  hosts:
    - host: "myapp.example.com"
      paths:
        - path: /
          backend:
            service:
              name: "myapp-external"  # Points to ExternalName
              port:
                number: 80
```

## 📋 Complete Production Example

```yaml
global:
  environment: "production"
  project: "my-platform"

app:
  name: "api-server"
  image:
    repository: "myregistry/api"
    tag: "2.1.0"
  replicaCount: 3

  container:
    port: 8080

  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 2Gi

service:
  enabled: true
  port: 80

ingress:
  enabled: true
  className: "alb"
  hosts:
    - host: "api.myplatform.com"

deployments:
  worker:
    enabled: true
    replicaCount: 10
    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 50

databases:
  redis-queue:
    enabled: true
    type: redis
    resources:
      limits:
        cpu: 6000m
        memory: 6Gi
    persistence:
      size: 20Gi

  redis-cache:
    enabled: true
    type: redis
    passwordSecretKey: "CACHE_PASSWORD"
    resources:
      limits:
        cpu: 2000m
        memory: 2Gi
    persistence:
      size: 10Gi

  postgres:
    enabled: true
    type: postgresql
    passwordSecretKey: "POSTGRES_PASSWORD"
    resources:
      limits:
        cpu: 4000m
        memory: 8Gi
    persistence:
      size: 100Gi

secrets:
  enabled: true
  external:
    enabled: true
    secretName: "api-server-secrets"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20

podDisruptionBudget:
  enabled: true
  minAvailable: 2

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true

securityContext:
  enabled: true
  runAsNonRoot: true
  runAsUser: 1000

networkPolicy:
  enabled: true
```

## 🚀 Deployment

```bash
# Install chart
helm install my-app . -f values.yaml

# Upgrade
helm upgrade my-app . -f values.yaml

# Different environments
helm install my-app . -f values/prod.yaml
helm install my-app . -f values/qa.yaml
helm install my-app . -f values/dev.yaml
```

## 🐛 Troubleshooting

### Check Deployment

```bash
# All resources
kubectl get all -n <namespace> -l app.kubernetes.io/instance=my-app

# Master deployment
kubectl get deployment my-app -n <namespace>

# Worker deployments
kubectl get deployment my-app-worker -n <namespace>

# Databases
kubectl get statefulset my-app-queue my-app-cache -n <namespace>
```

### Check Databases

```bash
# Database pods
kubectl get pods -n <namespace> -l app.kubernetes.io/component=database

# Test connectivity from app
kubectl exec -n <namespace> deployment/my-app -- nc -zv my-app-queue 6379

# Check database logs
kubectl logs my-app-queue-0 -n <namespace>

# Verify environment variables
kubectl exec my-app-queue-0 -n <namespace> -- env
```

### Check Secrets

```bash
# List secrets
kubectl get secret my-app-secrets -n <namespace>

# Check secret keys
kubectl get secret my-app-secrets -n <namespace> -o jsonpath='{.data}' | jq 'keys'

# Verify pod is using secret
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Environment"
```

## 📚 Key Configuration Sections

- `app` - Main application deployment
- `deployments` - Additional deployments (workers, schedulers)
- `databases` - Multiple database StatefulSets
- `service` - Kubernetes service
- `ingress` - Primary ingress
- `additionalIngresses` - Additional ingress resources
- `secrets` - Secret management
- `configMap` - Configuration
- `autoscaling` - HPA configuration
- `podDisruptionBudget` - High availability
- `monitoring` - Prometheus integration
- `networkPolicy` - Network security

See `values.yaml` for all available options.

## 📄 License

MIT License
# tccw-k8s-service-template
