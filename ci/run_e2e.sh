#!/bin/bash
set -e

#############################################################################
#                                                                           #
# Copyright kubeinit contributors.                                          #
#                                                                           #
# Licensed under the Apache License, Version 2.0 (the "License"); you may   #
# not use this file except in compliance with the License. You may obtain   #
# a copy of the License at:                                                 #
#                                                                           #
# http://www.apache.org/licenses/LICENSE-2.0                                #
#                                                                           #
# Unless required by applicable law or agreed to in writing, software       #
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT #
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the  #
# License for the specific language governing permissions and limitations   #
# under the License.                                                        #
#                                                                           #
#############################################################################

echo "(run_e2e.sh) ==> Executing run.sh ..."

REPOSITORY="${1}"
BRANCH_NAME="${2}"
PULL_REQUEST="${3}"
DISTRO="${4}"
DRIVER="${5}"
MASTERS="${6}"
WORKERS="${7}"
HYPERVISORS="${8}"
SERVICES_TYPE="${9}"
JOB_TYPE="${10}"
LAUNCH_FROM="${11}"

ANSIBLE_VERBOSITY="${ANSIBLE_VERBOSITY:-v}"

KUBEINIT_MAIN_CI_REPOSITORY="https://github.com/kubeinit/kubeinit.git"

echo "The repository is $REPOSITORY"
echo "The branch is $BRANCH_NAME"
echo "The pull request is $PULL_REQUEST"
echo "The distro is $DISTRO"
echo "The driver is $DRIVER"
echo "The amount of master nodes is $MASTERS"
echo "The amount of worker nodes is $WORKERS"
echo "The amount of hypervisors is $HYPERVISORS"
echo "The services type is $SERVICES_TYPE"
echo "The job type is $JOB_TYPE"
echo "The ansible will be launched from $LAUNCH_FROM"
echo "The ansible verbosity is $ANSIBLE_VERBOSITY"

echo "(run_e2e.sh) ==> Removing ara data ..."
# This will nuke the ara database so in each run we have a clean env
rm -rf /root/.ara/server/ansible.sqlite
ara-manage migrate

echo "(run_e2e.sh) ==> Configuring ara callback ..."
export ANSIBLE_CALLBACK_PLUGINS="$(python3 -m ara.setup.callback_plugins)"

echo "(run_e2e.sh) ==> Removing old tmp files ..."
# Remove old code
rm -rf tmp
mkdir -p tmp
cd tmp

echo "(run_e2e.sh) ==> Downloading KubeInit's code ..."
# Get the kubeinit code we will test
if [[ "$JOB_TYPE" == "pr" ]]; then
    # Keep as an example for cherry-picking workarounds
    # git remote add ccamacho https://github.com/ccamacho/kubeinit.git
    # git fetch ccamacho
    # git cherry-pick 58f718a29d5611234304b1e144a69
    git clone -n $KUBEINIT_MAIN_CI_REPOSITORY -b $BRANCH_NAME
    cd kubeinit
    git fetch origin pull/$PULL_REQUEST/head
    git checkout -b pr  FETCH_HEAD
    git log -n 5 --pretty=oneline
else
    git clone $KUBEINIT_MAIN_CI_REPOSITORY
    cd kubeinit
fi

# Install the collection
echo "(run_e2e.sh) ==> Installing KubeInit ..."
cd kubeinit
rm -rf ~/.ansible/collections/ansible_collections/kubeinit/kubeinit
ansible-galaxy collection build -v --force --output-path releases/
ansible-galaxy collection install --force --force-with-deps releases/kubeinit-kubeinit-`cat galaxy.yml | shyaml get-value version`.tar.gz
cd ..

# We configure here our main scenario variables
# In this case we need to adjust the DNS we will
# use and in the case of the okd.rke distro we
# need to make sure we wont remove the previously
# deployed cluster resources, like guests and
# SDN resources

