<p style="text-align: center" align="center">
    <a href="https://www.kubeinit.com"><img src="https://raw.githubusercontent.com/ccamacho/kubeinit/master/images/logo.svg?sanitize=true" alt="The KUBErnetes INITiator"/></a>
</p>

**The KUBErnetes INITiator**

<p style="text-align: center" align="center">
    <a href="https://www.python.org"><img height="30px" src="https://raw.githubusercontent.com/pystol/pystol-docs/master/assets/badges/made-with-python.svg?sanitize=true"/> </a>
    <a href="https://www.ansible.com"><img height="30px" src="https://raw.githubusercontent.com/pystol/pystol-docs/master/assets/badges/made-with-ansible.svg?sanitize=true"/> </a>
    <a href="https://www.kubeinit.com"><img height="30px" src="https://raw.githubusercontent.com/pystol/pystol-docs/master/assets/badges/made-with-love.svg?sanitize=true"/> </a>
    <a href="https://www.kubeinit.com"><img height="30px" src="https://raw.githubusercontent.com/pystol/pystol-docs/master/assets/badges/cloud-native.svg?sanitize=true"/> </a>
</p>

<p style="text-align: center" align="center">
    <a href="https://github.com/ccamacho/kubeinit/actions?workflow=linters"><img height="20px" src="https://github.com/ccamacho/kubeinit/workflows/linters/badge.svg?event=push"/> </a>
    <a href="https://github.com/ccamacho/kubeinit/actions?workflow=docs_build"><img height="20px" src="https://github.com/ccamacho/kubeinit/workflows/docs_build/badge.svg?event=push"/> </a>
    <a href="https://github.com/ccamacho/kubeinit/actions?workflow=molecule"><img height="20px" src="https://github.com/ccamacho/kubeinit/workflows/molecule/badge.svg?event=push"/> </a>
    <a href="https://opensource.org/licenses/Apache-2.0"><img height="20px" src="https://img.shields.io/badge/License-Apache%202.0-blue.svg"/> </a>
</p>

# Abstract

KubeInit provides Ansible playbooks and roles for the deployment and configuration of multiple Kubernetes distributions.
The main goal of KubeInit is to have a fully automated way to deploy in a single command a curated list of
prescribed architectures.

# Documentation

KubeInit's documentation is hosted in [this same repository](https://ccamacho.github.io/kubeinit/).
The documentation is rendered using Sphinx and uploaded to GitHub pages using a GitHub action.

# Requirements

* A server with enough RAM and disk space (120GB in RAM and 300GB in disk).
* A hypervisor with Centos 8.
* We assume that the hypervisor node is called nyctea (defined in the inventory).
* Have root access with certificates.
* Adjust the inventory file to suit your needs i.e. [the worker nodes](https://github.com/ccamacho/kubeinit/blob/master/hosts/okd/inventory#L66)
 you will need in your cluster.

```bash
ssh root@nyctea
ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -P ""
curl -sS https://github.com/<your_github_username>.keys >> ~/.ssh/authorized_keys
exit
```

# How to run

The following example command will deploy a multi-master OKD 4.5 cluster with 1 worker node
in a single command and in approximately 30 minutes.

```bash
git clone https://github.com/ccamacho/kubeinit.git
cd kubeinit
ansible-playbook \
    --user root \
    -v -i ./hosts/okd/inventory \
    --become \
    --become-user root \
    ./playbooks/okd.yml
```

After provisioning any of the scenarios, you should have your environment ready to go.

To connect to the nodes from the hypervisor use the IP addresses from the inventory files.
