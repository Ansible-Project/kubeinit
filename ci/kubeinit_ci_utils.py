#!/bin/python3

"""
Copyright kubeinit contributors.

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations
under the License.
"""

"""KubeInit's CI utils."""

import os
import re

from google.cloud import storage

from jinja2 import Environment, FileSystemLoader


def render_index(gc_token_path):
    """Render and upload the index file."""
    # Google cloud Storage init
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = gc_token_path
    bucket_name = "kubeinit-ci"
    client = storage.Client()

    jobs = []

    print("'kubeinit_ci_utils.py' ==> Rendering CI jobs index page")
    prefix = 'jobs/'
    delimiter = None

    root_blobs = list(client.list_blobs(bucket_name,
                                        prefix=prefix,
                                        delimiter=delimiter))

    filtered = list(dict.fromkeys([re.sub('/.*', '', sub.name.replace(prefix, '')) for sub in root_blobs]))
    print("'kubeinit_ci_utils.py' ==> Filtered blobs")
    print(filtered)

    print("'kubeinit_ci_utils.py' ==> Rendering page indexes")
    for idx, blob in enumerate(filtered):
        print(str(blob))
        fields = blob.split("-")
        stat = fields[10]
        if stat == '0':
            status = 'Passed'
            badge = 'success'
        elif stat == '1':
            status = 'Failed'
            badge = 'danger'
        elif stat == 'u':
            status = 'Periodic'
            badge = 'primary'
        else:
            status = 'Running'
            badge = 'warning'

        jobs.append({'status': status,
                     'index': idx,
                     'distro': fields[0],
                     'driver': fields[1],
                     'masters': fields[2],
                     'workers': fields[3],
                     'hypervisors': fields[4],
                     'services_type': fields[5],
                     'launch_from': fields[6],
                     'job_type': fields[7],
                     'id': fields[8],
                     'date': fields[9],
                     'badge': badge,
                     'url': 'https://storage.googleapis.com/kubeinit-ci/jobs/' + blob + '/index.html'})

    path = os.path.join(os.path.dirname(__file__))
    file_loader = FileSystemLoader(searchpath=path)
    env = Environment(loader=file_loader)
    template_index = "kubeinit_ci_logs.html.j2"
    print("'kubeinit_ci_utils.py' ==> The path for the template is: " + path)
    template = env.get_template(template_index)
    output = template.render(jobs=jobs)

    bucket = client.get_bucket(bucket_name)
    blob = bucket.blob('index.html')
    blob.upload_from_string(output, content_type='text/html')


def upload_logs_to_google_cloud(job_path, gc_token_path):
    """Upload the CI results to Google cloud Cloud Storage."""
    return_code = 0

    try:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = gc_token_path
        bucket_name = "kubeinit-ci"
        bucket = storage.Client().get_bucket(bucket_name)

        print("'kubeinit_ci_utils.py' ==> ----Uploading logs----")

        print("'kubeinit_ci_utils.py' ==> Path at terminal when executing this file")
        print(os.getcwd() + "\n")

        print("'kubeinit_ci_utils.py' ==> This file path, relative to os.getcwd()")
        print(__file__ + "\n")

        file_list = []
        path_to_upload = os.path.join(os.getcwd(), job_path)
        print("'kubeinit_ci_utils.py' ==> Path to upload: " + path_to_upload)

        for r, _d, f in os.walk(path_to_upload):
            for file in f:
                file_list.append(os.path.join(r, file))

        prefix_path = os.getcwd() + '/'
        print("'kubeinit_ci_utils.py' ==> The initial path: " + prefix_path + " will be removed")

        for entry in file_list:
            try:
                blob = bucket.blob('jobs/' + entry.replace(prefix_path, ''))
                blob.upload_from_filename(entry)
            except Exception as e:
                print("'kubeinit_ci_utils.py' ==> An exception hapened adding the initial log files, some files could not be added")
                print(e)
                return_code = 1
    except Exception as e:
        print("'kubeinit_ci_utils.py' ==> An exception hapened uploading files to Google Cloud Storage")
        print(e)
        return_code = 1
    return return_code


def remove_label(the_label, pr, repo):
    """Remove a label."""
    labels = [label for label in repo.get_labels()]
    if any(filter(lambda l: l.name == the_label, labels)):
        r_label = repo.get_label(the_label)
    else:
        r_label = repo.create_label(the_label, "32CD32")
    pr.remove_from_labels(r_label)


