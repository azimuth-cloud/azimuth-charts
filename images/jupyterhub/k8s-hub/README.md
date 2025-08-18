# Dockerfile

This Dockerfile for JupyterHub is a custom image that extends the standard JupyterHub k8s-hub image by installing the Kubernetes Python client, which is required for dynamically configuring the JupyterHub instance based on the features of the host cluster (e.g. providing GPU notebook profiles when the cluster has at least 1 GPU node).