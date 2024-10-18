#!/usr/bin/env bash
absdir=$(dirname $0)

die() {
    echo $1
    exit 1
}

help() {
    basename=$(basename $0)
    echo "Replay dashboard from the efs tar downloaded from CDK stack"
    echo "$basename \$efs_file \$env_dir up"
    echo "$basename \$efs_file \$env_dir down"
}


if [ $# -lt 3 ];then
   help
   exit 2
fi


efs_tar=$1
env_dir=$2
op=${3:-"up"}

if [ ! -f  $efs_tar ]; then
    help
    die "efs tar file ${efs_tar} not found"

else
    efs_tar=$(realpath $efs_tar)
    echo "using $efs_tar"
fi

if [ ! -d  $env_dir ]; then
    help
    die "env_dir ${env_dir} not found"
fi

echo "bring $op replay.."

case $op in
    up)
        helpdir=$absdir/_files/dashboard-replay
        cp -rf ${helpdir}/* "$env_dir"
        pushd "$env_dir"
        tar zxvf "$efs_tar" -C ./
        chmod -R 777 mnt
        rm -f mnt/efs-data/tsdb_data/lock
        docker-compose up -d
        popd
        until $absdir/grafana_setup.sh localhost:3000;
        do
            echo "retry grafana dashboards"
            sleep 1
        done
    ;;
    down)
        pushd "$env_dir"
        docker-compose down
        popd
    ;;
esac

