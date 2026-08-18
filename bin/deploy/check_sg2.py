# bin/deploy/check_sg2.py
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
        
        # Describe rules using describe_security_groups
        sg_details = ec2.describe_security_groups(GroupIds=[sg_id])
        for g in sg_details.get('SecurityGroups', []):
            print("\nIngress Rules:")
            for rule in g.get('IpPermissions', []):
                protocol = rule.get('IpProtocol')
                from_port = rule.get('FromPort')
                to_port = rule.get('ToPort')
                ip_ranges = [r.get('CidrIp') for r in rule.get('IpRanges', [])]
                print(f"   Protocol: {protocol} | Ports: {from_port}-{to_port} | IP Ranges: {ip_ranges}")
            
except Exception as e:
    print(f"Failed: {e}")
