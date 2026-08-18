# bin/deploy/test_old_connection.py
import os
import paramiko

EC2_IP = "13.60.42.33"
EC2_USER = "ec2-user"
KEY_PATH = "/home/mohan/jeeni_app/bin/deploy/id_rsa"

print(f"Connecting to {EC2_USER}@{EC2_IP} using {KEY_PATH}...")
try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    private_key = paramiko.RSAKey.from_private_key_file(KEY_PATH)
    ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key, timeout=10)
    print("SUCCESS!")
    ssh.close()
except Exception as e:
    print(f"FAILED: {e}")
