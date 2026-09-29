# AMD AI Workbench
- Currently assumes
  - Monitoring addon is enabled
  - Ingress addon is disabled
  - AMD GPU operator addon is enabled (along with its cert-manager dependency)
  - ArgoCD is installed in the cluster in namespace `argocd`
    - Could deploy an ArgoCD app with name `argocd` or use a custom cluster addon
      in Azimuth config
- Currently uses a fork of [cluster-forge](https://github.com/silogen/cluster-forge)
  with the following modifications:
  - <https://github.com/silogen/cluster-forge/pull/775>
  - <https://github.com/silogen/cluster-forge/pull/778>
- The cluster-forge subchart currently isn't hosted in a Helm repository, so the
  `build-chart.sh` script must be run to pull it into the charts directory. This
  script also produces modified manifests from the subchart to recreate the
  OpenBao bootstrapping procedure which AMD's
  [cluster-bloom tool would normally perform](https://github.com/silogen/cluster-bloom/blob/v2.2.0/pkg/ansible/runtime/playbooks/tasks/deploy_clusterforge/bootstrap_openbao.yaml#L85).