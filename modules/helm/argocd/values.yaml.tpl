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
    hostname: "${domain_name}"
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
      #alb.ingress.kubernetes.io/inbound-cidrs: "${allowed_cidrs}"
      alb.ingress.kubernetes.io/security-groups: "${security_group_id}"
      alb.ingress.kubernetes.io/certificate-arn: "${acm_cert_arn}"
      # External DNS annotation (optional - helps external-dns identify the record)
      external-dns.alpha.kubernetes.io/hostname: "${domain_name}"
    extraAnnotations:
      # This ensures the ALB controller finishes cleaning up before Ingress is deleted
      "kubectl.kubernetes.io/last-applied-configuration": ""  # optional workaround

  extraMetadata:
    finalizers:
      - ingress.k8s.aws/resources  
  
  # ArgoCD server configuration
  config:
    # This tells ArgoCD what its external URL is
    url: "https://${domain_name}"

# Global configuration
global:
  # Ensure ArgoCD knows its domain
  domain: "${domain_name}"

# Optional: Configure RBAC if needed
configs:
  params:
    # Enable insecure mode if you're terminating TLS at ALB
    server.insecure: true