#!/usr/bin/env python
import sys
import json
import boto3
import os
import time
import requests
import time
import json
import random

"""
This python script is designed for AWS lambda.
But it could be called from local as well by defining following env_vars
prom_host=127.0.0.1:19090
fault_name="emqx-high-io-100"

"""

ssm = boto3.client('ssm')
fis = boto3.client('fis')

def error_exit(info:str):
    print(info)
    sys.exit(1)

def run_cmd_on(cluster_name, command_name, services, cmd_parms={}):
    doc_name='-'.join([cluster_name, command_name])
    print(f"run {command_name} ...")
    res = ssm.send_command(DocumentName=doc_name, TimeoutSeconds=30,
                           Targets=[{"Key":"tag:cluster","Values":[cluster_name]},
                                    {"Key":"tag:service","Values":services}],
                           Parameters=cmd_parms
                           )
    """ example of return
    {'Command': {'CommandId': 'bf834b53-0507-4e94-812d-725366985d69',
                 'DocumentName': 'stop_traffic-william-k2',
                 'DocumentVersion': '$DEFAULT',
                 'Comment': '',
                 'ExpiresAfter': datetime.datetime(2022, 2, 16, 15, 19, 22, 524000, tzinfo=tzlocal()),
                 'Parameters': {},
                 'InstanceIds': [],
                 'Targets': [{'Key': 'tag:cluster', 'Values': ['william-k2']}, {'Key': 'tag:service', 'Values': ['loadgen']}],
                 'RequestedDateTime': datetime.datetime(2022, 2, 16, 14, 18, 52, 524000, tzinfo=tzlocal()),
                 'Status': 'Pending', 'StatusDetails': 'Pending',
                 'OutputS3Region': 'eu-west-1', 'OutputS3BucketName': '',
                 'OutputS3KeyPrefix': '', 'MaxConcurrency': '50', 'MaxErrors': '0',
                 'TargetCount': 0, 'CompletedCount': 0, 'ErrorCount': 0, 'DeliveryTimedOutCount': 0,
                 'ServiceRole': '', 'NotificationConfig': {'NotificationArn': '', 'NotificationEvents': [], 'NotificationType': ''},
                 ....
    """
    return res

def start_traffic(cluster_name, loadgen_args):
    return run_cmd_on(cluster_name, 'start_traffic', ['loadgen'], loadgen_args)

def stop_traffic(cluster_name):
    return run_cmd_on(cluster_name, 'stop_traffic', ['loadgen'])

def wait_for_finish(run):
    if not run:
        error_exit("Error: unknown run to wait for ...")
    elif 'Command' in run:
        cmd=run['Command']
        cmd_id=cmd['CommandId']
        time.sleep(5)
        res=ssm.list_command_invocations(CommandId=cmd_id, Details=True)
        if res['CommandInvocations'] == []:
            # ensures we have >1 target invocations.
            error_exit("Error: command invoke failed, no invocations: %s" % cmd)
        for invk in res['CommandInvocations']:
            status = invk['Status']
            if status == 'Success':
                pass
            elif status in ['Pending', 'InProgress', 'Delayed']:
                time.sleep(3)
                wait_for_finish(run)
            else:
                error_exit("command invoke failed: %s" % invk )
    elif 'experiment' in run:
        exp=run['experiment']
        exp_id=exp['id']
        res=fis.get_experiment(id=exp_id)
        status=res['experiment']['state']['status']
        if status in ['completed', 'failed']:
            return status
        else:
            time.sleep(5)
            wait_for_finish(run)

def find_exp_id(cluster_name, fault_name, next_token=None):
    if next_token:
        res=fis.list_experiment_templates(maxResults=100, nextToken=next_token)
    else:
        res=fis.list_experiment_templates(maxResults=100)
    for t in res['experimentTemplates']:
        if t['tags']['cluster'] == cluster_name and t['tags']['fault_name'] == fault_name:
            return t['id']
    if 'nextToken' in res:
        find_exp_id(cluster_name, fault_name, next_token=res['nextToken'])
    else:
        return None

