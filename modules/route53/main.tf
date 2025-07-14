# modules/route53/main.tf

resource "aws_route53_zone" "this" {
  name = var.domain_name
  comment = "Hosted zone for ${var.project_tag}"

  tags = {
    Project     = var.project_tag
    Environment = var.environment
  }
}

# resource "aws_route53_record" "app_dns" {
#   zone_id = aws_route53_zone.this.zone_id
#   name    = "${var.subdomain_name}.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [var.alb_dns_name]
# }