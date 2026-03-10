# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a reusable Kubernetes Helm chart template for deploying containerized applications and microservices with comprehensive AWS integration. It provides a complete foundation for cloud-native application deployment with production-ready patterns for security, monitoring, and scalability.

**IMPORTANT**: This chart is designed to be consumed by other projects as a reusable template, not deployed directly. The `values/` files serve as environment-specific configuration examples.

## Common Commands

### Helm Operations
```bash
# Validate the chart
helm lint .

# Render templates locally to debug
helm template my-service . -f values/dev-values.yaml

# Deploy to different environments
helm install my-service . -f values/dev-values.yaml     # Development
helm install my-service . -f values/qa-values.yaml      # QA/Staging  
helm install my-service . -f values/prod-values.yaml    # Production

# Upgrade existing deployment
helm upgrade my-service . -f values/qa-values.yaml

# Dry run to see what would be deployed
helm install my-service . -f values/qa-values.yaml --dry-run

# Package chart for distribution
helm package .

# Test config file mounting strategies
helm template test-pvc . -f values/dev-values.yaml \
  --set configFiles.enabled=true \
  --set configFiles.pvc.enabled=true \
  --set configFiles.pvc.volumes[0].name=config-vol \
  --set configFiles.pvc.volumes[0].claimName=my-config-pvc \
  --set configFiles.pvc.volumes[0].mountPath=/app/config.yaml

helm template test-init . -f values/dev-values.yaml \
  --set configFiles.enabled=true \
  --set configFiles.initContainer.enabled=true \
  --set configFiles.initContainer.sources[0].url=https://example.com/config.yaml \
  --set configFiles.initContainer.sources[0].mountPath=/app/config.yaml

# Test TargetGroupBinding instead of Ingress (external ALB control)
helm template test-tgb . -f values/qa-values.yaml \
  --set ingress.enabled=false \
  --set targetGroupBinding.enabled=true \
  --set targetGroupBinding.targetGroupARN=arn:aws:elasticloadbalancing:region:account:targetgroup/my-targets/1234567890123456
```

### Prerequisites
```bash
# Install AWS Load Balancer Controller (required for ingress and TargetGroupBinding)
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=your-cluster-name

# Install Vault CSI Driver (required for Vault secrets in QA/Prod)
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system

# Install Prometheus Operator (required for monitoring)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

## Architecture Overview

This comprehensive Kubernetes Helm chart provides a complete foundation for deploying containerized applications and microservices with production-ready patterns. It supports both stateless applications (Deployment) and stateful services (StatefulSet) with integrated AWS Load Balancer Controller support.

### Chart Consumption Pattern

This chart is designed as a **reusable template** to be consumed by other projects via Helm's dependency system or as a chart template:

```bash
# Method 1: Use as dependency in Chart.yaml
dependencies:
  - name: k8s-service-template
    version: "0.1.0"
    repository: "file://path/to/k8s-service-template"

