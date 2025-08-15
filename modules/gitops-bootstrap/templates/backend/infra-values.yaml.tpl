# Backend infrastructure values - managed by Terraform

image:
  repository: "${ecr_backend_repo_url}"
  digest: "sha256:84783d64c351cf966a7f87eef83793d512a628103676b3d609c5a5c4ad3fcc66"
  tag: ""
  pullPolicy: Always

namespace: ${backend_namespace}

service:
  type: "ClusterIP"
  port: 80

serviceAccount:
  create: false
  name: ${backend_service_account_name}

containerPort: ${backend_container_port}

ingress:
  enabled: true
  host: "${backend_ingress_host}"
  ingressControllerClassResourceName: "alb"
  ingressPath: "/"
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/group.name: "${alb_group_name}"
    #SG list order argo,frontend,backend
    alb.ingress.kubernetes.io/security-groups: "${alb_security_groups}"
    alb.ingress.kubernetes.io/certificate-arn: "${acm_certificate_arn}"
    # External DNS annotation (optional - helps external-dns identify the record)
    external-dns.alpha.kubernetes.io/hostname: "${backend_external_dns_hostname}"

# External Secrets  
externalSecrets:
  enabled: true
  externalSecretName: ${backend_external_secret_name}
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  remoteKey: ${backend_aws_secret_key}
  #targetSecretName: backend-env

secretStore:
  enabled: true
  name: "aws-secretsmanager"
  service: "SecretsManager"
  region: "${aws_region}"
  serviceAccountName: "${backend_service_account_name}"
  syncWave: "-1"