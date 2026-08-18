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

cmd = "sudo journalctl -u puma_rails -n 150 --no-pager"
print("Fetching latest 150 lines of systemd journal logs...")
stdin, stdout, stderr = ssh.exec_command(cmd)

print(stdout.read().decode('utf-8'))
err = stderr.read().decode('utf-8')
if err:
    print("Errors:")
    print(err)

ssh.close()
