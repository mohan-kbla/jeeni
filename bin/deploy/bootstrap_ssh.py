# bin/deploy/bootstrap_ssh.py
import re
import os
import boto3
import paramiko
from cryptography.hazmat.primitives import serialization

EC2_IP = "107.22.90.79"
EC2_USER = "ubuntu"
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

# Get the public keys we want to authorize
# 1. id_rsa.pub
id_rsa_pub_path = "/home/mohan/jeeni_app/bin/deploy/id_rsa.pub"
with open(id_rsa_pub_path, "r") as f:
    id_rsa_pub = f.read().strip()

# 2. jeeni_keys.pem public key
jeeni_pem_path = "/home/mohan/jeeni_app/jeeni_keys.pem"
with open(jeeni_pem_path, "rb") as f:
    jeeni_pem_data = f.read()
private_key = serialization.load_pem_private_key(jeeni_pem_data, password=None)
jeeni_pub = private_key.public_key().public_bytes(
    encoding=serialization.Encoding.OpenSSH,
    format=serialization.PublicFormat.OpenSSH
).decode().strip()

authorized_keys_to_add = [id_rsa_pub, jeeni_pub]
print("Public keys to authorize:")
for k in authorized_keys_to_add:
    print(f" - {k[:50]}...{k[-50:]}")

# Describe the instance to find its Availability Zone
az = "us-east-1d"  # fallback default
try:
    ec2 = boto3.client(
        'ec2',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=REGION
    )
    inst_desc = ec2.describe_instances(InstanceIds=[INSTANCE_ID])
    for res in inst_desc.get('Reservations', []):
        for inst in res.get('Instances', []):
            az = inst.get('Placement', {}).get('AvailabilityZone', az)
    print(f"Fetched Availability Zone: {az}")
except Exception as e:
    print(f"Warning: failed to describe instance to get AZ: {e}. Using default {az}")

# Push temporary key via EC2 Instance Connect
try:
    eic = boto3.client(
        'ec2-instance-connect',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name=REGION
    )
    print(f"Sending temporary SSH public key to instance {INSTANCE_ID} in AZ {az}...")
    eic.send_ssh_public_key(
        InstanceId=INSTANCE_ID,
        InstanceOSUser=EC2_USER,
        SSHPublicKey=id_rsa_pub,
        AvailabilityZone=az
    )
    print("Temporary SSH key pushed successfully.")
except Exception as e:
    print(f"EIC push failed: {e}")
    exit(1)

# Connect via SSH and write the authorized keys permanently
try:
    priv_key_path = "/home/mohan/jeeni_app/bin/deploy/id_rsa"
    print(f"Connecting to {EC2_USER}@{EC2_IP}...")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    priv_key = paramiko.RSAKey.from_private_key_file(priv_key_path)
    ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=priv_key, timeout=10)
    
    print("Connection established. Writing authorized_keys...")
    # Prepare keys injection commands
    cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
    ssh.exec_command(cmd)
    
    # Append each key if not already present
    for k in authorized_keys_to_add:
        k_escaped = k.replace("'", "'\\''")
        append_cmd = f"grep -qF '{k_escaped}' ~/.ssh/authorized_keys || echo '{k_escaped}' >> ~/.ssh/authorized_keys"
        stdin, stdout, stderr = ssh.exec_command(append_cmd)
        exit_status = stdout.channel.recv_exit_status()
        if exit_status != 0:
            print(f"Failed to append key. Error: {stderr.read().decode()}")
            
    print("Permanently wrote public keys to authorized_keys!")
    
    # Verify that the keys are written
    stdin, stdout, stderr = ssh.exec_command("cat ~/.ssh/authorized_keys")
    print("\nCurrent authorized_keys on server:")
    print(stdout.read().decode())
    
    ssh.close()
    print("SSH Bootstrapping Complete!")
except Exception as e:
    print(f"SSH setup failed: {e}")
