# bin/deploy/inspect_remote.py
import os
import paramiko

EC2_IP = "13.60.42.33"
EC2_USER = "ec2-user"
SSH_KEY_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "id_rsa"))

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
private_key = paramiko.RSAKey.from_private_key_file(SSH_KEY_PATH)
ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key)

def run_remote_cmd(cmd_str, desc):
    print(f"\n=== Running remote command: {desc} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd_str)
    
    # Read stdout in real-time
    while True:
        line = stdout.readline()
        if not line:
            break
        print(line, end="")
        
    err = stderr.read().decode('utf-8')
    if err:
        print("STDERR:")
        print(err)

# Run git diff config/initializers/spree.rb
run_remote_cmd("cd /var/www/jeeni_app && git diff config/initializers/spree.rb", "Git diff for spree.rb")
# Also cat config/initializers/spree.rb to see exactly what is on the remote server
run_remote_cmd("cat /var/www/jeeni_app/config/initializers/spree.rb", "Remote spree.rb content")

ssh.close()
