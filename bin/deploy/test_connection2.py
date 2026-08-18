# bin/deploy/test_connection2.py
import os
import paramiko

EC2_IP = "52.203.49.163"
EC2_USER = "ubuntu"
KEYS = [
    "/home/mohan/jeeni_app/bin/deploy/id_rsa",
    "/home/mohan/jeeni_app/jeeni_keys.pem"
]

for key_path in KEYS:
    print(f"Connecting using {key_path}...")
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        private_key = paramiko.RSAKey.from_private_key_file(key_path)
        ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key, timeout=10)
        print(f"SUCCESS with {key_path}!")
        ssh.close()
    except Exception as e:
        print(f"FAILED: {e}")
