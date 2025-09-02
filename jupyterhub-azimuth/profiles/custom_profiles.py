import logging
from kubernetes import client, config
import os,yaml

def get_profile_list(spawner):
    logging.warning("Loading custom profiles for JupyterHub.")
    profiles = []

    default_profiles = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.default_profiles | toYaml }}""")
    if default_profiles:
        profiles.extend(default_profiles)

    config.load_incluster_config()
    api = client.CoreV1Api()
    nodes = api.list_node().items

    custom_profile = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.custom_profiles | toYaml }}""")
    for label_key, profile_definition in custom_profile.items():
        has_profile = lambda node: node.metadata.labels.get(label_key, "") == "true"
        if any(map(has_profile, nodes)):
            profiles.extend(profile_definition)
            logging.info(f"Added custom profile for label {label_key}.")

    return profiles