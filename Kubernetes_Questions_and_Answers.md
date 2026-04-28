# Kubernetes Questions and Answers

## 1. Kubernetes Architecture Components

**Q: How would you explain the key Kubernetes architecture components?**

A: You can describe the roles like this:
- **API Server**: Central control plane component that exposes the Kubernetes API; handles all API requests and validates/processes them
- **etcd**: Distributed key-value store that stores all cluster data; serves as the single source of truth for cluster state
- **Controller Manager**: Runs controller processes that regulate the state of the cluster; includes node controller, job controller, replication controller
- **Scheduler**: Assigns pods to nodes based on resource requirements and scheduling policies
- **kubelet**: Node agent that ensures containers are running in a Pod; registers nodes with the API server and reports node status
- **kube-proxy**: Network proxy running on each node; maintains network rules for service routing and load balancing

---

## 2. Kubernetes vs Traditional VM-Based Deployments

**Q: How would you describe the benefits and drawbacks of using Kubernetes instead of traditional VM-based deployments?**

A: 
**Benefits:**
- Container efficiency: Faster startup times, lower resource overhead compared to VMs
A: A strong justification usually considers:
- Self-healing: Automatic restart of failed containers
- Rolling updates: Zero-downtime deployments with automatic rollback
- Resource optimization: Better resource utilization through bin-packing
- Declarative configuration: Infrastructure as code approach

**Drawbacks:**
- Learning curve: Complex ecosystem and new operational model
- Operational complexity: Requires expertise in container orchestration
- Network complexity: More complex networking model compared to VMs
- Smaller blast radius concerns: More individual containers to monitor
- Migration effort: Requires containerization of existing applications
- Debugging challenges: Distributed debugging across many containers

---

## 3. Kubernetes Namespaces

**Q: How would you explain the purpose and benefits of using namespaces in Kubernetes?**

A:
- **Multi-tenancy**: Logical isolation of resources within a cluster
- **Resource quotas**: Limit CPU, memory, and other resources per namespace
- **Access control**: Apply RBAC policies at namespace level
- **Organization**: Separate environments (dev, staging, production) or teams
- **Default isolation**: Network policies can be scoped to namespaces
- **Clean resource management**: Easier to track and delete resources by namespace
- **DNS isolation**: Services within a namespace have DNS names scoped to the namespace

---

## 4. Deployment vs StatefulSet

**Q: How would you explain the difference between a Deployment and a StatefulSet in Kubernetes, and when to use each one?**

A:
**Deployment:**
- For stateless applications
- Pods are interchangeable and have no persistent identity
- Random pod names (e.g., deployment-abc123-xyz)
- No guaranteed pod ordering
- Better for web servers, APIs, load-balanced services
- Easier to scale and update

**StatefulSet:**
- For stateful applications requiring persistent identity
- Pods have stable network identities (e.g., mysql-0, mysql-1, mysql-2)
- Ordered pod creation/deletion (ordinal index)
- Maintains network identity across rescheduling
- Better for databases, message queues, distributed systems
- Supports persistent storage per pod

**When to use:**
- Use Deployment for: web applications, microservices, APIs, frontend applications
- Use StatefulSet for: databases, caching layers, distributed systems, applications needing stable network identity

---

## 5. Kubernetes Networking Model

**Q: How would you describe the Kubernetes networking model and how pods communicate across nodes?**

A:
- **Pod-to-Pod communication**: Every pod gets its own IP address; pods can communicate directly without NAT
- **Flat network model**: All pods in cluster can communicate with each other regardless of node
- **Network plugins (CNI)**: Implement the networking model (Flannel, Calico, Weave, etc.)
- **Service networking**: Services provide stable endpoints for pods; kube-proxy handles load balancing
- **Cross-node communication**: Overlay networks or direct routing bridges traffic between pods on different nodes
- **Network policies**: Control ingress/egress traffic between pods
- **No node-to-pod NAT**: Traffic from pod reaches other pods/nodes using the pod IP directly

---

## 6. kube-proxy Component

**Q: How would you explain what kube-proxy does in Kubernetes and how it handles service load balancing?**

A:
- **Service implementation**: Runs on every node and implements the Service abstraction
- **Load balancing**: Distributes traffic across pod replicas using iptables, ipvs, or userspace modes
- **Service discovery**: Watches for Service and Endpoint changes and updates routing rules
- **Port forwarding**: Translates service IP:port to actual pod IP:port
- **Multiple modes**:
  - **iptables mode**: Uses Linux iptables for routing (default, most performant)
  - **IPVS mode**: Uses Linux IPVS for load balancing (better performance at scale)
  - **Userspace mode**: Routes through userspace proxy (deprecated, slower)
- **ClusterIP routing**: Handles internal service communication
- **NodePort/LoadBalancer**: Enables external access to services

---

## 7. Kubernetes Operators

**Q: How would you explain Kubernetes Operators and how they extend Kubernetes functionality?**

A:
- **Definition**: Custom controllers that extend Kubernetes APIs to manage complex applications
- **CRDs (Custom Resource Definitions)**: Define new resource types specific to the application
- **Automation**: Encode operational knowledge and automate management tasks
- **Examples**: Database operators, monitoring operators, networking operators
- **Lifecycle management**: Handle installation, upgrades, backup, recovery, scaling
- **Domain expertise**: Encapsulate best practices for operating specific applications
- **Declarative management**: Use YAML to declare desired state; operator ensures compliance
- **Use cases**: 
  - Managing stateful services (databases, caches)
  - Complex application orchestration
  - Multi-cluster operations
  - Backup and disaster recovery automation

---

## 8. Minikube Limitations

**Q: How would you explain Minikube limitations compared with a production Kubernetes cluster, including features that are missing or behave differently?**

A:
**Limitations:**
- **Single-node cluster**: No multi-node networking or behavior testing
- **Storage limitations**: Limited persistent volume support; no real storage solutions
- **Resource constraints**: Limited by local machine resources
- **Networking**: No real load balancers; limited ingress testing
- **Add-ons unavailable**: Some production features not available (some advanced networking, certain CSI drivers)
- **Performance**: Slower than production due to virtualization overhead
- **Scalability testing**: Cannot test cluster scaling behavior
- **Node failure simulation**: Difficult to test node failure scenarios
- **Advanced networking**: Network policies behavior may differ from production
- **Security**: Reduced security features compared to production
- **Limited monitoring**: No production-grade monitoring stacks easily available

---

## 9. Kubernetes Probes

**Q: How would you explain the use of Kubernetes probes (readiness, liveness, startup) in deployment manifests?**

A:
**Liveness Probe:**
- Determines if pod should be restarted
- If fails, pod is terminated and recreated
- Detects deadlocks or hung processes
- Config example: httpGet to `/health` endpoint