echo "(run_e2e.sh) ==> Configuring KubeInit's scenario file ..."
if [[ "$DISTRO" == "okd.rke" && "$JOB_TYPE" == "submariner" ]]; then
# Here we will deploy a submariner environment testing a PR from
# the submariner-operator repository
sudo tee scenario_variables.yml > /dev/null <<EOF
kubeinit_submariner_test_pr_url: "https://github.com/submariner-io/submariner-operator/pull/$PULL_REQUEST"
kubeinit_libvirt_destroy_all_guests: False
kubeinit_common_dns_public: 10.64.63.6
EOF
elif [[ "$DISTRO" == "okd.rke" ]]; then
# Here we will deploy a submariner environment based on kubeinit's code
# assuming the code from submariner works (fetching latest code from upstream)
sudo tee scenario_variables.yml > /dev/null <<EOF
kubeinit_common_dns_public: 10.64.63.6
kubeinit_libvirt_destroy_all_guests: False
EOF
else
# Here we will deploy a regular job to test the distributions
# that are supported
sudo tee scenario_variables.yml > /dev/null <<EOF
kubeinit_common_dns_public: 10.64.63.6
kubeinit_libvirt_destroy_all_guests: True
EOF
fi

cat scenario_variables.yml
# Before doing anything we make sure the environment is completely cleared
# like remove podman connections, guests, and libvirt networks

echo "(run_e2e.sh) ==> Cleaning hypervisor ..."
echo "(run_e2e.sh) ==> Removing podman connections ..."
for i in $(podman --remote system connection list | sed -e 1d -e 's/[* ].*//'); do
    podman --remote system connection remove $i
done;
echo "(run_e2e.sh) ==> Removing guests ..."
for i in $(virsh -q list | awk '{ print $2 }'); do
    virsh destroy $i;
    virsh undefine $i --remove-all-storage;
done;
echo "(run_e2e.sh) ==> Removing nets ..."
for i in $(virsh -q net-list | awk '{ print $1 }'); do
    virsh net-destroy $i;
    virsh net-undefine $i;
done;

# Let's configure the inventory file based in the variables
# this script is receiving

echo "(run_e2e.sh) ==> Preparing the inventory ..."
if [[ "$MASTERS" == "1" ]]; then
    find ./hosts/ -type f -exec sed -i -E -e "s/.*-controller-02/#-controller-02/g" {} \;
    find ./hosts/ -type f -exec sed -i -E -e "s/.*-controller-03/#-controller-03/g" {} \;
fi

if [[ "$WORKERS" == "0" ]]; then
    find ./hosts/ -type f -exec sed -i -E -e "s/.*-compute-01/#-compute-01/g" {} \;
    find ./hosts/ -type f -exec sed -i -E -e "s/.*-compute-02/#-compute-02/g" {} \;
fi

if [[ "$WORKER" == "1" ]]; then
    find ./hosts/ -type f -exec sed -i -E -e "s/.*-compute-02/#-compute-02/g" {} \;
fi

# We reduce the default disk volume size used in the nodes
find ./hosts/ -type f -exec sed -i -E -e "s/disk=25G/disk=20G/g" {} \;
find ./hosts/ -type f -exec sed -i -E -e "s/disk=30G/disk=20G/g" {} \;
find ./hosts/ -type f -exec sed -i -E -e "s/disk=150G/disk=20G/g" {} \;

# If the distro that will be deployed is okd.rke that means
# that we will deploy two clusters in the same libvirt host
# to do so we need to move the RKE cluster IP addresses
if [[ "$DISTRO" == "okd.rke" ]]; then
    sed -i "s/10.0.0.1 /10.0.0.201 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.2 /10.0.0.202 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.3 /10.0.0.203 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.4 /10.0.0.204 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.5 /10.0.0.205 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.6 /10.0.0.206 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.7 /10.0.0.207 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.8 /10.0.0.208 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.9 /10.0.0.209 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.10 /10.0.0.210 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.11 /10.0.0.211 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.12 /10.0.0.212 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.13 /10.0.0.213 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.14 /10.0.0.214 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.15 /10.0.0.215 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.100 /10.0.0.250 /g" ./hosts/rke/inventory
    sed -i "s/10.0.0.100/10.0.0.250/g" ./hosts/rke/inventory
fi

#
# For the multinode deployment we only support a 3 nodes cluster
#
if [[ "$HYPERVISORS" != "1" && "$HYPERVISORS" != "3" ]]; then
    echo "(run_e2e.sh) ==> We only support 1 and 3 nodes clusters"
    exit 1
