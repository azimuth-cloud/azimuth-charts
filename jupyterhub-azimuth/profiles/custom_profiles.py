import logging
from kubernetes import client, config
import os,yaml

def get_profile_list(spawner):
    logging.info("Loading custom profiles for JupyterHub.")
    profiles = []

    # Include any custom profiles provided via Helm values
    custom_profiles = yaml.safe_load("""\n{{ .Values.user_notebook_profiles.default_profiles | toYaml }}""")
    if custom_profiles:
        profiles.extend(custom_profiles)
    config.load_incluster_config()
    api = client.CoreV1Api()
    nodes = api.list_node().items

    device_id_intel_gpu = "{{  .Values.conditions.device_id_intel_gpu }}" + ".present"
    nvidia_gpu = "{{  .Values.conditions.nvidia_gpu }}" + ".present"

    has_nvidia_gpu = lambda node: node.metadata.labels.get(nvidia_gpu, "") == "true"
    has_intel_gpu = lambda node: node.metadata.labels.get(device_id_intel_gpu, "") == "true"

    if any(map(has_nvidia_gpu, nodes)):
        profiles.extend(yaml.safe_load("""\n{{ .Values.user_profile_values.nvidia_gpu | toYaml }}"""))
    else:
        logging.info("No Nvidia GPU nodes found, skipping Pytorch Nvidia GPU profile.")

    if any(map(has_intel_gpu, nodes)):
        profiles.extend(yaml.safe_load("""\n{{ .Values.user_profile_values.intel_gpu | toYaml }}"""))
    else:
        logging.info("No Intel GPU nodes found, skipping profile.")    
    logging.info(f"Available profiles: {[profile.get('display_name', 'unknown') for profile in profiles]}")

    return profiles