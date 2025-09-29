import logging
from kubernetes import client, config
import yaml

def get_profile_list(spawner):
    logging.info("Loading custom profiles for JupyterHub.")
    profiles = []
    # Include any default profiles provided via Helm values
    default_profiles = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.default_profiles | toYaml }}""")
    if default_profiles:
        profiles.extend(default_profiles)

    # Check for certain types of specialised hardware on the host cluster (e.g. GPUs) 
    config.load_incluster_config()
    api = client.CoreV1Api()
    nodes = api.list_node().items

    # Include any custom profiles provided via Helm values
    custom_profiles = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.custom_profiles | toYaml }}""")
    for label_key, profile_definition in custom_profiles.items():
        label_value = profile_definition["label_value"]
        extra_profiles = profile_definition["profiles"]        
        has_node_label = lambda node: node.metadata.labels.get(label_key) == label_value
        if any(map(has_node_label, nodes)):
            profiles.extend(extra_profiles)
            logging.info(f"Added custom profile for label {label_key} == {label_value}.")

    return profiles