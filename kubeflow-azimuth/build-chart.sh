#!/bin/bash
set -e
if [[ ! $(kustomize version) == *v5.* ]]; then
    echo "Kustomize version 5 or later required for chart build."
    echo "Please install a valid version then try again."
    exit 1
fi

OUTPUT_FILE=kustomize-build-output.yml
kustomize build overlay/ --output $OUTPUT_FILE

# NOTE(scott): kustomize image source patches don't capture 
# default notebook images used by kubeflow jupyterhub platform 
# since these are defined within the data.'spawner_ui_config.yaml'
# field of the ConfigMap 'jupyter-web-app-config-xxxxxxx'
# Use sed here to replace these images with ghcr versions
IMAGES=(
    "jupyter-scipy"
    "jupyter-pytorch-full"
    "jupyter-pytorch-cuda-full"
    "jupyter-tensorflow-full"
    "jupyter-tensorflow-cuda-full"
)
for image in ${IMAGES[@]}; do
    # Backup suffix is required on MacOS
    sed -i.bak "s|kubeflownotebookswg/${image}|ghcr.io/stackhpc/azimuth-charts/docker.io/kubeflownotebookswg/${image}|g" $OUTPUT_FILE
    # suffix to -i option is mandatory on MacOS sed, remove backup file here
    rm $OUTPUT_FILE.bak
done

# Convert kustomize output to helm chart directory structure
python3 to-helm-chart.py
