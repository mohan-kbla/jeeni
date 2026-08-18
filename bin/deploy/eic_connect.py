# bin/deploy/eic_connect.py
import re
import os
import boto3
import paramiko

EC2_IP = "107.22.90.79"
EC2_USER = "ubuntu"
INSTANCE_ID = "i-029ee62854378170c"
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

# Read the local public key
pub_key_path = "/home/mohan/jeeni_app/bin/deploy/id_rsa.pub"
with open(pub_key_path, "r") as f:
    pub_key_content = f.read().strip()

# Initialize EC2 Instance Connect client
try:
    eic = boto3.client(
        'ec2-instance-connect',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=REGION
    )
    print(f"Sending SSH public key to instance {INSTANCE_ID} (User: {EC2_USER})...")
    response = eic.send_ssh_public_key(
        InstanceId=INSTANCE_ID,
        InstanceOSUser=EC2_USER,
        SSHPublicKey=pub_key_content,
        AvailabilityZone="us-east-1d" # Derived from Placement
    )
    print("Success response from EC2 Instance Connect:")
    print(response)
    
    # Try connecting immediately using the private key
    priv_key_path = "/home/mohan/jeeni_app/bin/deploy/id_rsa"
    print(f"Attempting SSH connection to {EC2_USER}@{EC2_IP} using {priv_key_path}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    private_key = paramiko.RSAKey.from_private_key_file(priv_key_path)
    ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key, timeout=10)
    print("SSH CONNECTION SUCCESSFUL VIA EC2 INSTANCE CONNECT!")
    ssh.close()
except Exception as e:
    print(f"Error: {e}")
