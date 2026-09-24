# Remember to update JupyterHub version at jupyterhub-azimuth/Chart.yaml
# when updating k8s-hub version here
FROM quay.io/jupyterhub/k8s-hub:4.4.2
RUN pip install kubernetes pymysql==1.1.3
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && apt-get install --only-upgrade -y libssh2-1
USER joyvan
