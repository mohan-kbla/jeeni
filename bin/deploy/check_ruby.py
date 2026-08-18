# bin/deploy/check_ruby.py
import os
import paramiko

EC2_IP = "107.22.90.79"
EC2_USER = "ubuntu"
KEY_PATH = "/home/mohan/jeeni_app/bin/deploy/id_rsa"

try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    private_key = paramiko.RSAKey.from_private_key_file(KEY_PATH)
    ssh.connect(hostname=EC2_IP, username=EC2_USER, pkey=private_key, timeout=10)
    
    commands = [
        "ls -la /home/ubuntu/.rbenv/versions/3.2.2/bin/ruby",
        "ls -la /home/ubuntu/tmp",
        "tail -n 20 /home/ubuntu/tmp/ruby-build*.log 2>/dev/null || echo 'No log files'"
    ]
    
    for cmd in commands:
        print(f"\n=== Running: {cmd} ===")
        stdin, stdout, stderr = ssh.exec_command(cmd)
        print("STDOUT:")
        print(stdout.read().decode())
        print("STDERR:")
        print(stderr.read().decode())
        
    ssh.close()
except Exception as e:
    print(f"Failed: {e}")