def add_label(the_label, pr, repo):
    """Assign a label."""
    labels = [label for label in repo.get_labels()]
    if any(filter(lambda l: l.name == the_label, labels)):
        new_label = repo.get_label(the_label)
    else:
        new_label = repo.create_label(the_label, "32CD32")
    pr.add_to_labels(new_label)


def get_periodic_jobs_labels(distro='all'):
    """Get the labels for an specific distro."""
    # DISTRO-DRIVER-CONTROLLERS-COMPUTES-HYPERVISORS-[VIRTUAL_SERVICES|CONTAINERIZED_SERVICES]-[LAUNCH_FROM_CONTAINER|LAUNCH_FROM_HOST]

    cdk_configs = ["cdk-libvirt-3-1-3-v-c",
                   "cdk-libvirt-3-0-1-c-h",
                   "cdk-libvirt-1-1-1-c-c",
                   "cdk-libvirt-1-0-1-v-h"]

    okd_configs = ["okd-libvirt-3-1-1-c-h",
                   "okd-libvirt-3-0-3-v-c",
                   "okd-libvirt-1-1-1-v-h",
                   "okd-libvirt-1-0-1-c-c"]

    rke_configs = ["rke-libvirt-3-1-3-c-h",
                   "rke-libvirt-3-0-1-v-h",
                   "rke-libvirt-1-1-1-c-c",
                   "rke-libvirt-1-0-1-v-c"]

    k8s_configs = ["k8s-libvirt-3-1-1-v-h",
                   "k8s-libvirt-3-0-3-c-c",
                   "k8s-libvirt-1-1-1-c-h",
                   "k8s-libvirt-1-0-1-v-c"]

    eks_configs = ["eks-libvirt-3-1-3-v-c",
                   "eks-libvirt-3-0-1-v-h",
                   "eks-libvirt-1-1-1-c-h",
                   "eks-libvirt-1-0-1-c-c"]

    kid_configs = ["kid-libvirt-3-1-1-v-h",
                   "kid-libvirt-3-0-3-c-h",
                   "kid-libvirt-1-1-1-v-c",
                   "kid-libvirt-1-0-1-c-c"]

    okd_rke_configs = ["okd.rke-libvirt-1-2-1-v-c",
                       "okd.rke-libvirt-3-1-1-v-h"]

    if re.match(r"([a-z|0-9|\.]+-[a-z]+-[1-9]-[1-9]-[1-9]-[v|c]-[c|h],?)+", distro):
        print("'kubeinit_ci_utils.py' ==> We are requesting specific job labels")
        req_labels = set(distro.split(","))
        all_labels = set(okd_configs + kid_configs + eks_configs + rke_configs + cdk_configs + k8s_configs + okd_rke_configs)
        if (req_labels.issubset(all_labels)):
            print("'kubeinit_ci_utils.py' ==> The requested labels are defined correctly")
            return req_labels
        else:
            print("'kubeinit_ci_utils.py' ==> The requested labels are not a subset of the allowed labels")
            raise Exception("'kubeinit_ci_utils.py' ==> STOP!")

    configs = []
    if 'okd' in distro and 'okd.rke' not in distro:
        print("'kubeinit_ci_utils.py' ==> Appending OKD configs")
        configs = configs + okd_configs
    if 'rke' in distro and 'okd.rke' not in distro:
        print("'kubeinit_ci_utils.py' ==> Appending RKE configs")
        configs = configs + rke_configs
    if 'kid' in distro:
        print("'kubeinit_ci_utils.py' ==> Appending KID configs")
        configs = configs + kid_configs
    if 'eks' in distro:
        print("'kubeinit_ci_utils.py' ==> Appending EKS configs")
        configs = configs + eks_configs
    if 'cdk' in distro:
        print("'kubeinit_ci_utils.py' ==> Appending CDK configs")
        configs = configs + cdk_configs
    if 'k8s' in distro:
        print("'kubeinit_ci_utils.py' ==> Appending K8S configs")
        configs = configs + k8s_configs
    if 'okd.rke' in distro:
        print("'kubeinit_ci_utils.py' ==> Appending OKD.RKE configs")
        configs = configs + okd_rke_configs
    if distro == "all":
        print("'kubeinit_ci_utils.py' ==> Appending all configs")
        return okd_configs + kid_configs + eks_configs + rke_configs + cdk_configs + k8s_configs + okd_rke_configs
    return configs