**Readiness Probe:**
- Determines if pod is ready to receive traffic
- If fails, pod is removed from service endpoints
- Detects when application is starting up or temporarily unavailable
- Prevents traffic routing to not-yet-ready pods
- Config example: TCP connection to port 8080

**Startup Probe:**
- Gives slow-starting containers time to initialize
- Disables liveness and readiness probes until it succeeds
- For legacy applications with long startup times
- Config example: httpGet with high initial delay

**Implementation methods:**
- httpGet: HTTP request to container
- tcpSocket: TCP connection attempt
- exec: Execute command inside container

---

## 10. Resource Requests and Limits

**Q: How would you set resource requests and limits for pods, and what happens if a pod exceeds its memory limit?**

A:
**Resource Requests:**
- Minimum resources guaranteed to pod
- Scheduler uses requests to place pods on appropriate nodes
- Ensures pod has enough resources to function
- Does not prevent pod from using more resources

**Resource Limits:**
- Maximum resources pod can use
- Pod cannot exceed CPU limit (throttled)
- Pod killed if exceeds memory limit (OOMKilled)
- Prevents resource contention between pods

**Memory Limit Exceeded:**
- Pod receives SIGKILL signal
- Container stops and restarts
- Pod enters CrashLoopBackOff if restart policy is Always
- Node kubelet reports OOMKilled status
- Visible in pod events and logs

**Implementation:**
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

---

## 11. Init Containers

**Q: How would you explain the purpose of init containers in a pod, and when they solve deployment problems?**

A:
**Purpose:**
- Run before application containers start
- Run sequentially to completion
- Must complete successfully before pod starts main containers
- Separate concerns: setup vs application logic
- Run with full privileges of pod security context

**Use Cases:**
- Database initialization: Wait for database to be ready
- Configuration setup: Generate config files
- Dependency checking: Verify required services are available
- Data migration: Perform one-time setup tasks
- Permission fixes: Change ownership of mounted volumes

**Example: Wait for Database:**
```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command: ['sh', '-c', 'until nc -z db-service 5432; do sleep 1; done']
containers:
- name: app
  image: myapp:latest
```

This solves race conditions where the application starts before the database is ready, causing connection failures.

---

## 12. Kubernetes Manifests Creation

**Q: How do you create Kubernetes manifests for backend and frontend deployments?**

A: Create YAML manifest files that include:
- **Backend Deployment**: 
  - Replicas configuration
  - Container image specification
  - Resource requests/limits
  - Environment variables
  - Health probes (liveness, readiness, startup)
  - Volume mounts if needed
  - Service for internal communication

- **Frontend Deployment**:
  - Replicas configuration (typically more than backend)
  - Frontend container image
  - Resource allocation
  - Service for internal routing
  - Ingress for external access

---

## 13. Application Manifests Deployment

**Q: How do you verify that application manifests were applied and deployed successfully?**

A: A deployment is successful when:
- All manifests applied using `kubectl apply -f`
- No validation errors
- Pods reach Running status
- Health probes pass
- Services created and endpoints populated
- No pending pods or failed deployments
- Application is accessible through service/ingress endpoints

---

## 14. Initial Replica Configuration

**Q: How do you configure startup replicas so the backend has 1 replica and the frontend has 2 replicas?**

A: Configure deployments with:
```yaml
# Backend Deployment
spec:
  replicas: 1
  
# Frontend Deployment
spec:
  replicas: 2
```

This configuration:
- Reduces backend complexity for single-instance services
- Provides frontend redundancy for better availability
- Reflects typical microservices pattern
- Can be scaled independently as needed

---

## 15. Services and Ingress Configuration

**Q: How do you configure Services and Ingress so services handle internal communication and ingress provides external access?**

A:
**Services for Internal Communication:**
- Create ClusterIP services for backend and frontend
- Enable pod-to-pod communication
- Service DNS names allow discovery (e.g., backend-service, frontend-service)
- Internal traffic routed through service IPs

**Ingress for External Access:**
- Expose frontend service to external traffic
- Configure routing rules (host-based or path-based)
- TLS/SSL termination optional
- Routes external requests to frontend service
- Example: `myapp.example.com` â†’ frontend service

**Benefits:**
- Separation of concerns: internal vs external
- Security: frontend exposed, backend protected
- Load distribution: services handle routing
- Scalability: easy to modify service endpoints

---

## 16. Deployment Troubleshooting

**Q: How would you troubleshoot deployment issues using kubectl commands?**

A:
**Diagnostic Commands:**
- `kubectl get pods` - List pods and status
- `kubectl describe pod <name>` - Detailed pod information, events
- `kubectl logs <pod>` - View container logs
- `kubectl logs <pod> --previous` - Previous container logs
- `kubectl exec <pod> -- <command>` - Execute command in pod
- `kubectl get events` - Cluster events
- `kubectl get deployments` - Deployment status
- `kubectl rollout status deployment/<name>` - Rollout progress
- `kubectl top nodes/pods` - Resource usage

**Common Issues and Solutions:**
- ImagePullBackOff: Check image name, registry credentials
- CrashLoopBackOff: Check logs, resource limits, health probes
- Pending: Check resource availability, node selectors
- Services not reachable: Check selectors, endpoints, DNS
- Node not ready: Check node status, kubelet logs

---

## 17. Network Policies

**Q: How would you configure network policies to restrict pod-to-pod communication while addressing security considerations?**

A:
**Network Policies:**
- Control ingress and egress traffic between pods
- Label-based pod selection
- Deny-all by default when policies exist
- Specify allowed sources/destinations

**Configuration:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-policy
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
    ports:
    - protocol: TCP
      port: 5432
