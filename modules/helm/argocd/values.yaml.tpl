server:
  service:
    type: ClusterIP
  
  serviceAccount:
    create: false
    name: "${service_account_name}"
  
  ingress:
    enabled: true
    hosts:
      - "argocd.${environment}.${domain_name}"
    ingressControllerClassResourceName: "${ingress_controller_class}"
    ingressPath: "/"

    annotations:
      alb.ingress.kubernetes.io/scheme: "internet-facing"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: ${node_group_name}
      alb.ingress.kubernetes.io/inbound-cidrs: "${allowed_cidrs}"

  config:
    url: "https://argocd.${environment}.${domain_name}"

