# slinky-azimuth

Installs Certmanager, Slurm Operator and a Slurm control plane into the
target K8s cluster.

Only available when installed with Azimuth Apps Operator. Requires the
`managementInstall` field in its AppTemplate spec to be set to `true` e.g

```yaml
apiVersion: apps.azimuth-cloud.io/v1alpha1
kind: AppTemplate
metadata:
  name: slinky
  # Access-control annotations, if required
  # https://azimuth-config.readthedocs.io/en/latest/configuration/13-access-control/#annotations
  # annotations:
  #   acl.azimuth.stackhpc.com/allow-list: ""
  #   acl.azimuth.stackhpc.com/deny-list: ""
  #   acl.azimuth.stackhpc.com/allow-regex: ""
  #   acl.azimuth.stackhpc.com/deny-regex: ""
spec:
  # The chart and versions to use
  chart:
    repo: https://azimuth-cloud.github.io/azimuth-charts
    name: slinky-azimuth
  #   The range of versions to consider
  #   Here, we consider all stable versions (the default)
  versionRange: ">=0.0.0"

  managementInstall: true

  # Synchronisation options
  #   The number of versions to make available
  keepVersions: 5
  #   The frequency at which to check for new versions
  syncFrequency: 86400

  # Default values for the deployment, applied on top of the chart defaults
  defaultValues: {}
```

## Current Limitations

- There are currently no services exposed to access the cluster, accessing
  the cluster requires access to the tenancy's kubeconfig, the Slurm controller
  can then be accessed with
  `kubectl --namespace=slurm exec -it statefulsets/slurm-controller -- bash --login`
- Slinky currently doesn't clean up the PVC created for its database on uninstall
  which future deployments don't have the credentials to access, leading the
  installation to fail. This can be worked around by deleting the
  `slurm-mariadb` and `slurm-controller` PVCs created by the chart manually.
  Future releases will require
  [patching a post-delete hook](https://github.com/azimuth-cloud/azimuth-charts/blob/bed545c4c2d14a4c3f70f2896adf44cb3878b6a2/slinky-azimuth/templates/cleanup-pvcs.yml)
  into a wrapper chart or fork of the upstream Slurm control plane chart.
- CertManager is currently installed as a dependency of this app. Running multiple
  CertManager instances may lead to conflicts, so only one instance of this app
  per cluster is recommended. Future updates could amend this by removing the
  CertManager dependency and instead ensuring its existence per cluster
  via patches to the Azimuth Apps Operator.