```

**Security Considerations:**
- Principle of least privilege: allow only necessary traffic
- Segment network by tier (frontend, backend, database)
- Restrict external traffic entry points
- Log network policy violations
- Test policies in non-production first
- Monitor for policy bypass attempts

---

## 18. Service Types

**Q: How would you explain the differences between ClusterIP, NodePort, and LoadBalancer, and justify which one to use for each component?**

A:
**ClusterIP (Default):**
- Internal-only service
- Accessible within cluster only
- No external exposure
- Use for: backend services, databases, internal APIs
- Most secure, no external access
- Most resource-efficient

**NodePort:**
- Exposes service on every node's IP at a specific port
- External access via `<NodeIP>:<NodePort>`
- Port range: 30000-32767
- Use for: development, testing, small deployments
- Less sophisticated than LoadBalancer
- Each node consumes a port

**LoadBalancer:**
- Provision external load balancer (cloud provider)
- Distributes traffic across nodes
- Each service gets unique external IP
- Use for: production external APIs, public web services
- Cleaner external interface
- Cloud provider integration required
- Higher cost (external LB resource)

**Typical Architecture:**
- Frontend: LoadBalancer (external access)
- Backend: ClusterIP (internal only)
- Database: ClusterIP (internal only)
- Admin API: NodePort or ClusterIP (limited access)

---

## 19. Persistent Storage Importance

**Q: How would you explain why persistent storage is important in Kubernetes?**

A:
**Importance:**
- **Data persistence**: Survive pod restarts and deletions
- **Stateful applications**: Databases, message queues, caches
- **Data sharing**: Between pod replicas or across time
- **Compliance**: Retain logs and audit trails
- **Cost efficiency**: Avoid data loss and reprocessing
- **High availability**: Data available even if pods recreated
- **Backup/recovery**: Enable disaster recovery
- **Application requirements**: Many applications require persistent state

**Use Cases:**
- Database data storage
- File uploads and documents
- Application logs
- Cache data
- Session state
- Configuration files

---

## 20. Persistent Volumes and Claims

**Q: How do you define Persistent Volumes (PVs) and Persistent Volume Claims (PVCs)?**

A:
**Persistent Volume (PV):**
- Cluster-level resource
- Storage provisioned by administrator
- Independent of pods
- Lifecycle decoupled from pods
- Example: NFS, iSCSI, AWS EBS, Google Persistent Disk

**Persistent Volume Claim (PVC):**
- Pod-level request for storage
- Abstract storage requirements
- Binds to matching PV
- Storage class determines provisioning
- Dynamic provisioning possible

**Definition Example:**
```yaml
# Static PV
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-storage
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    server: nfs-server
    path: "/exports/data"

# PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi

# Pod using PVC
pods:
- name: db
  volumeMounts:
  - name: data
    mountPath: /var/lib/postgresql
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-claim
```

---

## 21. Persistent Volume Access Modes

**Q: How would you explain the differences between ReadWriteOnce, ReadOnlyMany, and ReadWriteMany access modes, and justify your choice?**

A:
**ReadWriteOnce (RWO):**
- Single node can read/write
- Most restrictive
- Best for: databases, single-pod stateful apps
- Highest performance
- Use when only one pod needs access

**ReadOnlyMany (ROMany):**
- Multiple nodes can read (no write)
- Shared read-only access
- Best for: shared config files, static content
- No concurrent write conflicts
- Use for read-only data distribution

**ReadWriteMany (RWMany):**
- Multiple nodes can read/write
- Most flexible
- Requires network storage (NFS, EFS)
- Performance varies
- Best for: shared file systems, logs, multi-pod write access
- Potential consistency issues with concurrent writes

**Selection Criteria:**
- **Single database pod**: RWO (performance, consistency)
- **Configuration files**: ROMany (shared but no write conflicts)
- **Web application serving static files**: ROMany or RWMany
- **Multi-pod log aggregation**: RWMany
- **Cluster-wide shared data**: RWMany
- **Performance critical**: RWO when possible

---

## 22. Data Loss Handling

**Q: How would you handle potential data loss when pods with persistent storage are rescheduled to different nodes?**

A:
**Risk Factors:**
- Pod rescheduled to different node with storage affinity
- Storage unmounted from original node
- Network storage temporarily unavailable
- Data corruption on network storage

**Mitigation Strategies:**

1. **Storage Affinity:**
   - Use node affinity to keep pod and storage together
   - Limits flexibility but ensures performance

2. **Backup Strategy:**
   - Regular backups to remote location
   - Point-in-time recovery capability
   - Test recovery procedures

3. **Replication:**
   - Multi-replica storage backends
   - RAID configurations
   - Cloud provider multi-AZ storage

4. **StatefulSet Stability:**
   - Use StatefulSets for stable identity
   - Ordered pod management
   - Persistent naming

5. **Storage Health Monitoring:**
   - Monitor storage availability
   - Alert on connection issues
   - Proactive intervention

6. **Graceful Shutdown:**
   - Pod termination grace period
   - Flush data before shutdown
   - Drain nodes before replacement

7. **Distributed Storage:**
   - Use distributed storage systems (GlusterFS, Ceph)
   - Built-in redundancy
   - Handle node failures transparently

---

## 23. CI/CD Tool Deployment

**Q: How do you deploy a CI/CD tool on a Kubernetes cluster?**

A:
- CI/CD tool installed via Helm chart or manifests
- Persistent storage for job history, artifacts, configuration
- Service created for internal access
- Configured RBAC for cluster access
- Secrets configured for credentials and tokens
- Integration with version control system (Git)
- Ready to build and deploy applications

---

## 24. CI/CD Tool Choice

**Q: How would you justify your CI/CD tool choice?**

A:
Student should justify choice considering:
- **Kubernetes native support**: ArgoCD, Flux, Jenkins with Kubernetes plugin
- **Ease of deployment**: GitOps tools (ArgoCD) vs traditional (Jenkins)
- **Community support**: Active community, available plugins
- **Features**: Pipeline support, multi-branch, artifact management
- **Cost**: Free vs commercial options
- **Learning curve**: Familiarity vs best practices
- **Integration**: Git integration, container registry, notification systems
- **Scalability**: Agent/worker support for distributed builds

**Popular Options:**
- **ArgoCD**: GitOps-native, declarative, K8s-first
- **Jenkins**: Widely used, extensive plugin ecosystem
- **GitLab CI/CD**: Integrated with GitLab, strong K8s support
- **Tekton**: Cloud-native, Kubernetes-first
- **GitHub Actions**: Simple, integrated with GitHub

---

## 25. CI/CD Integration with Kubernetes

**Q: How do you configure a CI/CD tool to interact with a Kubernetes cluster?**

A:
**Configuration Requirements:**
- Service account created for CI/CD
- RBAC roles with appropriate permissions
  - Create/update deployments
  - Manage pods
  - Access secrets
- kubeconfig mounted in CI/CD pods
- Cluster endpoint configured
- Authentication credentials secured
- Network access from CI/CD to cluster API

**Capabilities:**
- Deploy applications to cluster
- Trigger rollouts
- Access cluster logs
- Run tests in cluster
- Manage resources

---

## 26. Secrets Management in CI/CD

**Q: How would you secure secrets used in a CI/CD pipeline, and how do you manage and rotate them?**

A:
**Security Practices:**

1. **Secret Storage:**
   - Use Kubernetes Secrets for sensitive data
   - CI/CD tool secret management (not environment variables)
   - Encrypted at rest
   - RBAC restricted access

2. **Secret Usage:**
   - Mount as environment variables
   - Mount as files
   - Reference in manifests (not hardcoding)

3. **Secret Rotation:**
   - Regular rotation schedule
   - Automation for rotation
   - Zero-downtime updates
   - Old secrets maintained during transition

4. **Access Control:**
   - Principle of least privilege
   - Service account per application
   - Audit logging of secret access
   - Limited secret visibility in logs

5. **External Secret Management:**
   - HashiCorp Vault
   - Cloud provider KMS (AWS Secrets Manager, GCP Secret Manager)
   - External Secrets operator for sync to K8s

6. **Pipeline Protection:**
   - Secrets not printed in logs
   - CI/CD masked secrets in output
   - Limited access to CI/CD secrets
   - Audit trail of secret usage

---

## 27. Rolling Updates and Rollbacks

**Q: How would you implement rolling updates and handle failed deployments and rollbacks?**

A:
**Rolling Update Strategy:**
```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  minReadySeconds: 30
```

**How it works:**
- Gradually replace old pods with new ones
- `maxSurge`: Extra pods during update (surge capacity)
- `maxUnavailable`: Pods that can be down during update
- Maintains minimum availability throughout
- Health probes verify pod readiness

**Advantages:**
- Zero-downtime deployments
- Easy rollback if issues detected
- Gradual traffic shift to new version
- Automatic retry on pod failure

**Failed Deployment Handling:**
- Readiness probe failures halt rollout
- Automatic rollback available
- Specify rollback revision
- Previous pods maintained temporarily

**Rollback Process:**
```bash
# Check deployment history
kubectl rollout history deployment/myapp

