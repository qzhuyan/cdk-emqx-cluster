#!/usr/bin/env bash
#
absdir=$(dirname $0)

help() {
    basename=$(basename $0)
    echo "$basename: download prom datadir from stack"
    echo "$basename \$stackname \$dstdir"
}

if [ $# -lt 2 ]; then
    help
    exit 1
fi
stackname=$1
dstdir=$2

remote_host=$($absdir/get_stackinfo.sh $stackname bastion)
snapshot_dir=$(ssh ec2-user@$remote_host "curl -XPOST lb.int.$stackname:9090/api/v1/admin/tsdb/snapshot" | jq .data.name)

ssh ec2-user@$remote_host "sudo tar czvf efs-data.tar.gz -C /mnt/efs-data/tsdb_data/snapshots/$snapshot_dir ."
scp ec2-user@$remote_host:efs-data.tar.gz $dstdir/
