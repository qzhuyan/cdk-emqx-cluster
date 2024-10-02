#!/usr/bin/env bash
absdir=$(dirname $0)


help() {
    basename=$(basename $0)
    echo "$basename: clone the dashboard from CDK stack and replay locally "
    echo "$basename \$stackname \$dstdir"
    exit
}

stackname=$1
replaydir=$2

if [ $# -lt 2 ]; then
    help
fi

$absdir/download_prom_data.sh $stackname $replaydir && \
    $absdir/replay-dashboard.sh "${replaydir}/efs-data.tar.gz" ${replaydir} up && \
    echo "\n ==== \ndeployed at ${replaydir}"
