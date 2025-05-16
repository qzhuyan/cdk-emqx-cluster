#!/usr/bin/env bash
#
absdir=$(dirname $0)

help() {
    basename=$(basename $0)
    echo "$basename: download loki datadir from stack"
    echo "$basename \$stackname \$dstdir"
}

if [ $# -lt 2 ]; then
    help
    exit 1
fi
stackname=$1
dstdir=$2

remote_host=$($absdir/get_stackinfo.sh $stackname bastion)

ssh ec2-user@$remote_host "curl -XPOST lb.int.$stackname:3100/flush"
ssh ec2-user@$remote_host "curl -XPOST lb.int.$stackname:3100/ingester/prepare_shutdown"

sleep 1;
ssh ec2-user@$remote_host "curl -XPOST lb.int.$stackname:3100/ingester/shutdown"

ssh ec2-user@$remote_host "sudo tar czvf loki-data.tar.gz -C /mnt/efs-data/loki_data/ ."
scp ec2-user@$remote_host:loki-data.tar.gz $dstdir/
