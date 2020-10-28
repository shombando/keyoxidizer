#!/usr/bin/env bash
set -euo pipefail
echo "Keyoxidizer - Interactive Keyoxide helper. Go to keyoxide.org to learn more."
echo "This utility requires gpg installed on your system"

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

   echo -e "=================================================="
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
   if ! [[ -v  keyoxidizer_email ]]; then
    read -p "Enter email for existing key: " keyoxidizer_email
   else
      echo -e "Using $keyoxidizer_email "
   fi
   printFingerPrint $keyoxidizer_email
}

addNotation()
{
   fingerPrint=`cat keyoxidizer.fingerprint`
   {
      echo notation
      echo proof@metacode.biz=$1
      echo save
   } | gpg --command-fd=0 --status-fd=1 --edit-key $fingerPrint
   gpg --keyserver hkps://keys.openpgp.org --send-keys $fingerPrint
}

mastodon()
{
   fingerPrint=`cat keyoxidizer.fingerprint`

   echo -e "Log into your Mastodon account and click Edit Profile."
   echo -e "Add a new item under Profile metadata with the label OpenPGP"
   echo -e "Paste in your PGP fingerprint as the content: $fingerPrint"

   read -p "Have completed this step (y/N): " keyoxidizer_response
   if [ "$keyoxidizer_response" == "y" ]; then
     read -p "Enter your full Mastodon instance url (ex: https://fosstodon.org/): " keyoxidizer_url
     read -p "Enter your Mastodon username with @ (ex: @keyoxide): " keyoxidizer_username
     keyoxidizer_fullUrl=$keyoxidizer_url$keyoxidizer_username
     addNotation $keyoxidizer_fullUrl
   else
     echo -e "Exiting"
   fi
}

dns()
{
   fingerPrint=`cat keyoxidizer.fingerprint`
   read -p "Enter the domain or subdomain do you want to proove (ex: keyoxide.org -- don't include https://): " keyoxidizer_domain

   echo -e "Add a text record to your DNS records of your domain/sub-domain.\nThe exact instructions will depend on your domain registrar (ex: namecheap) or hosting interface (ex: cpanel): "
   echo -e "Paste this into your DNS text record: \nopenpgp4fpr:$fingerPrint"

   read -p "Have completed this step (y/N): " keyoxidizer_response
   if [ "$keyoxidizer_response" == "y" ]; then
     addNotation "dns:$keyoxidizer_domain?type=TXT"
   else
      echo -e "Exiting"
   fi
}

gitea()
{
   fingerPrint=`cat keyoxidizer.fingerprint`

   echo -e "Log into your Gitea instance (like codeberg.org account) and create a new repository named 'gitea_proof'."
   echo -e "Set the project description to: "
   echo -e "[Verifying my OpenPGP key: openpgp4fpr:$fingerPrint]"

   read -p "Have completed this step (y/N): " keyoxidizer_response
   if [ "$keyoxidizer_response" == "y" ]; then
     read -p "Enter the full url of the repo you created (ex: https://codeberg.org/keyoxide/gitea_proof): " keyoxidizer_url
     addNotation $keyoxidizer_url
   else
     echo -e "Exiting"
   fi
}

github()
{
   fingerPrint=`cat keyoxidizer.fingerprint`

   read -p "Enter your Github username: " keyoxidizer_username
   echo -e "Log into your Github account and create a new gist called 'openpgp.md'. \nPaste the following into the gist and be sure to select 'Create public gist':"
   echo -e "This is an OpenPGP proof that connects [my OpenPGP key](https://keyoxide.org/$fingerPrint) to [this Github account](https://github.com/$keyoxidizer_username). For details check out https://keyoxide.org/guides/openpgp-proofs\n\n[Verifying my OpenPGP key: openpgp4fpr:$fingerPrint]"

   read -p "Have completed this step (y/N): " keyoxidizer_response
   if [ "$keyoxidizer_response" == "y" ]; then
     read -p "Enter the full url of the repo you created (ex: https://codeberg.org/keyoxide/gitea_proof): " keyoxidizer_url
     addNotation $keyoxidizer_url
   else
     echo -e "Exiting"
   fi
}

addProof()
{
   existingKey
   echo -e "Select platform to add proof"
   echo -e "1. DNS/Domain"
   echo -e "2. Gitea"
   echo -e "3. Github"
   echo -e "4. Mastadon"
   echo -e "Enter 'q' to quit to main menu"
   read keyoxidizer_proof

   case $keyoxidizer_proof in
      1)
         dns
         ;;
      2)
         gitea
         ;;
      3)
         github
         ;;
      4)
         mastodon
         ;;
      q)
         break
         ;;
      *)
         echo "Please make a valid selection"
         ;;
   esac
}

# Generate a script to read back the notation
# FIXME: I'm unable to capture the full output from the first line
# so I'm having to capture the whole thing to file and grep it.
#
# echo showpref | gpg  --command-fd=0 --status-fd=1 --edit-key $fingerPrint | \
#   grep "proof@metacode.biz=" | \
#   awk '{if($1 == "Notations:") print $2; else print $1;}'
generateNotationScript()
{
   echo "#!/usr/bin/env bash" > keyoxidizer_getNotationList.sh
   echo "set -euo pipefail" >> keyoxidizer_getNotationList.sh
   echo "fingerPrint=\`cat keyoxidizer.fingerprint\`" >> keyoxidizer_getNotationList.sh
   echo "output=\$(echo showpref | gpg  --command-fd=0 --status-fd=1 --edit-key \$fingerPrint)" >> keyoxidizer_getNotationList.sh
   chmod +x ./keyoxidizer_getNotationList.sh
}

listProofs()
{
   existingKey
   generateNotationScript # generate script each time so code isn't stale
   ./keyoxidizer_getNotationList.sh
   script -c ./keyoxidizer_getNotationList.sh keyoxidizer.showpref

   echo -e "\n\n\n=================================================="
   echo -e "This key contains the following proofs:"
   grep proof@metacode.biz ./keyoxidizer.showpref | \
      awk '{if($1 == "Notations:") print NR ". " $2; else print NR ". " $1;}'
   echo -e "==================================================\n"
}

deleteProofs()
{
   listProofs
}

# User request handling
keyoxidizer_keyType="1"

while [ $keyoxidizer_keyType != "q" ]; do
      echo -e "Select an option: \n\
         1. Create a new key. \n\
         2. Add proofs to existing key. \n\
         3. List proofs from existing key. \n\
         4. Delete proofs from existing key. \n\
         Enter 'q' to quit"
      read keyoxidizer_keyType

      case $keyoxidizer_keyType in
      1)
         newKey
         exportOpenPGP
         addProof
         ;;
      2)
         addProof
         ;;
      3)
         listProofs
         ;;
      4)
         deleteProofs
         ;;
      q)
         break
         ;;
      *)
         echo "Please make a valid selection"
         ;;
   esac
done 