def inject_fault(cluster_name, fault_name):
    fid = find_exp_id(cluster_name, fault_name)
    if not fid:
        error_exit(f"Error: inject_fault, fault id not found for {fault_name}")
    res=fis.start_experiment(experimentTemplateId=fid)
    return res

def prom_query(url, query, time):
    # https://prometheus.io/docs/prometheus/latest/querying/api/
    resp=requests.request(method='POST',url=url, params={'query': query, 'time':time})
    if resp.status_code==200 and resp.json()['status'] == 'success':
        return resp.json()['data']['result']

def check_traffic(url, time_at, period='5m'):
    for metric_name in ['emqx_client_subscribe',
                        'emqx_messages_publish',
                        'emqx_client_connected',
                        'emqx_connections_count']:
        # 1) check: all traffic counters are non-zero for last x mins
        print(f"checking {metric_name}")
        query_str="sum(increase(%s[%s]))" % (metric_name, period)
        # example: [{'metric': {}, 'value': [1644946184, '1578.9473684210525']}]
        res=prom_query(url, query_str, time_at)
        print(res)
        if float(res[0]['value'][1]) == 0:
            error_exit("Error: traffic error: {{metric_name}} is 0")

        # 2) check: all emqx nodes get traffic distribution
        query_str="increase(%s[%s])" % (metric_name, period)
        res=prom_query(url, query_str, time_at)
        for r in res:
            ins=(r['metric']['instance'])
            v=r['value'][1]
            if float(v) == 0:
                error_exit(f"Error: {ins}'s {metric_name} is 0")
    print("Metrics check finished and succeeded")


def run_test(cluster_name, fault_name):
    wait_for_finish(stop_traffic(cluster_name)['Command'])
    lb='.'.join(["lb", "int", cluster_name])
    if 'prom_host' in os.environ:
        prom_host=os.environ['prom_host']
    else:
        prom_host=lb+":9090"
    prom_url="http://%s/api/v1/query" % prom_host
    traffic_sub_bg={"Host": [lb], "Command":["sub"],"Prefix":["cdkS1"],"Topic":["root/%c/1/+/abc/#"],"Clients":["200000"],"Interval":["200"]}
    traffic_pub={"Host": [lb], "Command":["pub"],"Prefix":["cdkP1"],"Topic":["t1"],"Clients":["200000"],"Interval":["200"], "PubInterval":["1000"]}
    traffic_sub={"Host": [lb], "Command":["sub"],"Prefix":["cdkS2"],"Topic":["t1"],"Clients":["200"],"Interval":["200"]}
    wait_for_finish(start_traffic(cluster_name, traffic_sub_bg))
    wait_for_finish(start_traffic(cluster_name, traffic_sub))
    wait_for_finish(start_traffic(cluster_name, traffic_pub))

    time.sleep(300)
    ts_stable = int(time.time())
    check_traffic(prom_url, ts_stable)
    wait_for_finish(inject_fault(cluster_name, fault_name))
    time.sleep(300)
    ts_recover = int(time.time())
    check_traffic(prom_url, ts_recover)
    return True;

def random_fault():
    return random.choice(['emqx-node-shutdown',
                          'emqx-high-cpu-100',
                          'emqx-high-cpu-80',
                          'emqx-high-io-80',
                          'emqx-high-io-100',
                          'emqx-kill-proc',
                          'emqx-high-mem-80',
                          'emqx-high-mem-95',
                          'emqx-distport-blackhole',
                          'emqx-latency-200ms',
                          'emqx-packet-loss-10',
                          'kafka-plaintext-latency-200',
                          'kafka-plaintext-pktloss-10',
                          'kafka-plaintext-pktloss-100'])

def handler(event, context):
    cluster_name=os.environ['cluster_name']
    if 'fault_name' in os.environ:
        fault_name=os.environ['fault_name']
    else:
        fault_name=random_fault()
    print('request: {}'.format(json.dumps(event)))
    run_test(cluster_name, fault_name)
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'text/plain'
        },
        'body': event
    }

