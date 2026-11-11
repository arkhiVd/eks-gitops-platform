# Argo CD is the last thing Terraform installs. It then syncs gitops/apps (app-of-apps)
# from the public repo and owns everything else in the cluster.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.17.2"

  values = [file("${path.module}/values/argocd.yaml")]

  depends_on = [helm_release.lbc]
}

resource "helm_release" "argocd_root" {
  name       = "argocd-root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.8"

  values = [yamlencode({
    applications = {
      root = {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_revision
          path           = "gitops/apps"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd, module.karpenter, kubernetes_secret_v1.grafana_admin]
}

# Grafana admin credentials. Generated here so no password sits in git; kube-prometheus-stack
# reads this secret through grafana.admin.existingSecret.
resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }
  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_admin.result
  }
}
