#!/bin/bash
###############################################################################
# We put chaos tests script here and hopefully we could reuse these scripts in k8s env
# To run chaos test the stack called CDKchaosTest should be deployed.
###############################################################################

set -e

BASEDIR=$(dirname "$0")
source $BASEDIR/fis_lib.sh
export AWS_PAGER=""

die() {
    echo "$@" >&2
    exit 1
}

wait_ssm_cmd_finish() {
    local jobid=$1
    job_status=""
    while [[ $job_status != "Success" && $job_status != "Failed" ]];
    do
        sleep 20;
        job_status=$(aws ssm list-command-invocations --command-id="$jobid" | jq -r .CommandInvocations[].Status
                   );
    done;
    echo "$job_status"
}


gen_tc() {
    cluster=$1
    fault=$2
    # step 0: stop traffic
    echo "Stop Traffic"
    cmdid=$($BASEDIR/send_cmd.sh "$cluster" "stop_traffic" |  jq -r .Command.CommandId )
    wait_ssm_cmd_finish "$cmdid"

    # step 1: start traffic
    echo "Start Traffic"
    $BASEDIR/send_cmd.sh "$cluster" "start_traffic" || die "stopped: start traffic failed"
    # step 2: sleep for 5mins for steady state
    sleep 300;
    # step 3: inject faults
    echo "Inject fault: $fault:"
    jobid=$($BASEDIR/inject_fault.sh "$cluster" "$fault" | jq -r '.experiment.id');
    wait_fis_job_finish "$jobid"

    # step 4: wait for traffic to back to normal
    sleep 300;
    # step 5: collect logs
    echo "Collecting logs"
    $BASEDIR/send_cmd.sh "$cluster" "collect_logs" "$fault"|| die "stopped: collect_logs failed"

    echo "test finished"
}

# cluster name 'CDK_EMQX_CLUSTERNAME' when you deploy cdk
cluster="$1"
tc_name="$2"

case "$tc_name" in
     all)
         for fault in ${ALL_FIS_FAULTS[*]};
         do
             gen_tc "$cluster" "$fault";
         done
         ;;
     list)
         echo "Available faults: ${ALL_FIS_FAULTS[*]}"
         ;;
     *)
         gen_tc "$cluster" "$tc_name"
         ;;
esac