# Rollback to previous version
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=2

# Pause/resume rollout
kubectl rollout pause deployment/myapp
kubectl rollout resume deployment/myapp
```

**Prevention:**
- Thorough testing before deployment
- Canary deployments for critical services
- Feature flags for gradual enablement
- Blue-green deployments for instant rollback
- Monitoring and alerts during deployment

---

## 28. Prometheus Deployment and Configuration

**Q: How do you deploy and configure Prometheus to scrape metrics?**

A:
- Prometheus installed in cluster (Helm chart or manifests)
- ConfigMap with scrape configuration
- Service created for access
- Persistent volume for data storage
- Retention policy configured
- Service discovery enabled
- Scrape targets defined
- Ready to collect and store metrics

---

## 29. Custom Metrics Implementation

**Q: How would you implement custom application metrics and make sure Prometheus scrapes them?**

A:
**Implementation Steps:**

1. **Instrument Application:**
   - Use Prometheus client library (language-specific)
   - Define custom metrics (counters, gauges, histograms)
   - Expose metrics endpoint (typically `:8080/metrics`)

2. **Metrics Types:**
   - **Counter**: Monotonically increasing (requests, errors)
   - **Gauge**: Value that can go up/down (temperature, memory)
   - **Histogram**: Distribution of values (request duration)
   - **Summary**: Quantiles over time window

3. **Example (Python):**
```python
from prometheus_client import Counter, Gauge, start_http_server

requests_total = Counter('myapp_requests_total', 'Total requests')
active_users = Gauge('myapp_active_users', 'Active users')

@app.route('/api/data')
def handle_request():
    requests_total.inc()
    # Process request
```

4. **Prometheus Configuration:**
```yaml
scrape_configs:
- job_name: 'myapp'
  static_configs:
  - targets: ['localhost:8080']
  metrics_path: '/metrics'
```

5. **Service Discovery:**
- Automatic discovery via Kubernetes annotations
- `prometheus.io/scrape: "true"`
- `prometheus.io/port: "8080"`
- `prometheus.io/path: "/metrics"`

---

## 30. Prometheus Service Discovery

**Q: How would you configure Prometheus service discovery and handle cases where required targets are not discovered?**

A:
**Service Discovery Configuration:**
```yaml
scrape_configs:
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __address__
```

**Challenges and Solutions:**

1. **Target Discovery Gaps:**
   - Challenge: Some pods not scraped
   - Solution: Verify pod annotations, check relabel rules

2. **Incorrect Port/Path:**
   - Challenge: Wrong metrics endpoint
   - Solution: Validate annotations on pods

3. **Pod Lifecycle Changes:**
   - Challenge: New pods not automatically discovered
   - Solution: Service discovery watches for changes automatically

4. **Namespace Filtering:**
   - Challenge: Too many targets
   - Solution: Use namespace selectors, relabel to filter

5. **DNS Resolution:**
   - Challenge: Service names not resolving
   - Solution: Use internal cluster DNS, verify ServiceMonitor resources

6. **Network Policies:**
   - Challenge: Prometheus cannot reach pods
   - Solution: Configure network policies to allow Prometheus scraping

---

## 31. Grafana Dashboards

**Q: How do you configure Grafana dashboards?**

A:
**Required Dashboards:**

1. **Cluster Performance Dashboard:**
   - Node CPU utilization
   - Node memory usage
   - Disk I/O rates
   - Network throughput
   - Pod scheduling rate
   - API server latency

2. **Pod and Container Dashboard:**
   - Pod CPU/memory usage
   - Container restart count
   - Pod status distribution
   - Network I/O per pod
   - Storage usage per pod
   - Pod startup time

3. **Application Performance Dashboard:**
   - Request rate (RPS)
   - Request duration (latency)
   - Error rate
   - Custom application metrics
   - Throughput by endpoint
   - SLA compliance metrics

**Implementation:**
- Create datasource pointing to Prometheus
- Import pre-built dashboards or create custom
- Add panels with PromQL queries
- Configure alerts in dashboards
- Set refresh intervals
- Share dashboards across team

---

## 32. EFK Stack Deployment

**Q: How do you deploy the EFK stack and configure Fluentd or Fluent Bit to collect logs?**

A:
**EFK Components:**

1. **Elasticsearch:**
   - Deployed in cluster
   - Persistent storage configured
   - Cluster configuration for reliability
   - Index management and lifecycle policies

2. **Fluent/Fluent Bit:**
   - DaemonSet deployed to every node
   - Collects logs from:
     - Container stdout/stderr
     - System logs
     - Pod logs via mounted volumes
   - Filters and processes logs
   - Forwards to Elasticsearch

3. **Kibana:**
   - Dashboard for log visualization
   - Index patterns configured
   - Service created for access

**Configuration Points:**
- Log parsing and filtering
- Multi-line log handling
- Metadata enrichment (namespace, pod name, node)
- Output to Elasticsearch

---

## 33. Log Rotation and Retention

**Q: How would you set up log rotation and retention in the EFK stack to prevent disk space issues?**

A:
**Elasticsearch Configuration:**

1. **Index Lifecycle Management (ILM):**
   - Define policies for index lifecycle
   - Rollover conditions (size, age, document count)
   - Retention periods
   - Deletion policies

2. **Index Naming:**
   - Convention: `logs-{namespace}-{pod}-{timestamp}`
   - Enables automatic rollover
   - Facilitates cleanup

3. **Retention Policies:**
```yaml
# Example policy
policy:
  phases:
    hot:
      min_age: 0d
      actions:
        rollover:
          max_size: 50GB
          max_age: 1d
    warm:
      min_age: 3d
      actions:
        set_priority:
          priority: 50
    delete:
      min_age: 30d
      actions:
        delete: {}