fi

if [[ "$HYPERVISORS" == "3" ]]; then
    # We enable the other 2 HVs
    find ./hosts/ -type f -exec sed -i -E -e "/# hypervisor-02 ansible_host=tyto/ s/# //g" {} \;
    find ./hosts/ -type f -exec sed -i -E -e "/# hypervisor-03 ansible_host=strix/ s/# //g" {} \;

    #
    # We balance the cluster nodes across the HVs
    #
    # Controllers
    find ./hosts/ -type f -exec sed -i -E -e "/.*-controller-01 ansible_host/ s/hypervisor-01/hypervisor-01/g"  {} \;
    find ./hosts/ -type f -exec sed -i -E -e "/.*-controller-02 ansible_host/ s/hypervisor-01/hypervisor-02/g" {} \;
    find ./hosts/ -type f -exec sed -i -E -e "/.*-controller-03 ansible_host/ s/hypervisor-01/hypervisor-03/g" {} \;

    # Computes
    find ./hosts/ -type f -exec sed -i -E -e "/.*-compute-01 ansible_host/ s/hypervisor-01/hypervisor-01/g" {} \;
    find ./hosts/ -type f -exec sed -i -E -e "/.*-compute-02 ansible_host/ s/hypervisor-01/hypervisor-02/g" {} \;

    # Services
    find ./hosts/ -type f -exec sed -i -E -e "/.*-service-01 ansible_host/ s/hypervisor-01/hypervisor-03/g" {} \;

    # Bootstrap
    find ./hosts/ -type f -exec sed -i -E -e "/.*-bootstrap-01 ansible_host/ s/hypervisor-01/hypervisor-02/g" {} \;
fi

#
# We change the way the services node is deployed, by default
# it will live in a virtual machine if the parameter is changed
# to container, then all the services will be deployed in a pod
# in the first hypervisor.
#
if [[ "$SERVICES_TYPE" == "c" ]]; then
    find ./hosts/ -type f -exec sed -i -E -e "/.*-service-01 ansible_host/ s/type=virtual/type=container/g" {} \;
fi

echo "(run_e2e.sh) ==> The inventory content..."
cat ./hosts/$DISTRO/inventory || true
#
# The last step is to run the deployment
#

echo "(run_e2e.sh) ==> Deploying the cluster ..."

#
# The deployment playbook can be launched from a container [c]
# or directly from the host [h]
#
if [[ "$LAUNCH_FROM" == "c" ]]; then
    if [[ "$DISTRO" == "okd.rke" ]]; then
        podman build -t kubeinit/kubeinit .

        podman run --rm -it \
            -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:z \
            -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:z \
            -v /etc/hosts:/etc/hosts \
            kubeinit/kubeinit \
                --user root \
                -${ANSIBLE_VERBOSITY} -i ./hosts/okd/inventory \
                --become \
                --become-user root \
                -e kubeinit_bind_multicluster_dns_forward_enabled=True \
                -e @scenario_variables.yml \
                -e ansible_ssh_user=root \
                ./playbooks/okd.yml

        podman run --rm -it \
            -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:z \
            -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:z \
            -v /etc/hosts:/etc/hosts \
            kubeinit/kubeinit \
                --user root \
                -${ANSIBLE_VERBOSITY} -i ./hosts/rke/inventory \
                --become \
                --become-user root \
                -e kubeinit_bind_multicluster_dns_forward_enabled=True \
                -e kubeinit_libvirt_multicluster_keep_predefined_networks=True \
                -e @scenario_variables.yml \
                -e ansible_ssh_user=root \
                ./playbooks/rke.yml

        podman run --rm -it \
            -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:z \
            -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:z \
            -v /etc/hosts:/etc/hosts \
            kubeinit/kubeinit \
                --user root \
                -${ANSIBLE_VERBOSITY} -i ./hosts/rke/inventory \
                --become \
                --become-user root \
                -e kubeinit_submariner_is_broker=True \
                -e @scenario_variables.yml \
                -e ansible_ssh_user=root \
                ./playbooks/submariner.yml

        podman run --rm -it \
            -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:z \
            -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:z \
            -v /etc/hosts:/etc/hosts \
            kubeinit/kubeinit \
                --user root \
                -${ANSIBLE_VERBOSITY} -i ./hosts/okd/inventory \
                --become \
                --become-user root \
                -e kubeinit_submariner_is_secondary=True \
                -e @scenario_variables.yml \
                -e ansible_ssh_user=root \
                ./playbooks/submariner.yml

        podman run --rm -it \
            -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:z \
            -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:z \
            -v /etc/hosts:/etc/hosts \
            kubeinit/kubeinit \
                --user root \
                -${ANSIBLE_VERBOSITY} -i ./hosts/okd/inventory \
                --become \
                --become-user root \
                -e kubeinit_submariner_is_secondary=True \
                -e @scenario_variables.yml \
                -e ansible_ssh_user=root \
                ./playbooks/ubmariner-subctl-verify.yml
    else
        # This will deploy a single kubernetes cluster based
        # on the $DISTRO variable from a container

        podman build -t kubeinit/kubeinit .

        podman run --rm -it \
            -v ~/.ssh/id_rsa:/root/.ssh/id_rsa:z \
            -v ~/.ssh/id_rsa.pub:/root/.ssh/id_rsa.pub:z \
            -v /etc/hosts:/etc/hosts \
            kubeinit/kubeinit \
                --user root \
                -${ANSIBLE_VERBOSITY} -i ./hosts/$DISTRO/inventory \
                --become \
                --become-user root \
                -e @scenario_variables.yml \
                -e ansible_ssh_user=root \
                ./playbooks/$DISTRO.yml
    fi
