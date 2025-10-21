# ==============================================================================
# Route53 - Public Hosted Zone and Records
# ==============================================================================

resource "aws_route53_zone" "public" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-zone"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Alias A record to CloudFront for the frontend
resource "aws_route53_record" "frontend_a" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "${var.frontend_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront hosted zone ID (global, static)
    evaluate_target_health = false
  }
}

# Public API A record to public backend ALB
resource "aws_route53_record" "backend_public_a" {
  zone_id = aws_route53_zone.public.zone_id
  name    = "${var.backend_public_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.backend_public.dns_name
    zone_id                = aws_lb.backend_public.zone_id
    evaluate_target_health = false
  }
}

# Optional AAAA record for IPv6 alias
resource "aws_route53_record" "frontend_aaaa" {
  count   = var.enable_ipv6_alias ? 1 : 0
  zone_id = aws_route53_zone.public.zone_id
  name    = "${var.frontend_subdomain}.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront hosted zone ID (global, static)
    evaluate_target_health = false
  }
}


// Removed: Private hosted zone and internal backend alias record


