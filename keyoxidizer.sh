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

# Print key fingerprint as single string
printFingerPrint()
{
   gpg --with-colons --fingerprint $1 | \
      awk -F: '$1 == "fpr" {print $10;}'| \
      sed -n '1p' > keyoxidizer.fingerprint

   echo -e "\n\n\n==================================================\n"
   echo -e "Here's your GPG fingerprint: \n"
   cat keyoxidizer.fingerprint
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

mastodon()
{
   fingerPrint=`cat keyoxidizer.fingerprint`

   echo -e "Log into your Mastodon account and click Edit Profile."
   echo -e "Add a new item under Profile metadata with the label OpenPGP"
   echo -e "Paste in your PGP fingerprint as the content: $fingerPrint"

   read -p "Have completed this step (y/n): " keyoxidizer_response

   if [ "$keyoxidizer_response" == "y" ]; then
     echo -e "After collecting some input you'll be presented with some text to paste into the pgp prompt"
     read -p "Enter your full Mastodon instance url (ex: https://fosstodon.org/): " keyoxidizer_url
     read -p "Enter your Mastodon username with @ (ex: @keyoxide): " keyoxidizer_username
     keyoxidizer_fullUrl=$keyoxidizer_url$keyoxidizer_username

     #TODO: Use parameters to set notation, potential bug: https://lists.gnupg.org/pipermail/gnupg-users/2019-June/062067.html
     echo -e "=================================================="
     echo -e "Paste the following into the gpg prompt including the extra blank line"
     echo -e "notation\nproof@metacode.biz=$keyoxidizer_fullUrl\nsave\n"
     echo -e "==================================================\n\n\n\n"
     gpg --edit-key $fingerPrint
     gpg --keyserver hkps://keys.openpgp.org --send-keys $fingerPrint
   else
     echo -e "Exiting"
   fi

}

addProof()
{
   echo -e "Select platform to add proof"
   echo -e "1. Mastadon"
   read keyoxidizer_proof

   case $keyoxidizer_proof in
      1)
         mastodon
         ;;
      *)
         echo "Please make a valid selection"
         ;;
   esac
}

# User request handling
echo -e "Select an option: \n1. Create a new key. \n2. Use an existing key."
read keyoxidizer_keyType

if [ "$keyoxidizer_keyType" == "1" ]; then
   newKey
   exportOpenPGP
else
   existingKey
   addProof
fi
