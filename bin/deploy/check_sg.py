# bin/deploy/check_sg.py
import re
import os
import boto3

INSTANCE_ID = "i-03b279cac1b59e0de"
REGION = "us-east-1"

# Read AWS credentials from local .env
env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.env"))
aws_access_key = ""
aws_secret_key = ""

if os.path.exists(env_path):
    with open(env_path, "r") as f:
        content = f.read()
        key_match = re.search(r'AWS_ACCESS_KEY_ID=["\']?([^"\'\n]+)', content)
        secret_match = re.search(r'AWS_SECRET_ACCESS_KEY=["\']?([^"\'\n]+)', content)
        if key_match:
            aws_access_key = key_match.group(1)
        if secret_match:
            aws_secret_key = secret_match.group(1)

try:
    ec2 = boto3.client(
        'ec2',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=REGION
    )
    inst_desc = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    sgs = []
    for res in inst_desc.get('Reservations', []):
        for inst in res.get('Instances', []):
            sgs = inst.get('SecurityGroups', [])
            
    print(f"Security Groups associated with {INSTANCE_ID}:")
    for sg in sgs:
        sg_id = sg.get('GroupId')
        sg_name = sg.get('GroupName')
        print(f" - ID: {sg_id} | Name: {sg_name}")
        
        # Describe rules
        rules = ec2.describe_security_group_rules(Filters=[{'Name': 'group-id', 'Values': [sg_id]}])
        for rule in rules.get('SecurityGroupRules', []):
            is_egress = rule.get('IsEgress')
            protocol = rule.get('IpProtocol')
            from_port = rule.get('FromPort')
            to_port = rule.get('ToPort')
            cidr = rule.get('CidrIpv4')
            desc = rule.get('Description')
            direction = "EGRESS" if is_egress else "INGRESS"
            print(f"   [{direction}] Protocol: {protocol} | Ports: {from_port}-{to_port} | Source/Dest: {cidr} | Desc: {desc}")
            
except Exception as e:
    print(f"Failed: {e}")