```

**Storage Management:**

1. **Disk Space Monitoring:**
   - Monitor disk usage percentage
   - Alert when approaching capacity
   - Set watermarks (high, low)

2. **Cleanup Strategies:**
   - Delete old indices automatically
   - Archive cold indices to cheaper storage
   - Compress old indices

3. **Capacity Planning:**
   - Calculate log volume per day
   - Size Elasticsearch cluster appropriately
   - Plan for log growth

4. **Fluent Configuration:**
   - Buffer limits to prevent memory bloat
   - Retry logic with exponential backoff
   - Dead letter queue for failed logs

---

## 34. Kibana Dashboards

**Q: How do you demonstrate useful Kibana dashboards?**

A:
**Required Dashboards:**

1. **Cluster Logs Dashboard:**
   - Logs by namespace
   - Logs by pod
   - Error rate over time
   - Log level distribution
   - System component logs (kubelet, API server)
   - Node-level logs

2. **Application Logs Dashboard:**
   - Application-specific logs
   - Request tracing information
   - Error stack traces
   - Application performance metrics
   - Request latency from logs
   - Transaction tracking

3. **Pod and Container Logs Dashboard:**
   - Logs per pod
   - Container restart logs
   - Init container logs
   - Resource limits related logs
   - Pod lifecycle events
   - Multi-container troubleshooting

**Dashboard Features:**
- Filterable by namespace, pod, container
- Time range selection
- Log highlighting and filtering
- Saved searches and queries
- Alerts based on log patterns
- Real-time log streaming

---

## 35. Alert Rules and Alertmanager

**Q: How would you define alert rules and route them through Alertmanager?**

A:
**Alert Rule Definition:**

1. **PrometheusRule Resources:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
spec:
  groups:
  - name: app.rules
    interval: 30s
    rules:
    - alert: HighErrorRate
      expr: rate(http_errors_total[5m]) > 0.05
      for: 5m
      annotations:
        summary: "High error rate detected"
```

2. **Alert Routing:**
   - Alertmanager receives alerts from Prometheus
   - Routes based on labels
   - Groups similar alerts
   - Deduplicates
   - Sends to notification receivers

3. **Alertmanager Config:**
```yaml
route:
  receiver: default
  group_by: ['alertname', 'cluster']
  routes:
  - match:
      severity: critical
    receiver: pagerduty
  - match:
      severity: warning
    receiver: slack
receivers:
- name: default
  slack_configs:
  - api_url: <webhook-url>
```

4. **Notification Receivers:**
   - Slack channels
   - PagerDuty incidents
   - Email
   - Custom webhooks
   - Integration with escalation policies

---

## 36. Pod Restart Alerting

**Q: How would you configure alerts for frequent pod restarts and use grouping/throttling to reduce alert fatigue?**

A:
**Alert Rule:**
```yaml
- alert: PodRestarting
  expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.2
  for: 15m
  annotations:
    summary: "Pod {{ $labels.pod }} restarting frequently"
```

**Alert Grouping:**
```yaml
alertmanager:
  config:
    route:
      group_by: ['namespace', 'alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
```

**Alert Throttling:**
1. **Repeat Interval:**
   - How often to repeat alert
   - Prevents duplicate notifications
   - Example: 12 hours

2. **Group Wait:**
   - Wait period before sending first notification
   - Collect similar alerts
   - Example: 10 seconds

3. **Group Interval:**
   - Send update if alert state changes
   - Example: 10 seconds

4. **Inhibition Rules:**
   - Suppress less important alerts
```yaml
inhibit_rules:
- source_match:
    severity: critical
  target_match:
    severity: warning
  equal: ['namespace', 'pod']
```

**Alert Fatigue Reduction:**
- Aggregate alerts by cluster/namespace
- Silence non-critical alerts during maintenance
- Tune thresholds to reduce false positives
- Route different severities appropriately
- Set meaningful repeat intervals

---

## 37. Node CPU Usage Alert

**Q: How do you create an alert for node CPU usage above 80% for more than 5 minutes?**

A:
```yaml
- alert: NodeCPUUsageHigh
  expr: (1 - avg by (node) (rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100 > 80
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Node {{ $labels.node }} CPU usage above 80%"
    description: "Node {{ $labels.node }} CPU usage is {{ $value }}%"
```

**Testing:**
```bash
stress-ng --cpu 8 --timeout 360s
# or
stress-ng --cpu 8 --timeout 360s &
```

---

## 38. Node Disk Space Alert

**Q: How do you create an alert for node disk space falling below 20% available?**

A:
```yaml
- alert: NodeDiskSpaceLow
  expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 20
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Node {{ $labels.node }} disk space below 20%"
    description: "Node {{ $labels.node }} has {{ $value }}% free disk space"
```

**Testing:**
```bash
fallocate -l 10G large_file.img
# or
dd if=/dev/zero of=large_file.img bs=1G count=10
```

---

## 39. Node Memory Usage Alert

**Q: How do you create an alert for node memory usage above 90% for more than 5 minutes?**

A:
```yaml
- alert: NodeMemoryUsageHigh
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Node {{ $labels.node }} memory usage above 90%"
    description: "Node {{ $labels.node }} memory usage is {{ $value }}%"
```

**Testing:**
```bash
stress-ng --vm 2 --vm-bytes 75% --timeout 360s
```

---

## 40. Pod Restart Frequency Alert

**Q: How do you create an alert when a pod restarts more than 3 times in 15 minutes?**

A:
```yaml
- alert: PodRestartingTooOften
  expr: rate(kube_pod_container_status_restarts_total[15m]) > (3/900)
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Pod {{ $labels.pod }} restarting frequently"
    description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has restarted {{ $value }} times in 15 minutes"
```

**Testing:**
```bash
kubectl run test-pod --image=alpine -i --tty --restart=Always -- /bin/sh -c "sleep 1; exit 1"
```

---

## 41. Container Memory Limit Alert

**Q: How do you create an alert when container memory usage exceeds 80% of its limit?**

A:
```yaml
- alert: ContainerMemoryUsageHigh
  expr: (container_memory_usage_bytes / container_spec_memory_limit_bytes) * 100 > 80
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Container {{ $labels.container }} memory usage above 80%"
    description: "Container {{ $labels.container }} in pod {{ $labels.pod }} has {{ $value }}% of memory limit"
```

**Testing:**
```bash
docker run -m 512m -it ubuntu /bin/bash
# Inside container: stress-ng --vm 1 --vm-bytes 450M --timeout 60s
```

---

## 42. Pod Pending State Alert

**Q: How do you create an alert when a pod stays Pending for more than 5 minutes?**

