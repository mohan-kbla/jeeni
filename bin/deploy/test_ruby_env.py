# bin/deploy/test_ruby_env.py
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
        "export PATH=\"$HOME/.rbenv/bin:$PATH\" && eval \"$(rbenv init -)\" && ruby --version",
        "export PATH=\"$HOME/.rbenv/bin:$PATH\" && eval \"$(rbenv init -)\" && gem list bundler",
        "ls -la /etc/nginx/sites-enabled"
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
