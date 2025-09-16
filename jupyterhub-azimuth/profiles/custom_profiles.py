import logging
from kubernetes import client, config
import os, yaml

def get_profile_list(spawner):
    logging.info("Loading custom profiles for JupyterHub.")
    profiles = []

    # Include any default profiles provided via Helm values
    default_profiles = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.default_profiles | toYaml }}""")
    if default_profiles:
        profiles.extend(default_profiles)

    # Check for certain types of specialised hardware on the host cluster (e.g. GPUs) 
    # and add some appropriate notebook profiles
    config.load_incluster_config()
    api = client.CoreV1Api()
    nodes = api.list_node().items
<<<<<<< Updated upstream

    # Include any default profiles provided via Helm values by finding if the
    # specific label is present on any node in the cluster
=======
>>>>>>> Stashed changes
    custom_profile = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.custom_profiles | toYaml }}""")
    for label_key, profile_definition in custom_profile.items():
        has_profile = lambda node: node.metadata.labels.get(label_key, "") == "true"
        if any(map(has_profile, nodes)):
            profiles.extend(profile_definition)
            logging.info(f"Added custom profile for label {label_key}.")

    return profiles