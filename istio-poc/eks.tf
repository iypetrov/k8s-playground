locals {
  k8s_name    = "istio-poc"
  k8s_version = "1.35"

  k8s_addons = {
    cert_manager = "v1.19.3-eksbuild.2"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.15.1"

  name               = local.k8s_name
  kubernetes_version = local.k8s_version

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  create_auto_mode_iam_resources = true
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  addons = {
    cert-manager = {
      addon_version = local.k8s_addons.cert_manager
    }
  }

  tags = {
    Name = local.k8s_name
  }
}

module "cert_manager_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.7.0"

  name = "cert-manager"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = [data.aws_route53_zone.this.arn]

  associations = {
    this = {
      cluster_name    = local.k8s_name
      namespace       = "cert-manager"
      service_account = "cert-manager"
    }
  }
}
