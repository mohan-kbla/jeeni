# bin/deploy/compare_fingerprints.py
import re
import os
import boto3
import hashlib
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

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

# Describe key pair from AWS
try:
    ec2 = boto3.client(
        'ec2',
        aws_access_key_id=aws_access_key,
        aws_secret_access_key=aws_secret_key,
        region_name='us-east-1'
    )
    response = ec2.describe_key_pairs(KeyNames=['jeeni_keys'])
    aws_fingerprint = response['KeyPairs'][0]['KeyFingerprint']
    print(f"AWS Key Fingerprint (SHA-1): {aws_fingerprint}")
except Exception as e:
    print(f"AWS Error: {e}")
    exit(1)

# Compute local key fingerprint
# AWS computes SHA-1 fingerprint of the DER-encoded private key (if imported/created in AWS)
# Or MD5/SHA-256 fingerprint depending on the key format.
# Let's read the local private key
local_key_path = "/home/mohan/jeeni_app/jeeni_keys.pem"
if not os.path.exists(local_key_path):
    print("Local key does not exist!")
    exit(1)

try:
    with open(local_key_path, "rb") as f:
        key_data = f.read()
        
    # Let's load the key using cryptography
    private_key = serialization.load_pem_private_key(key_data, password=None)
    
    # DER representation of the private key
    der_data = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    # SHA-1 fingerprint (format: aa:bb:cc...)
    sha1_hash = hashlib.sha1(der_data).hexdigest()
    sha1_formatted = ":".join(sha1_hash[i:i+2] for i in range(0, len(sha1_hash), 2))
    print(f"Local Key Fingerprint (Traditional OpenSSL DER SHA-1): {sha1_formatted}")
    
    # Also check PKCS#8 format if Traditional OpenSSL doesn't match
    der_pkcs8 = private_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    sha1_pkcs8 = hashlib.sha1(der_pkcs8).hexdigest()
    sha1_pkcs8_formatted = ":".join(sha1_pkcs8[i:i+2] for i in range(0, len(sha1_pkcs8), 2))
    print(f"Local Key Fingerprint (PKCS#8 DER SHA-1):               {sha1_pkcs8_formatted}")
    
    # Also check MD5 on the public key (which is what OpenSSH uses for fingerprint)
    # AWS sometimes uses MD5 on the DER-encoded public key
    public_key = private_key.public_key()
    pub_der = public_key.public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo
    )
    md5_hash = hashlib.md5(pub_der).hexdigest()
    md5_formatted = ":".join(md5_hash[i:i+2] for i in range(0, len(md5_hash), 2))
    print(f"Local Public Key Fingerprint (SPKI MD5):                {md5_formatted}")
    
    # Also OpenSSH style MD5 on public key
    # public key in OpenSSH format: "ssh-rsa AAAAB3NzaC1yc2E..."
    openssh_pub = public_key.public_bytes(
        encoding=serialization.Encoding.OpenSSH,
        format=serialization.PublicFormat.OpenSSH
    )
    # The actual key part in openssh format is the second field
    pub_bytes = re.split(r'\s+', openssh_pub.decode())[1].encode()
    # Decode base64
    import base64
    pub_raw = base64.b64decode(pub_bytes)
    md5_openssh = hashlib.md5(pub_raw).hexdigest()
    md5_openssh_formatted = ":".join(md5_openssh[i:i+2] for i in range(0, len(md5_openssh), 2))
    print(f"Local Public Key Fingerprint (OpenSSH MD5):             {md5_openssh_formatted}")
    
except Exception as e:
    print(f"Local compute Error: {e}")
