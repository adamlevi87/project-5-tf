server:
  # Service configuration
  service:
    type: ClusterIP
  
  # Service account configuration
  serviceAccount:
    create: false
    name: "${service_account_name}"
  
  # Ingress configuration for AWS ALB
  ingress:
    enabled: true
    ingressClassName: alb
    hostname: "${domain}"
    path: /
    pathType: Prefix
    annotations:
      # ALB Controller annotations
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: "${node_group_name}"
      alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60
      # CIDR restrictions
      alb.ingress.kubernetes.io/inbound-cidrs: "${allowed_cidrs}"
      # External DNS annotation (optional - helps external-dns identify the record)
      external-dns.alpha.kubernetes.io/hostname: "${domain}"
  
  # ArgoCD server configuration
  config:
    # This tells ArgoCD what its external URL is
    url: "https://${domain}"

# Global configuration
global:
  # Ensure ArgoCD knows its domain
  domain: "${domain}"

# Optional: Configure RBAC if needed
configs:
  params:
    # Enable insecure mode if you're terminating TLS at ALB
    server.insecure: true