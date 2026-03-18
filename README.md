# Mina Helm Charts

Community-friendly Helm charts for deploying Mina blockchain nodes on Kubernetes.

> **Note**: These charts are forked from o1Labs' private gitops-helm-charts repository and have been generalized for community use while maintaining backwards compatibility.

## Overview

This repository provides a layered architecture for deploying Mina blockchain nodes using Helm and Helmfile:

- **[mina-daemon-chart](./mina-daemon-chart/)**: Base Helm chart providing core Kubernetes manifests
- **[mina-node-orchestrator](./mina-node-orchestrator/)**: Helmfile-based orchestrator for deploying different node types

## Quick Start

### Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.8+
- Helmfile (optional, for orchestrator)

### Deploy a Simple Mina Node

```bash
# Add dependencies
cd mina-daemon-chart
helm dependency update

# Install with default values
helm install my-mina-node . --values values.yaml

# Or customize your deployment
helm install my-mina-node . --set daemon.network=mainnet --set daemon.role=plain
```

### Deploy Multiple Nodes with Orchestrator

```bash
# Create a values file
cat > my-nodes.yaml << EOF
global:
  namespace: mina
  network: mainnet

nodes:
  plain-1:
    enable: true
    role: plain
    name: plain-node-1
  
  archive-1:
    enable: true
    role: archive
    name: archive-node-1
EOF

# Deploy with helmfile
cd mina-node-orchestrator
helmfile -f my-nodes.yaml apply
```

## Supported Node Types

| Role | Description | Replicas Support |
|------|-------------|------------------|
| `plain` | Basic Mina node | Single |
| `coordinator` | Network coordinator node | Single |
| `snarkWorker` | SNARK proof worker | Multiple |
| `blockProducer` | Block producer node | Single |
| `seed` | Network seed node | Single |
| `archive` | Archive node with PostgreSQL | Single |

## Configuration

### Common Configuration Options

```yaml
# Network settings
daemon:
  network: devnet  # or mainnet
  role: plain
  
  # Image configuration
  image:
    repository: minaprotocol/mina-daemon
    tag: "3.0.4-alpha2-b8cdab0-bullseye-devnet"
    pullPolicy: IfNotPresent

  # Resource limits
  resources:
    requests:
      cpu: "6"
      memory: "10Gi"
    limits:
      cpu: "8" 
      memory: "12Gi"

# Service configuration
service:
  enable: true
  type: ClusterIP
  
# Persistence (optional)
persistentVolumeClaim:
  enable: true
  size: 100Gi
  storageClassName: fast-ssd
```

### Archive Node with PostgreSQL

```yaml
# Enable PostgreSQL dependency
postgresql:
  enable: true
  
# Configure archive container
archive:
  enable: true
  image:
    repository: minaprotocol/mina-archive
    tag: "3.0.4-alpha2-b8cdab0-bullseye"
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Orchestration Level                         │
│  ┌─────────────────┐    ┌─────────────────┐                   │
│  │   Helmfile      │    │  Custom Values  │                   │
│  │  Configuration  │    │     Files       │                   │
│  └─────────────────────────────────────────┘                   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Node Level                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            mina-node-orchestrator                       │   │
│  │  • Role-specific templates                              │   │
│  │  • Default configurations                               │   │
│  │  • DAG-based deployment                                 │   │
│  └─────────────────────┬───────────────────────────────────┘   │
└─────────────────────────┬───────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Baseline Level                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              mina-daemon-chart                          │   │
│  │  • Core Kubernetes manifests                           │   │
│  │  • Container orchestration                             │   │
│  │  • Service and networking                              │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Development

### Chart Development

```bash
# Validate chart
cd mina-daemon-chart
helm lint .

# Test template rendering
helm template . --values values.yaml

# Test with CI values
helm template . --values ct-values.yaml
```

### Orchestrator Development

```bash
# Validate helmfile
cd mina-node-orchestrator
helmfile lint

# Preview changes
helmfile diff

# Deploy with dry-run
helmfile apply --dry-run
```

## Migration from o1Labs Charts

If you're migrating from the original o1Labs charts, key changes include:

- **Image repositories**: `gcr.io/o1labs-192920/*` → `minaprotocol/*`
- **Annotations**: `app.o1labs.org/*` → `app.minaprotocol.org/*`
- **Node labels**: `node-role.o1labs.org` → `node-role.minaprotocol.org`

All configuration APIs remain backwards compatible.

## Contributing

1. Open an issue describing the bug or feature
2. Create a branch from `main` (e.g. `fix/issue-42` or `feat/my-feature`)
3. Make your changes following the existing patterns
4. Test with `helm lint` and `helm template`
5. Submit a pull request referencing the issue

External contributors may also fork the repository and follow the same workflow.

## Support

- **Issues**: Report bugs and feature requests via GitHub Issues
- **Documentation**: See individual chart READMEs for detailed configuration options
- **Community**: Join the Mina Protocol Discord for general support

## License

This project is licensed under the MIT License with additional attribution requirements and disclaimers. See the [LICENSE](./LICENSE) file for full details.

**Key Points:**
- Free to use, modify, and distribute with attribution
- Must acknowledge derivation from o1Labs' original work
- **No warranties or guarantees provided**
- **Users deploy at their own risk and responsibility**
- **Contributors not liable for any damages or data loss**

By using these charts, you acknowledge and accept full responsibility for any consequences of deployment, including but not limited to data loss, security issues, or operational failures.