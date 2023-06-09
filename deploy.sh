#!/bin/zsh

set -x
# Deploy LXD infra
terraform -chdir=bm-infra init
terraform -chdir=bm-infra apply -auto-approve

lxc exec bm0 -- cloud-init status --wait

LAST=$(terraform -chdir=bm-infra output -json baremetal_ip | jq -r '. | length - 1')

for N in {0..$LAST};
do
  ip=$(dig +short bm$N @10.206.54.1)
  ssh-keygen -R bm$N
  ssh-keygen -R bm$N.lxd
  ssh-keygen -R $ip
  ssh-keyscan -H bm$N >> ~/.ssh/known_hosts
  ssh-keyscan -H bm$N.lxd >> ~/.ssh/known_hosts
  ssh-keyscan -H $ip >> ~/.ssh/known_hosts
done

OUTPUT=$(terraform -chdir=bm-infra output -json baremetal_ip | jq -r '. | join(" ")')
HOSTS=(${(@s/ /)OUTPUT})

