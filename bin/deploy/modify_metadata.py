# bin/deploy/modify_metadata.py
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
    print("Modifying instance metadata options...")
    response = ec2.modify_instance_metadata_options(
        InstanceId='i-029ee62854378170c',
        HttpTokens='optional',
        HttpEndpoint='enabled'
    )
    print("Successfully set HttpTokens to optional!")
    print(response.get('InstanceMetadataOptions'))
    
    # Also reboot the instance so cloud-init runs again
    print("Rebooting instance to trigger cloud-init...")
    ec2.reboot_instances(InstanceIds=['i-029ee62854378170c'])
    print("Reboot command sent!")
except Exception as e:
    print(f"Error: {e}")