A:
```yaml
- alert: PodPendingTooLong
  expr: kube_pod_status_phase{phase="Pending"} == 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pod {{ $labels.pod }} pending for more than 5 minutes"
    description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} has been pending for {{ $value }} time units"
```

**Testing:**
```bash
kubectl apply -f insufficient-resources-pod.yaml
# Pod will stay pending due to insufficient CPU/memory
```

---

## 43. Kubernetes API Server Alert

**Q: How do you create an alert for the Kubernetes API server becoming unreachable?**

A:
```yaml
- alert: KubernetesAPIServerDown
  expr: kube_apiserver_up == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Kubernetes API server is unreachable"
    description: "The Kubernetes API server has been down for more than 2 minutes"
```

**Testing:**
```bash
# Simulate by disrupting Minikube API server (in test environment)
minikube ssh -- sudo systemctl stop kubelet
```

---

## 44. Elasticsearch Cluster Health Alert

**Q: How do you create alerts for Elasticsearch cluster health changing to yellow or red?**

A:
```yaml
- alert: ElasticsearchClusterHealthYellow
  expr: elasticsearch_cluster_health_status{color="yellow"} == 1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Elasticsearch cluster health is yellow"
    description: "Elasticsearch cluster status is yellow - some replicas are unallocated"

- alert: ElasticsearchClusterHealthRed
  expr: elasticsearch_cluster_health_status{color="red"} == 1
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "Elasticsearch cluster health is red"
    description: "Elasticsearch cluster is in red status - primary shards are unallocated"
```

**Testing:**
```bash
# Stop one Elasticsearch node in multi-node cluster to simulate yellow state
```

---

## 45. Fluentd Log Collection Errors

**Q: How do you create an alert for Fluentd log collection errors?**

A:
```yaml
- alert: FluentdLogCollectionError
  expr: rate(fluentd_output_status_emit_error_logs_total[5m]) > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Fluentd is experiencing log collection errors"
    description: "Fluentd error rate is {{ $value }} errors per second"
```

**Testing:**
```bash
# Misconfigure Fluentd to point to incorrect log source
# Monitor error rate in metrics
```

---

## 46. RBAC in Kubernetes

**Q: How would you explain the importance of RBAC in Kubernetes, with examples?**

A:
**Importance:**
- **Security**: Control who can access cluster resources
- **Principle of Least Privilege**: Grant minimal permissions needed
- **Auditability**: Track who performed actions
- **Multi-tenancy**: Isolate teams/applications
- **Compliance**: Meet regulatory requirements

**RBAC Components:**

1. **ServiceAccount:**
   - Identity for applications
   - Bound to RBAC permissions

2. **Role/ClusterRole:**
   - Set of permissions
   - Resources and verbs (get, list, create, delete)

3. **RoleBinding/ClusterRoleBinding:**
   - Grants role to subject (user, group, service account)

**Example Configuration:**
```yaml
# Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-reader
  namespace: default

# Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
spec:
  rules:
  - apiGroups: [""]
    resources: ["pods", "pods/logs"]
    verbs: ["get", "list", "watch"]

# RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
spec:
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: pod-reader
  subjects:
  - kind: ServiceAccount
    name: app-reader
    namespace: default
```

**Best Practices:**
- Use namespace-scoped roles for isolation
- Create roles per application/team
- Use groups for user management
- Regular audit of role assignments
- Remove unnecessary permissions
- Service accounts for pod-to-pod communication

---

## 47. Network Segmentation

**Q: How would you explain network segmentation in a cluster, with examples?**

A:
**Network Segmentation:**
- Divide cluster into logical zones based on trust levels
- Frontend, backend, database tiers
- Sensitive and non-sensitive workloads
- Separate network policies per segment

**Implementation:**

1. **Using Namespaces:**
```yaml
# Separate namespaces for tiers
- frontend namespace
- backend namespace
- database namespace
```

2. **Using Labels:**
```yaml
# Label-based segmentation
tier: frontend
tier: backend
tier: database
```

3. **Network Policies:**
```yaml
# Restrict frontend-to-backend communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-only-from-frontend
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Examples:**
- Frontend pods: Internet traffic allowed
- Backend pods: Only from frontend, can reach database
- Database pods: Only from backend, outbound blocked
- Monitoring pods: Can scrape metrics from all
- Logging pods: Can access logs from all

---

## 48. Kubernetes Secrets

**Q: How would you explain using Kubernetes Secrets to store sensitive data?**

A:
**Purpose:**
- Store sensitive data securely
- Database credentials
- API tokens
- SSH keys
- TLS certificates
- OAuth tokens

**Secret Types:**

1. **Opaque (default):** Arbitrary user data
2. **docker-registry:** Docker registry credentials
3. **basic-auth:** Basic authentication credentials
4. **ssh-auth:** SSH authentication
5. **tls:** TLS/SSL certificate and key
6. **bootstrap.kubernetes.io/token:** Bootstrap token

**Security Considerations:**
- Secrets stored in etcd (encrypted at rest in production)
- RBAC controls access
- Mounting reduces visibility compared to environment variables
- External secret management (Vault) recommended
- Avoid storing in Git or logs
- Rotate regularly
- Use least privilege access

---

## 49. Mounting Secrets

**Q: How would you mount Secrets as volumes or environment variables in pods?**

A:
**As Environment Variables:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
    - name: API_KEY
      valueFrom:
        secretKeyRef:
          name: api-secret
          key: token
```

**As Volumes:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: my-secret
```

**Accessing Mounted Secrets:**
```bash
# Files appear in the specified directory
ls /etc/secrets
# Each key in secret becomes a file
cat /etc/secrets/password
```

**Advantages:**
- **Volume**: Secrets rotated without pod restart, files with permissions
- **Env vars**: Simple for small secrets, but requires pod restart for updates

---

## 50. Sensitive Information Protection

**Q: How do you ensure sensitive information (API keys, passwords, SSH keys, etc.) is not exposed in plain text in configs or manifests?**

A:
**Best Practices:**
- Never hardcode secrets in manifests
- Use Kubernetes Secrets resource
- Use external secret management (Vault, sealed secrets)
- Reference secrets, don't embed
- Gitignore secret files
- Use immutable secrets where possible
- Audit logging for secret access

**Example - Wrong:**
```yaml
env:
- name: DB_PASSWORD
  value: "superSecret123"  # WRONG!
```

**Example - Correct:**
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
```

---

## 51. Namespace Organization

**Q: How do you organize namespaces for different application components?**

A:
**Typical Structure:**
```
default: System components, initial deployments
kube-system: Kubernetes system components
monitoring: Prometheus, Grafana
logging: EFK stack
app-frontend: Frontend services
app-backend: Backend services
app-database: Database services
ci-cd: CI/CD tools and pipelines
```