# Method 2: Copy and customize for specific services
cp -r k8s-service-template my-service-chart
# Customize values and templates as needed
```

### Core Components

- **Application Deployment**: Flexible Deployment or StatefulSet patterns
- **Load Balancing**: AWS Application Load Balancer integration via Ingress
- **Database Support**: Optional in-cluster databases (PostgreSQL/MySQL/MongoDB) or external connections
- **Secret Management**: Vault integration for production, manual secrets for development
- **Monitoring**: Prometheus ServiceMonitor integration
- **Security**: NetworkPolicies, RBAC, Pod Security Standards
- **Auto-scaling**: Horizontal Pod Autoscaler with custom metrics support

### Key Architectural Patterns

**Environment Strategy**: Multi-environment support through separate values files in `values/` directory:
- `dev-values.yaml` - Single replica, local database, manual secrets, debug mode
- `qa-values.yaml` - Auto-scaling, Vault integration, monitoring enabled
- `prod-values.yaml` - High availability, external database, full security policies

**Service Type Selection**: The `app.type` field determines deployment pattern:
- `"deployment"` - Creates Kubernetes Deployment for stateless services
- `"statefulset"` - Triggers StatefulSet creation (used with database.enabled)

**AWS Integration**: Internal ALB configuration through ingress annotations:
- Uses AWS Load Balancer Controller with `alb.ingress.kubernetes.io/*` annotations
- Supports subnet specification, security groups, and ACM certificate integration
- Creates internal load balancers visible in AWS console for further configuration

**Secret Management**: Dual approach for different environments:
- **Vault Integration**: Uses SecretProviderClass with CSI Secret Store Driver for production
- **Manual Secrets**: Base64 encoded secrets in values files for development

**Database Architecture**: Optional in-cluster database support:
- PostgreSQL/MySQL/MongoDB StatefulSets with persistent storage
- External database support via environment variables (typical for production)
- Automatic service discovery through generated DNS names

### Template Interdependencies

**Core Dependencies**:
- `_helpers.tpl` provides common template functions used across all resources
- `deployment.yaml` and `statefulset.yaml` are mutually exclusive based on `app.type`
- `secret.yaml` renders differently based on `secrets.vault.enabled` flag

**Conditional Resources**: Many templates use conditional rendering:
- Database resources only render when `database.enabled: true`
- Monitoring resources require `monitoring.enabled: true`
- Security policies (NetworkPolicy, PDB) are optional based on environment

**Configuration Inheritance**: Templates inherit from multiple sources:
- Base `values.yaml` provides defaults
- Environment-specific files in `values/` override base configuration
- `global` values propagate to all templates for consistent labeling

### Integration Points

**AWS Load Balancer Controller**: Ingress template expects ALB Controller installed in cluster with proper IAM permissions for subnet and security group management.

**Vault CSI Driver**: When `secrets.vault.enabled: true`, expects Vault CSI Secret Store Driver installed for secret mounting.

**Prometheus Operator**: ServiceMonitor resource requires Prometheus Operator CRDs when monitoring is enabled.

## Values File Patterns

The chart uses a layered configuration approach where environment-specific values override base defaults. Key configuration sections:

- `global.*` - Cross-cutting concerns (environment, project name)
- `app.*` - Application deployment configuration  
- `ingress.aws.*` - AWS-specific load balancer settings (ingress-managed ALB)
- `targetGroupBinding.*` - External ALB target group integration
- `database.*` - Optional in-cluster database configuration
- `secrets.vault.*` - Vault integration settings
- `monitoring.*` - Prometheus/Grafana integration
- `configFiles.*` - External configuration file mounting strategies

Environment files should specify AWS resource IDs (subnets, security groups, certificate ARNs) appropriate for their target environment.

### Config File Mounting Architecture

The chart supports three distinct strategies for mounting external configuration files:

**Strategy Selection**: Use `configFiles.enabled: true` and choose one or more sub-strategies:
- `configFiles.pvc.*` - Mount from Persistent Volume Claims (production recommended)
- `configFiles.initContainer.*` - Dynamic fetching during pod startup (flexible)
- `configFiles.hostPath.*` - Direct node filesystem access (node-specific configs)

**Volume Management**: Config file volumes are managed separately from persistence volumes, allowing independent configuration. The helper functions automatically generate appropriate volume definitions and mounts based on enabled strategies.

**Init Container Integration**: When `configFiles.initContainer.enabled: true`, an init container runs before the main application container to fetch configuration files from external sources (S3, HTTP, Git) and stores them in a shared emptyDir volume.

**Multi-File Support**: Each strategy supports mounting multiple configuration files to different paths within the same pod, enabling complex configuration scenarios.

## Template Architecture Details

### Core Template Files Structure

**Deployment Strategy**: The chart uses conditional template rendering based on `app.type`:
- `templates/deployment.yaml` - Renders when `app.type: "deployment"` (stateless apps)
- `templates/app-statefulset.yaml` - Renders when `app.type: "statefulset"` and `database.enabled: false` (stateful apps)
- `templates/statefulset.yaml` - Renders when `app.type: "statefulset"` and `database.enabled: true` (database workloads)

**Shared Helper Functions** (`templates/_helpers.tpl`):
- `k8s-service-template.name` - Chart name normalization
- `k8s-service-template.fullname` - Full resource name generation
- `k8s-service-template.labels` - Standard Kubernetes labels with environment/project context
- `k8s-service-template.selectorLabels` - Pod selector labels
- `k8s-service-template.serviceAccountName` - ServiceAccount name resolution
- `k8s-service-template.database.*` - Database-specific label and selector functions
- `k8s-service-template.env` - Environment variable template generation
- `k8s-service-template.securityContext` - Security context template
- `k8s-service-template.volumeClaims` - Persistent volume claim generation
- `k8s-service-template.configFileVolumes` - Config file volume definitions (PVC, hostPath, emptyDir)
- `k8s-service-template.configFileMounts` - Config file volume mount specifications  
- `k8s-service-template.configInitContainer` - Init container for dynamic config fetching

### Resource Dependencies

**Template Rendering Order Considerations**:
1. `secret.yaml` must render before deployment/statefulset (referenced in env vars)
2. `configmap.yaml` provides application configuration (referenced in env vars)
3. `serviceaccount.yaml` and `rbac.yaml` must exist before pods start
4. `service.yaml` must exist before `ingress.yaml` (backend service reference)
5. `persistentvolume.yaml` must exist before `statefulset.yaml` when persistence enabled

**Checksum Annotations**: Deployment template includes automatic restart triggers:
- `checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}`  
- `checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}`

These ensure pods restart when ConfigMap or Secret content changes.

## Environment-Specific Configuration Patterns

### Development (`values/dev-values.yaml`)
- Single replica deployment
- In-cluster PostgreSQL StatefulSet enabled
- Manual base64-encoded secrets (no Vault)
- Debug logging enabled
- Minimal resource limits
- No monitoring or security policies

### QA (`values/qa-values.yaml`)
- 2-replica deployment with auto-scaling (2-5 replicas)
- Vault secret integration enabled
- Monitoring with ServiceMonitor enabled
- Specific AWS resources (real subnet/security group IDs)
- Access logging to S3 enabled on ALB

### Production (`values/prod-values.yaml`)  
- 3-replica deployment with auto-scaling (3-10 replicas)
- External RDS database (in-cluster database disabled)
- Full security: NetworkPolicy, PodDisruptionBudget, pod anti-affinity
- Enhanced monitoring (15s intervals vs 30s)
- Priority class for critical workloads
- Enhanced health check timeouts
- ALB deletion protection enabled

## AWS Integration Specifics

### Load Balancer Configuration Options

The chart provides two distinct approaches for AWS Application Load Balancer integration:

#### Option 1: Ingress-Managed ALB (Default)
The ingress template generates AWS-specific annotations based on `ingress.aws.*` values:
- `alb.ingress.kubernetes.io/subnets` - Populated from `ingress.aws.subnets`
- `alb.ingress.kubernetes.io/security-groups` - From `ingress.aws.securityGroups`  
- `alb.ingress.kubernetes.io/certificate-arn` - From `ingress.aws.certificateArn`
- `alb.ingress.kubernetes.io/group.name` - From `ingress.aws.groupName`
- `alb.ingress.kubernetes.io/load-balancer-attributes` - From `ingress.aws.loadBalancerAttributes`

**Use case**: When you want Kubernetes to fully manage the ALB lifecycle (creation, updates, deletion).

#### Option 2: TargetGroupBinding with External ALB
For scenarios requiring external ALB management, use TargetGroupBinding instead of Ingress:

```yaml
# Disable ingress
ingress:
  enabled: false

# Enable TargetGroupBinding
targetGroupBinding:
  enabled: true
  targetGroupARN: "arn:aws:elasticloadbalancing:region:account:targetgroup/my-targets/1234567890123456"
  serviceRef:
    name: ""    # Uses chart service name
    port: 80
  targetType: "ip"
  healthCheckPath: "/health"
  healthCheckPort: "8080"
```

**Use case**: When you need granular control over ALB configuration, shared ALBs across multiple services, or compliance requirements for infrastructure-as-code managed load balancers.

**Prerequisites for TargetGroupBinding**:
1. Pre-create ALB, listeners, rules, and target groups in AWS
2. Ensure AWS Load Balancer Controller has permissions to manage target group memberships
3. Configure ALB security groups to allow traffic from appropriate sources

**Workflow**:
1. Create ALB and target group externally via Terraform/CloudFormation/AWS CLI
2. Deploy chart with `targetGroupBinding.enabled: true` and the target group ARN
3. AWS Load Balancer Controller automatically registers/deregisters pod IPs in the target group
4. Manage ALB listeners, rules, and certificates outside of Kubernetes

### Secret Management Integration
When `secrets.vault.enabled: true`, the chart expects:
- Vault CSI Secret Store Driver installed in cluster
- SecretProviderClass resource configuration
- Proper Vault authentication setup (typically via ServiceAccount annotations)

Secrets are mounted as files and exposed as environment variables through the CSI driver.