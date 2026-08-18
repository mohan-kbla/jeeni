# bin/deploy/get_console_output.py
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

try:
    ec2 = boto3.client(
        'ec2',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name='us-east-1'
    )
    
    response = ec2.get_console_output(InstanceId='i-03b279cac1b59e0de')
    output = response.get('Output', '')
    if output:
        print("=== Console Output ===")
        print(output)
    else:
        print("No console output available yet.")
except Exception as e:
    print(f"Error: {e}")
