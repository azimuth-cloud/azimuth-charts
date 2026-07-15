GIT_REPO=$(yq '.root.clusterForge.repoUrl' values.yaml)
GIT_VERSION=$(yq '.root.clusterForge.targetRevision' values.yaml)
git clone --depth 1 --branch $GIT_VERSION $GIT_REPO /tmp/cluster-forge
# Copying inital ArgoCD-less bootstrap of OpenBao secrets from
# https://github.com/silogen/cluster-bloom/blob/v2.2.0/pkg/ansible/runtime/playbooks/tasks/deploy_clusterforge/bootstrap_openbao.yaml#L85
sed "s|name: openbao-secret-manager-scripts|name: openbao-secret-manager-scripts-init|g" /tmp/cluster-forge/sources/openbao-config/0.1.0/templates/openbao-secret-manager-cm.yaml > templates/openbao-secret-manager-cm.yaml
sed \
-e "s|name: openbao-secrets-config|name: openbao-secrets-init-config|g" \
-e "s|.Values|.Values.openbaoBootstrap|g" \
/tmp/cluster-forge/sources/openbao-config/0.1.0/templates/openbao-secret-definitions.yaml > templates/openbao-secret-definitions.yaml
# Cluster-forge root chart doesn't have Helm repository so packaging tarball directly into charts dir
helm package /tmp/cluster-forge/root --destination ./charts