elif [[ "$LAUNCH_FROM" == "h" ]]; then
    if [[ "$DISTRO" == "okd.rke" ]]; then
        # This will:
        # Deploy two kubernetes clusters,
        # it will install subctl in the services nodes of the broker cluster,
        # it will create a submariner broker cluster,
        # it will install subctl in the services nodes of the seconday node,
        # and it will join the secondary cluster to the broker.

        # Deploy the fisrt cluster (okd)
        ansible-playbook \
            --user root \
            -${ANSIBLE_VERBOSITY} -i ./hosts/okd/inventory \
            --become \
            --become-user root \
            -e kubeinit_bind_multicluster_dns_forward_enabled=True \
            -e @scenario_variables.yml \
            ./playbooks/okd.yml

        # Deploy the second cluster (rke)
        ansible-playbook \
            --user root \
            -${ANSIBLE_VERBOSITY} -i ./hosts/rke/inventory \
            --become \
            --become-user root \
            -e kubeinit_bind_multicluster_dns_forward_enabled=True \
            -e kubeinit_libvirt_multicluster_keep_predefined_networks=True \
            -e @scenario_variables.yml \
            ./playbooks/rke.yml

        # Deploy submariner as broker (rke)
        ansible-playbook \
            --user root \
            -${ANSIBLE_VERBOSITY} -i ./hosts/rke/inventory \
            --become \
            --become-user root \
            -e kubeinit_submariner_is_broker=True \
            -e @scenario_variables.yml \
            ./playbooks/submariner.yml

        # Deploy submariner as secondary (okd)
        ansible-playbook \
            --user root \
            -${ANSIBLE_VERBOSITY} -i ./hosts/okd/inventory \
            --become \
            --become-user root \
            -e kubeinit_submariner_is_secondary=True \
            -e @scenario_variables.yml \
            ./playbooks/submariner.yml

        # Run subctl verify to check cluster status in the sec cluster (okd)
        ansible-playbook \
            --user root \
            -${ANSIBLE_VERBOSITY} -i ./hosts/okd/inventory \
            --become \
            --become-user root \
            -e kubeinit_submariner_is_secondary=True \
            -e @scenario_variables.yml \
            ./playbooks/submariner-subctl-verify.yml
    else
        ansible-playbook \
            --user root \
            -${ANSIBLE_VERBOSITY} -i ./hosts/$DISTRO/inventory \
            --become \
            --become-user root \
            -e @scenario_variables.yml \
            ./playbooks/$DISTRO.yml
    fi

else
    echo "(run_e2e.sh) ==> The parameter launch from do not match a valid value [c|h]"
    exit 1
fi
