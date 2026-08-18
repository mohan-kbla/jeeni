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

cmd = "sudo tail -n 100 /var/log/nginx/jeeni_app_error.log"
print("Fetching Nginx error log...")
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8'))

cmd2 = "sudo tail -n 50 /var/log/nginx/error.log"
print("Fetching Nginx system error log...")
stdin2, stdout2, stderr2 = ssh.exec_command(cmd2)
print(stdout2.read().decode('utf-8'))

ssh.close()
