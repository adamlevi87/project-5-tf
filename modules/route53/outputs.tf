# modules/route53/outputs.tf

output "zone_id" {
  description = "Route53 Hosted Zone ID"
  value = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "NS records to configure at domain registrar"
  value = aws_route53_zone.this.name_servers
}