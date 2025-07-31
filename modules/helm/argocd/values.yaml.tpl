global:
  domain: ""
server:
  service:
    type: ClusterIP
  
  serviceAccount:
    create: false
    name: "${service_account_name}"
  
  ingress:
    enabled: true
    hosts:
      - "${domain_name}"
    ingressClassName: "${ingress_controller_class}"
    path: "/"

    annotations:
      alb.ingress.kubernetes.io/scheme: "internet-facing"
      alb.ingress.kubernetes.io/target-type: "ip"
      alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
      alb.ingress.kubernetes.io/ssl-redirect: "443"
      alb.ingress.kubernetes.io/group.name: ${node_group_name}
      alb.ingress.kubernetes.io/inbound-cidrs: "${allowed_cidrs}"

  config:
    url: "https://${domain_name}"

