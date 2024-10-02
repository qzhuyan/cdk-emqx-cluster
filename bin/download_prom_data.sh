#!/usr/bin/env bash
#
absdir=$(dirname $0)

help() {
    basename=$(basename $0)
    echo "$basename: download prom datadir from stack"
    echo "$basename \$stackname \$dstdir"
}

if [ $# -lt 3 ]; then
    help
fi
stackname=$1
dstdir=$2

remote_host=$($absdir/get_stackinfo.sh $stackname bastion)

ssh ec2-user@$remote_host 'sudo tar czvf efs-data.tar.gz /mnt/efs-data/'
scp ec2-user@$remote_host:efs-data.tar.gz $dstdir/
