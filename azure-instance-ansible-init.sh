#!/bin/bash

#---BEGIN VARIABLES---
VAULT_CREDENTIALS=''
GIT_USERNAME=''
GIT_PASSWORD=''
DOMAIN_INTERN =''
ANSIBLE_ENVIRONMENT=''
GIT_URL=''
PLAYBOOKYML=''

#---- -----------------------------#
function log()
{
    # If you want to enable this logging add a un-comment the line below and add your account id
    #curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $1" https://logs-01.loggly.com/inputs/<key>/tag/es-extension,${HOSTNAME}
    echo "$1"
}
#---PARSE AND VALIDATE PARAMETERS---
if [ $# -ne 7 ]; then
    log "ERROR:Wrong number of arguments specified. Parameters received $#. Terminating the script."
    
    exit 1
fi
#-----------------------------------------------------------------------------------------------------------------------------#
while getopts :c:u:p:d:e:g:p: optname; do
    log "INFO:Option $optname set with value ${OPTARG}"
  case $optname in
    c) # 
      VAULT_CREDENTIALS=${OPTARG}
      ;;
    u) # 
      GIT_USERNAME=${OPTARG}
      ;;
    p) # 
      GIT_PASSWORD=${OPTARG}
      ;;
    d) # 
      DOMAIN_INTERN=${OPTARG}
      ;;
    e) # 
      ANSIBLE_ENVIRONMENT=${OPTARG}
      ;;
    g) # define url
      GIT_URL=${OPTARG}
      ;;
    p) # define the playbook
      PLAYBOOKYML=${OPTARG}
      ;;
    \?) #Invalid option - show help
      log "ERROR:Option -${BOLD}$OPTARG${NORM} not allowed."
      
      exit 1
      ;;
  esac
done
# ----------------------------------------------------------------------------------------------------------------------------#
# clear cache
yum clean all

# install ansible, facter and git
yum -y install ansible facter git2u

# setting ansible and user creation
sed -ie 's#\#vault_password_file = /path/to/vault_password_file#vault_password_file = /root/.vault-credentials#g' /etc/ansible/ansible.cfg

cat << EOF > /etc/ansible/hosts
[local]
localhost  ansible_connection=local
EOF

cat << EOF > /root/.vault-credentials
$VAULT_CREDENTIALS
EOF

# setting git credentials
export HOME=/root
git config --global credential.helper store

cat << EOF > /root/.git-credentials
https://${GIT_USERNAME}:${GIT_PASSWORD}@stash.wob.vw.vwg:8443
EOF

# fix file permissions
chmod 0600 /root/.git-credentials /root/.vault-credentials

# store parameters for later use in ansible playbooks
mkdir -p /etc/ansible/facts.d
chmod 0755 /etc/ansible/facts.d
chown root:root /etc/ansible/facts.d

git_branch="master"

# internal domain with stripped last point char
domain_intern="${DOMAIN_INTERN}"
domain_as_url=${${DOMAIN_INTERN}::-1}

cat << EOF > /etc/ansible/facts.d/preferences.fact
[ansible]
environment=$ansible_environment
domain_intern=$domain_as_url

[git]
url=https://${GIT_URL}
branch=$git_branch
playbookyml=${PLAYBOOKYML}
EOF

# clone git repository and execute ansible playbook
mkdir -p /opt/ansible-environments
chmod 0755 /opt/ansible-environments
chown root:root /opt/ansible-environments
git clone https://${GIT_URL} /opt/ansible-environments
cd /opt/ansible-environments/${ANSIBLE_ENVIRONMENT}
ansible-galaxy install -f -p roles/ -r requirements.yml
ansible-playbook ${PLAYBOOKYML}