**Benefits:**
- Resource isolation
- Independent RBAC policies
- Resource quotas per namespace
- Network policies per namespace
- Easier management and cleanup
- Clear ownership and responsibility

---

## 52. Debugging CrashLoopBackOff

**Q: How would you debug a pod stuck in CrashLoopBackOff, including which commands to run and what to check?**

A:
**Symptoms:**
- Pod status shows CrashLoopBackOff
- Container exits immediately after restart
- Pod never reaches Running state

**Debugging Process:**

1. **Check Pod Status:**
```bash
kubectl describe pod <pod-name>
# Look for: Events, Exit Code, Last State Reason
```

2. **View Container Logs:**
```bash
kubectl logs <pod-name>
# Application errors, missing dependencies, config issues

# Previous logs if container restarted
kubectl logs <pod-name> --previous
```

3. **Check Resource Limits:**
```bash
kubectl describe pod <pod-name> | grep -A 5 "Limits\|Requests"
# Pod might be killed due to memory limit (OOMKilled)
```

4. **Inspect Events:**
```bash
kubectl describe pod <pod-name> | tail -20
# Look for: OOMKilled, NodeNotReady, FailedScheduling
```

5. **Execute into pod (if possible):**
```bash
kubectl exec -it <pod-name> -- /bin/sh
# Check configuration, dependencies, permissions
```

6. **Check Health Probes:**
```bash
# Review liveness, readiness, startup probe configuration
kubectl get pod <pod-name> -o yaml | grep -A 10 "Probe"
# Probes may be too strict or failing prematurely
```

**Common Causes and Fixes:**
- **Application error**: Check logs, fix application code
- **Missing config**: Mount ConfigMap/Secret correctly
- **Resource limit**: Increase limits or optimize application
- **Incorrect image**: Fix image name/tag
- **Network issue**: Check network connectivity, DNS
- **Permissions**: Check file permissions, user context

---

## 53. Pending State Diagnosis

**Q: How would you diagnose and resolve pods stuck in Pending due to insufficient cluster resources?**

A:
**Symptoms:**
- Pod status shows Pending
- Pod not scheduled on any node
- Stays pending indefinitely

**Diagnosis:**

1. **Check Pod Events:**
```bash
kubectl describe pod <pod-name>
# Look for: FailedScheduling, Insufficient cpu/memory
```

2. **Check Node Resources:**
```bash
kubectl top nodes
# Check available CPU and memory on nodes

kubectl describe nodes
# Detailed resource allocation per node
# Allocatable resources vs requested resources
```

3. **Check Pod Resource Requests:**
```bash
kubectl get pod <pod-name> -o yaml | grep -A 5 "resources"
# Check if requests exceed node capacity
```

4. **Check Taints and Tolerations:**
```bash
kubectl describe nodes | grep -i taint
# Pod may not have tolerations for node taints
```

5. **Check Node Selectors:**
```bash
kubectl get pod <pod-name> -o yaml | grep -i "nodeSelector\|affinity"
# Pod may have unsatisfiable node selectors
```

**Solutions:**

1. **Add Resources:**
   - Add new nodes to cluster
   - Increase node pool size
   - Scale down other workloads

2. **Reduce Pod Requirements:**
   - Lower CPU/memory requests
   - Optimize application

3. **Fix Scheduling Issues:**
   - Remove impossible node selectors
   - Add tolerations for taints
   - Adjust pod affinity rules

4. **Commands:**
```bash
# Scale up node pool
kubectl scale deployment my-deployment --replicas=10

# Add node (cloud provider specific)
kubectl autoscale deployment my-deployment --min=1 --max=10
```

---

## 54. Project Folder Structure

**Q: How would you structure the project folders to separate manifests, scripts, CI/CD configs, and other related files?**

A:
**Recommended Structure:**
```
kubernetes-project/
â”œâ”€â”€ README.md
â”œâ”€â”€ manifests/
â”‚   â”œâ”€â”€ backend/
â”‚   â”‚   â”œâ”€â”€ deployment.yaml
â”‚   â”‚   â”œâ”€â”€ service.yaml
â”‚   â”‚   â””â”€â”€ configmap.yaml
â”‚   â”œâ”€â”€ frontend/
â”‚   â”‚   â”œâ”€â”€ deployment.yaml
â”‚   â”‚   â”œâ”€â”€ service.yaml
â”‚   â”‚   â””â”€â”€ ingress.yaml
â”‚   â”œâ”€â”€ database/
â”‚   â”‚   â”œâ”€â”€ pvc.yaml
â”‚   â”‚   â””â”€â”€ statefulset.yaml
â”‚   â”œâ”€â”€ monitoring/
â”‚   â”‚   â”œâ”€â”€ prometheus-config.yaml
â”‚   â”‚   â”œâ”€â”€ grafana-dashboard.yaml
â”‚   â”‚   â””â”€â”€ alertmanager-config.yaml
â”‚   â””â”€â”€ logging/
â”‚       â”œâ”€â”€ elasticsearch.yaml
â”‚       â”œâ”€â”€ fluentd-config.yaml
â”‚       â””â”€â”€ kibana.yaml
â”œâ”€â”€ scripts/
â”‚   â”œâ”€â”€ deploy.sh
â”‚   â”œâ”€â”€ cleanup.sh
â”‚   â”œâ”€â”€ setup-monitoring.sh
â”‚   â””â”€â”€ setup-logging.sh
â”œâ”€â”€ ci-cd/
â”‚   â”œâ”€â”€ Jenkinsfile
â”‚   â”œâ”€â”€ .gitlab-ci.yml
â”‚   â”œâ”€â”€ argocd-config/
â”‚   â””â”€â”€ pipeline-scripts/
â”œâ”€â”€ docs/
â”‚   â”œâ”€â”€ setup-guide.md
â”‚   â”œâ”€â”€ troubleshooting.md
â”‚   â””â”€â”€ architecture.md
â””â”€â”€ .gitignore
```

**Benefits:**
- Clear organization
- Easy to locate resources
- Scalable structure
- Separation of concerns

---

## 55. README Documentation

**Q: What should a strong README include for project overview, setup, and usage?**

A:
**README Content:**

1. **Project Overview:**
   - What the project does
   - Technology stack
   - Architecture diagram

2. **Prerequisites:**
   - Kubernetes version
   - Required tools (kubectl, Helm, etc.)
   - System requirements

3. **Setup Instructions:**
   - Cloning repository
   - Creating namespaces
   - Applying manifests
   - Configuring secrets
   - Deploying step-by-step

4. **Usage Guide:**
   - How to access applications
   - Common commands
   - Configuration options

5. **Troubleshooting:**
   - Common issues
   - How to debug
   - Support information

6. **Contributing:**
   - How to contribute
   - Pull request process

---

## 56. Code Quality

