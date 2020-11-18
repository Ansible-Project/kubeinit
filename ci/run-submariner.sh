#!/bin/bash
set -e

BRANCH_NAME="$1"
PULL_REQUEST="$2"
VARS_YAML_PATH="$3"
DISTRO="$4"
DRIVER="$5"
MASTER="$6"
WORKER="$7"
SCENARIO="$8"

echo "The branch is $BRANCH_NAME"
echo "The pull request is $PULL_REQUEST"
echo "The vars.yaml path is: $VARS_YAML_PATH"
echo "The distro is $DISTRO"
echo "The driver is $DRIVER"
echo "The amount of master nodes is $MASTER"
echo "The amount of worker nodes is $WORKER"
echo "The scenario is $SCENARIO"

# Clone the repo
rm -rf tmp
mkdir -p tmp
cd tmp
git clone -n https://github.com/kubeinit/kubeinit.git
cd kubeinit

# TODO:Remove when merged
# Keep as an example for cherry-picking workarounds
# git remote add ccamacho https://github.com/ccamacho/kubeinit.git
# git fetch ccamacho
# git cherry-pick 58f718a29d5611234304b1e144a69

sudo tee scenario_variables.yml > /dev/null <<'EOF'
kubeinit_submariner_test_pr_url: "https://github.com/submariner-io/submariner-operator/pull/$PULL_REQUEST"
EOF


# By default we deploy 3 master and 1 worker cluster
# the case of 3 master is already by default
# the case of 1 worker is already by default
# We use the .*- expresion to comment the line
# no matter the distro, i.e., okd-master or k8s-master
if [[ "$DISTRO" == "multiple" ]]; then
    if [[ "$MASTER" == "1" ]]; then
        sed -i -E "s/.*-master-02/#-master-02/g" ./hosts/okd/inventory
        sed -i -E "s/.*-master-02/#-master-02/g" ./hosts/rke/inventory
        sed -i -E "s/.*-master-02/#-master-02/g" ./hosts/k8s/inventory
        sed -i -E "s/.*-master-02/#-master-02/g" ./hosts/cdk/inventory

        sed -i -E "s/.*-master-03/#-master-03/g" ./hosts/okd/inventory
        sed -i -E "s/.*-master-03/#-master-03/g" ./hosts/rke/inventory
        sed -i -E "s/.*-master-03/#-master-03/g" ./hosts/k8s/inventory
        sed -i -E "s/.*-master-03/#-master-03/g" ./hosts/cdk/inventory
    fi

    if [[ "$WORKER" == "0" ]]; then
        sed -i -E "s/.*-worker-01/#-worker-01/g" ./hosts/okd/inventory
        sed -i -E "s/.*-worker-01/#-worker-01/g" ./hosts/rke/inventory
        sed -i -E "s/.*-worker-01/#-worker-01/g" ./hosts/k8s/inventory
        sed -i -E "s/.*-worker-01/#-worker-01/g" ./hosts/cdk/inventory
    fi

    if [[ "$WORKER" == "2" ]]; then
        sed -i -E "/# .*-worker-02/ s/# //g" ./hosts/okd/inventory
        sed -i -E "/# .*-worker-02/ s/# //g" ./hosts/rke/inventory
        sed -i -E "/# .*-worker-02/ s/# //g" ./hosts/k8s/inventory
        sed -i -E "/# .*-worker-02/ s/# //g" ./hosts/cdk/inventory
    fi
else
    if [[ "$MASTER" == "1" ]]; then
        sed -i -E "s/.*-master-02/#-master-02/g" ./hosts/$DISTRO/inventory
        sed -i -E "s/.*-master-03/#-master-03/g" ./hosts/$DISTRO/inventory
    fi

    if [[ "$WORKER" == "0" ]]; then
        sed -i -E "s/.*-worker-01/#-worker-01/g" ./hosts/$DISTRO/inventory
    fi

    if [[ "$WORKER" == "2" ]]; then
        sed -i -E "/# .*-worker-02/ s/# //g" ./hosts/$DISTRO/inventory
    fi
fi
# We need to remove any created VM in other jobs
# TODO: Add cleanup tasks

for i in $(virsh -q list | awk '{ print $2 }'); do
    virsh destroy $i;
    virsh undefine $i --remove-all-storage;
done;

#
# We need to receive here some parameters, the source and destination
# tenants should be defined depending on where we will need to run the job
#

if [[ "$SCENARIO" == "submariner" ]]; then
    # Deploy the fisrt cluster (okd)
    ansible-playbook \
        --user root \
        -v -i ./hosts/okd/inventory \
        --become \
        --become-user root \
        -e kubeinit_libvirt_dns_forward_multicluster_enabled=True \
        ./playbooks/okd.yml

    # Deploy the second cluster (rke)
    ansible-playbook \
        --user root \
        -v -i ./hosts/rke/inventory \
        --become \
        --become-user root \
        -e kubeinit_libvirt_dns_forward_multicluster_enabled=True \
        ./playbooks/rke.yml

    # Deploy submariner as broker (okd)
    ansible-playbook \
        --user root \
        -v -i ./hosts/okd/inventory \
        --become \
        --become-user root \
        -e kubeinit_submariner_is_broker=True \
        -e @scenario_variables.yml \
        ./playbooks/submariner.yml

    # Deploy submariner as secondary (rke)
    ansible-playbook \
        --user root \
        -v -i ./hosts/rke/inventory \
        --become \
        --become-user root \
        -e kubeinit_submariner_is_secondary=True \
        -e @scenario_variables.yml \
        ./playbooks/submariner.yml
fi
