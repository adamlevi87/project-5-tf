server:
  ingress:
    enabled: true
    hosts:
      - argocd.${environment}.${domain_name}
    ingressControllerClassResourceName: "${ingress_controller_class}"

    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: ${node_group_name}
      alb.ingress.kubernetes.io/inbound-cidrs: "${allowed_cidrs}"

