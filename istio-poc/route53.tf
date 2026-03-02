data "aws_route53_zone" "this" {
  zone_id = var.zone_id
}

data "aws_lbs" "k8s_ingress_lb_arns" {
  tags = {
    "eks:eks-cluster-name" = "${local.k8s_name}"
  }
}

data "aws_lb" "k8s_ingress_lb" {
  for_each = toset(data.aws_lbs.k8s_ingress_lb_arns.arns)
  arn      = each.value
}

resource "aws_route53_record" "grafana_subdomain" {
  count   = length(data.aws_lb.k8s_ingress_lb) > 0 ? 1 : 0
  zone_id = var.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = values(data.aws_lb.k8s_ingress_lb)[0].dns_name
    zone_id                = values(data.aws_lb.k8s_ingress_lb)[0].zone_id
    evaluate_target_health = true
  }
}
