#!/bin/zsh

set -e -o pipefail -x

# Deploy LXD infra
terraform -chdir=bm-infra init
terraform -chdir=bm-infra apply -auto-approve

OUTPUT=$(terraform -chdir=bm-infra output -json baremetal_ip | jq -r '. | join(" ")')
HOSTS=(${(@s/ /)OUTPUT})

for HOST in $HOSTS;
do
    # ssh-keygen -R $HOST
    ssh -o StrictHostKeyChecking=accept-new ubuntu@$HOST echo $HOST added to known hosts
done

cat <<EOF > cloud.yaml
clouds:
  manual:
    type: manual
    endpoint: ubuntu@${HOSTS[1]}
    regions:
      default:
        endpoint: ubuntu@${HOSTS[1]}
EOF

juju add-cloud --client manual cloud.yaml
juju bootstrap manual

juju switch controller

for HOST in ${HOSTS[2,3]};
do
    juju add-machine ssh:ubuntu@$HOST
done

juju machines --format json | jq '{"machine_ids": (.machines | keys)}' > k8s-infra/machine.auto.tfvars.json

# Deploy K8S infra

terraform -chdir=k8s-infra init
terraform -chdir=k8s-infra apply -auto-approve

# Wait for deployment to finish 
juju-wait -vw -m controller -r 10

kube_config_result=$(juju run microk8s/0 kubeconfig --format json | jq '."microk8s/0".results.kubeconfig')
export KUBECONFIG=./kubeconfig
juju ssh microk8s/0 cat $kube_config_result > $KUBECONFIG

# Add K8S cloud to the controller
juju add-k8s k8s-cloud --controller manual-default

# Workaround for juju/terraform-provider-juju#147
juju add-model openstack --credential k8s-cloud k8s-cloud

# Deploy sunbeam
git clone --branch stable/yoga https://github.com/openstack-snaps/sunbeam-terraform
echo '{"cloud": "k8s-cloud"}' > sunbeam-terraform/cloud.auto.tfvars.json
sed -i 's/\(var.model\)/\1\n  credential = "k8s-cloud"/' sunbeam-terraform/main.tf

terraform -chdir=sunbeam-terraform init
terraform -chdir=sunbeam-terraform apply