**Q: How do you keep the code well-organized, properly commented, and aligned with language best practices?**

A:
**Best Practices:**

1. **Manifest Quality:**
   - Proper YAML indentation
   - Comments explaining configuration
   - Resource limits specified
   - Health probes defined
   - Security contexts applied

2. **Scripts:**
   - Error handling and validation
   - Comments explaining complex logic
   - Exit codes for success/failure
   - Idempotent scripts

3. **Application Code:**
   - Proper logging
   - Error handling
   - Comments for non-obvious logic
   - DRY (Don't Repeat Yourself)
   - Proper variable naming

4. **Configuration:**
   - ConfigMaps for non-sensitive config
   - Secrets for sensitive data
   - Environment variables for flexibility
   - Comments on configuration options

---

## 57. Image Scanning Integration

**Q: How would you explain the purpose and process of integrating image scanning into a CI/CD pipeline?**

A:
**Purpose:**
- Detect vulnerabilities in container images
- Ensure only secure images are deployed
- Meet compliance requirements
- Prevent known vulnerabilities in production
- Shift-left security (early detection)

**Integration Process:**

1. **Image Build Stage:**
   - Build container image
   - Tag with version

2. **Scanning Stage:**
   - Scan image for vulnerabilities
   - Check against CVE databases
   - Validate base image security

3. **Results:**
   - Pass: Proceed to next stage
   - Fail (critical): Reject deployment
   - Warn: Allow with review/approval

4. **Registry:**
   - Push only scanned, approved images
   - Tag with scan results
   - Maintain audit trail

**Tools:**
- Trivy
- Clair
- Anchore
- Quay.io built-in scanning
- ECR image scanning (AWS)

---

## 58. Image Scanning Configuration

**Q: How do you configure an image scanning tool to scan images before deployment?**

A:
**Configuration Elements:**

1. **Scanning Policies:**
   - Criticality thresholds
   - Allowed vs blocked vulnerabilities
   - Exemptions list

2. **CI/CD Integration:**
   - Scan in pipeline after build
   - Automatic registry push on pass
   - Notification on fail

3. **Registry Configuration:**
   - Connect to container registry
   - Credentials configured
   - Push/pull permissions

4. **Reporting:**
   - Scan reports accessible
   - Audit trail maintained
   - Notifications sent on results

---

## 59. Horizontal Pod Autoscaler (HPA)

**Q: How do you configure HPA and explain how it interacts with the frontend deployment?**

A:
**HPA Configuration:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
```

**How it Works:**
1. Monitor CPU/memory metrics of frontend pods
2. Calculate average utilization across replicas
3. Compare against target thresholds
4. Scale up when threshold exceeded
5. Scale down when below threshold
6. Respect min/max replica limits
7. Follow scale behavior rules

**Interaction with Frontend:**
- Dynamically adjusts replicas based on load
- Maintains minimum availability (minReplicas)
- Prevents resource exhaustion (maxReplicas)
- Smooth scaling behavior (stabilization windows)

---

## 60. Scaling Behavior

**Q: How do you demonstrate scaling behavior by showing pod count increases and decreases based on load?**

A:
**Demonstration:**

1. **Setup Monitoring:**
```bash
kubectl get hpa -w
# Watch HPA status in real-time

kubectl top pods -l app=frontend
# Monitor resource usage
```

2. **Generate Load:**
```bash
# Create load-generating pod
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://frontend-service; done"
```

3. **Observe Scaling Up:**
```bash
# Monitor HPA metrics
kubectl describe hpa frontend-hpa
# Watch replicas increase as CPU/memory rises

kubectl get deployment frontend
# See replica count increase
```

4. **Stop Load:**
```bash
# Stop load generation
# Ctrl+C in load generator terminal
```

5. **Observe Scaling Down:**
```bash
# After stabilization period
# Replicas gradually decrease
kubectl get deployment frontend -w
```

**Expected Behavior:**
- Pods scale from minReplicas (2) upward
- No sharp scale-up beyond 100% per period
- Gradual scale-down after load reduces
- Respects stabilization window (300s for down, 0s for up)
- Never exceeds maxReplicas (10)

---

## 61. Advanced Features Implementation (Extra)

**Q: How would you explain the purpose and process of integrating image scanning into a CI/CD pipeline?**

A: (Same as question 57 - covered in Image Scanning Integration)

---

## 62. Image Scanning Tool Configuration (Extra)

**Q: How do you configure an image scanning tool to scan images before deployment?**

A: (Same as question 58 - covered in Image Scanning Configuration)

---

## 63. HPA Configuration (Extra)

**Q: How do you configure HPA and explain how it interacts with the frontend deployment?**

A: (Same as question 59 - covered in Horizontal Pod Autoscaler section)

---

## 64. Scaling Demonstration (Extra)

**Q: How do you demonstrate scaling behavior by showing pod count increases and decreases based on load?**

A: (Same as question 60 - covered in Scaling Behavior section)

---

## 65. Additional Technologies and Features (Extra)

**Q: What additional technologies, security enhancements, or features have you implemented beyond the core requirements?**

A:
**Potential Enhancements:**

1. **Advanced Networking:**
   - Service mesh (Istio, Linkerd)
   - Advanced network policies
   - Multi-cluster networking

2. **Security Hardening:**
   - Pod security policies
   - Network policies with advanced rules
   - Admission webhooks for policy enforcement
   - Seccomp profiles
   - AppArmor/SELinux policies

3. **Advanced Monitoring:**
   - Distributed tracing (Jaeger, Zipkin)
   - Custom metrics with scraping
   - SLO/SLI monitoring
   - Cost monitoring and optimization

4. **Advanced CI/CD:**
   - Blue-green deployments
   - Canary deployments with automatic rollback
   - GitOps with automatic sync
   - Multi-environment deployments

5. **Disaster Recovery:**
   - Cross-cluster replication
   - Automated backup strategies
   - Disaster recovery testing
   - RTO/RPO targets

6. **Advanced Storage:**
   - Dynamic provisioning
   - Storage classes with different performance tiers
   - Data replication policies
   - Backup and recovery procedures

7. **Cost Optimization:**
   - Resource right-sizing
   - Spot instance integration
   - Reserved capacity planning
   - Cluster autoscaling

8. **Compliance and Governance:**
   - Pod security standards
   - Image signing and verification
   - Audit logging and retention
   - Compliance scanning

---

## Summary

This comprehensive guide covers all the Kubernetes learning objectives and demonstrates deep understanding of:
- Architecture and core concepts
- Deployment and management
- Networking and services
- Storage and persistence
- Monitoring and observability
- Security and access control
- Troubleshooting and debugging
- Production-ready deployments
- Advanced features and optimizations

Each question provides practical, implementable answers suitable for student learning and practical application in Kubernetes environments.


