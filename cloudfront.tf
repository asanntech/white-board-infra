# ==============================================================================
# CloudFront + ACM (us-east-1)
# ==============================================================================

locals {
  frontend_fqdn = "${var.frontend_subdomain}.${var.domain_name}"
}

resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = local.frontend_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend-cert"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_route53_record" "frontend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.public.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_cert_validation : record.fqdn]
}

// OAC is not applicable to ALB/custom origins; do not configure OAC here

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = var.enable_cdn
  is_ipv6_enabled     = true
  comment             = "${var.project_name}-${var.environment}-frontend"
  wait_for_deployment = true

  aliases = [local.frontend_fqdn]

  origin {
    domain_name = aws_lb.frontend.dns_name
    origin_id   = "alb-frontend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    compress = true

    forwarded_values {
      query_string = true
      headers      = ["*"]
      cookies {
        forward = "all"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  price_class = var.cloudfront_price_class

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_acm_certificate_validation.frontend]
}


