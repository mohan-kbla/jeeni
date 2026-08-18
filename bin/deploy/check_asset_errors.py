import os
import paramiko

EC2_IP = "52.203.49.163"
EC2_USER = "ubuntu"
SSH_KEY_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "id_rsa"))

print(f"Connecting to {EC2_USER}@{EC2_IP}...")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
private_key = paramiko.RSAKey.from_private_key_file(SSH_KEY_PATH)
ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key)

cmd = "sudo grep -i 'assets' /var/log/nginx/jeeni_app_access.log | grep -v ' 200 ' | grep -v ' 304 ' | tail -n 50"
print("Searching Nginx access logs for failed asset requests...")
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8'))

ssh.close()
