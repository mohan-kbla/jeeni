# bin/deploy/list_all_instances.py
import re
import os
import boto3

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

regions = ['us-east-1', 'eu-north-1', 'us-east-2', 'us-west-2']
for r in regions:
    print(f"\n=== Listing instances in region: {r} ===")
    try:
        ec2 = boto3.client(
            'ec2',
            aws_access_key_id=aws_access_key,
            aws_secret_access_key=aws_secret_key,
            region_name=r
        )
        response = ec2.describe_instances()
        for reservation in response.get('Reservations', []):
            for instance in reservation.get('Instances', []):
                print(f"ID: {instance.get('InstanceId')} | Public IP: {instance.get('PublicIpAddress')} | State: {instance.get('State', {}).get('Name')} | Key: {instance.get('KeyName')}")
    except Exception as e:
        print(f"Error in {r}: {e}")
