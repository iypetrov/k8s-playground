locals {
  org = "your-org"
  env = "prod"

  gf_aws_account_id = "012345555567"
  gf_region_slug    = "prod-eu-west-2"
  gh_username       = "yourusername"

  default_tags = {
    Organization = local.org
    Environment  = local.env
  }
}

variable "gh_access_token" {
  type      = string
  sensitive = true
}

variable "gf_cloud_access_policy_token" {
  type      = string
  sensitive = true
}

provider "grafana" {
  cloud_access_policy_token = var.gf_cloud_access_policy_token
}

provider "gitsync" {
  url   = "https://github.com/ip812/apps.git"
  token = var.gh_access_token
}

terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "3.22.3"
    }
    gitsync = {
      source  = "ip812/gitsync"
      version = "1.3.0"
    }
  }
}

resource "grafana_cloud_stack" "stack" {
  name        = "${local.org}.grafana.net"
  slug        = local.org
  region_slug = local.gf_region_slug
}

resource "grafana_cloud_access_policy" "access_policy" {
  region       = local.gf_region_slug
  name         = "${local.org}-access-policy"
  display_name = "${local.org}-access-policy"
  scopes = [
    "integration-management:read",
    "integration-management:write",
    "stacks:read",
  ]
  realm {
    type       = "stack"
    identifier = grafana_cloud_stack.stack.id
  }
}

resource "grafana_cloud_access_policy_token" "access_policy_token" {
  region           = local.gf_region_slug
  access_policy_id = grafana_cloud_access_policy.access_policy.policy_id
  name             = "${local.org}-access-policy-token"
  display_name     = "${local.org}-access-policy-token"
  depends_on = [
    grafana_cloud_access_policy.access_policy,
  ]
}

data "aws_iam_policy_document" "trust_grafana" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.gf_aws_account_id}:root"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "grafana_labs_cloudwatch_integration_role" {
  name               = "${local.org}-${local.env}-grafana-labs-cloudwatch-integration-role"
  assume_role_policy = data.aws_iam_policy_document.trust_grafana.json
}

resource "aws_iam_role_policy" "grafana_labs_cloudwatch_integration_policy" {
  name = "${local.org}-${local.env}-grafana-labs-cloudwatch-integration-policy"
  role = aws_iam_role.grafana_labs_cloudwatch_integration_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "gitsync_values_yaml" "monitoring" {
  branch  = "main"
  path    = "values/grafana-k8s-monitoring.yaml"
  content = <<EOT
cluster:
  name: ${local.org}-${local.env}
global:
  scrapeInterval: "60s"
destinations:
  - name: grafana-cloud-metrics
    type: prometheus
    url: ${grafana_cloud_stack.stack.prometheus_remote_write_endpoint}
    auth:
      type: basic
      usernameKey: GF_CLOUD_PROMETHEUS_USER_ID
      passwordKey: GF_CLOUD_ACCESS_POLICY_TOKEN
    secret:
      create: false
      name: grafana-k8s-monitoring-secret

  - name: grafana-cloud-logs
    type: loki
    url: ${grafana_cloud_stack.stack.logs_url}/loki/api/v1/push
    auth:
      type: basic
      usernameKey: GF_CLOUD_LOGS_USER_ID
      passwordKey: GF_CLOUD_ACCESS_POLICY_TOKEN
    secret:
      create: false
      name: grafana-k8s-monitoring-secret
clusterMetrics:
  enabled: true
clusterEvents:
  enabled: false
podLogs:
  enabled: true
applicationObservability:
  enabled: false
alloy-metrics:
  enabled: true
  alloy:
    clustering:
      enabled: false
    extraEnv:
      - name: GCLOUD_RW_API_KEY
        valueFrom:
          secretKeyRef:
            name: grafana-k8s-monitoring-secret
            key: GF_CLOUD_ACCESS_POLICY_TOKEN
      - name: CLUSTER_NAME
        value: ${local.org}-${local.env}
      - name: NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: GCLOUD_FM_COLLECTOR_ID
        value: grafana-k8s-monitoring-\$(CLUSTER_NAME)-\$(NAMESPACE)-\$(POD_NAME)
  remoteConfig:
    enabled: true
    url: ${grafana_cloud_stack.stack.fleet_management_url}
    auth:
      type: basic
      usernameKey: GF_CLOUD_PROFILES_USER_ID
      passwordKey: GF_CLOUD_ACCESS_POLICY_TOKEN
    secret:
      create: false
      name: grafana-k8s-monitoring-secret
alloy-logs:
  enabled: true
  alloy:
    clustering:
      enabled: false
    extraEnv:
      - name: GCLOUD_RW_API_KEY
        valueFrom:
          secretKeyRef:
            name: grafana-k8s-monitoring-secret
            key: GF_CLOUD_ACCESS_POLICY_TOKEN
      - name: CLUSTER_NAME
        value: ${local.org}-${local.env}
      - name: NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: NODE_NAME
        valueFrom:
          fieldRef:
            fieldPath: spec.nodeName
      - name: GCLOUD_FM_COLLECTOR_ID
        value: grafana-k8s-monitoring-\$(CLUSTER_NAME)-\$(NAMESPACE)-alloy-logs-\$(NODE_NAME)
  remoteConfig:
    enabled: true
    url: ${grafana_cloud_stack.stack.fleet_management_url}
    auth:
      type: basic
      usernameKey: GF_CLOUD_PROFILES_USER_ID
      passwordKey: GF_CLOUD_ACCESS_POLICY_TOKEN
    secret:
      create: false
      name: grafana-k8s-monitoring-secret
alloy-singleton:
  enabled: false
alloy-receiver:
  enabled: false
EOT
}
