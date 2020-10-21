#!/usr/bin/env bash
set -euo pipefail
echo "Keyoxidizer - Interactive Keyoxide helper"

# GPG config file for unattended keygen
generateConfig()
{
cat > ./keyoxidizer.config<<EOF
#%dry-run
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Name-Real: $keyoxidizer_name
Name-Email: $keyoxidizer_email
Name-Comment: $keyoxidizer_comment
Expire-Date: 2y
%ask-passphrase
%commit
%echo done
EOF
}

# Generate and upload
newKey()
{
   echo "Generating new key..."
   read -p "Enter full name: " keyoxidizer_name
   read -p "Enter email: " keyoxidizer_email
   read -p "Enter comment about key: " keyoxidizer_comment
   generateConfig
   echo "You'll now be asked to enter a password to secure the key"
   sleep 1.5s
   gpg --batch --generate-key ./keyoxidizer.config
   gpg --fingerprint #clears out meta output
   printFingerPrint $keyoxidizer_email
}

printFingerPrint()
{
   echo -e "\n\n\\n==================================================\n"
   echo -e "Here's your GPG fingerprint: \n"
   gpg --with-colons --fingerprint $1 | \
      awk -F: '$1 == "fpr" {print $10;}'| \
      sed -n '1p'
   echo -e "==================================================\n\n"
}

# Export key to keys.OpenPGP.org
exportOpenPGP()
{
   gpg --export $keyoxidizer_email | \
      curl -T - https://keys.openpgp.org
   echo -e "Open the link above and click on 'Send verification email' and check your email account."
}

# Operate on existing key
existingKey()
{
   read -p "Enter email for existing key: " keyoxidizer_email
   printFingerPrint $keyoxidizer_email
}

# User request handling
echo -e "Select an option: \n1. Create a new key. \n2. Use an existing key."
read keyoxidizer_keyType

if [ "$keyoxidizer_keyType" == "1" ]; then
   newKey
   exportOpenPGP
else
   existingKey
fi
