#!/usr/bin/env sh
# Get deployed stack info via query aws cloudformation
# deps: aws cli
#


help() {
    echo "# Get deployed stack info from cloudformation with aws cli"
    echo "get_stackinfo \$stackname \$info [\$format]"
    echo "get_stackinfo william ssh"
    echo "get_stackinfo william bastion"
    echo "get_stackinfo william info"
}

if [ $# -lt 2 ]; then
    help
    exit
fi

stackname=$1
field=$2
format=${3:-text}

case $2 in
     ssh)
         q="SSHCommandsforAccess";;
     bastion)
         q="SSHEntrypoint";;
     *)
         q=""
esac

if [ -n "$q" ]; then
    query="Stacks[0].Outputs[?OutputKey==\`$q\`].OutputValue"
else
    query="Stacks[0].Outputs"
    format="json"
fi

aws cloudformation describe-stacks  --stack-name $stackname  --query ${query} --output $format
