#!/bin/bash
# -----------------------------------------------------------
# Original Author: Travis F. Smith (https://github.com/TravisFSmith/SweetSecurity/)
# Author: int0x80
# License: WTFPL unless Apache License 2.0 must be applied ¯\_(ツ)_/¯
#
# This is a refactor of Travis F. Smith's "SweetSecurity" 
# repository for building a defensible Raspberry Pi. User 
# should have sudo privileges to install software and situate
# configuration files on the filesystem.
#
# Read the commit entry for more details.
# -----------------------------------------------------------


# -----------------------------------------------------------
# Global variables, configure as needed
# -----------------------------------------------------------
BRO_LATEST="2.5"
ES_LATEST="5.2.0"
KB_LATEST="5.2.0"
LS_LATEST="5.2.0"
INSTALL_DIR="/tmp"
SWEET_SEC="${HOME}/tools/SweetSecurity"


# -----------------------------------------------------------
# Prompt user for Critical Stack and email configuration
# -----------------------------------------------------------
read -s -p "Please enter your Critical Stack API Key: " cs_api
echo

read -p "Enter SMTP Host (smtp.google.com): " smtpHost
smtpHost=${smtpHost:-smtp.google.com}

read -p "Enter SMTP Port (587): " smtpPort
smtpPort=${smtpPort:-587}

read -p "Enter Email Address (email@gmail.com): " emailAddr
emailAddr=${emailAddr:-email@google.com}

read -s -p "Enter Email Password (Aqenbpuu): " emailPwd
emailPwd=${emailPwd:-Aqenbpuu}
echo




# -----------------------------------------------------------
# Update apt and install the needed dependencies
# -----------------------------------------------------------
function dependencies() {
  sudo apt update
  sudo apt install -y ant bison cmake default-jdk flex g++ gcc git-core gnupg libpcap-dev libssl-dev make mailutils nmap python-dev ssmtp swig zip zlib1g-dev || { echo '[-] FATAL: Could not install dependencies.'; exit 1; }
  echo '[+] System updated and dependencies installed.'
}


# -----------------------------------------------------------
# Configure mail transmissions
# -----------------------------------------------------------
function mailcall() {
  ssmtp_conf="/etc/ssmtp/ssmtp.conf"
  echo "AuthUser=${emailAddr}" | sudo tee $ssmtp_conf
  echo "AuthPass=${emailPwd}" | sudo tee -a $ssmtp_conf
  echo "FromLineOverride=YES" | sudo tee -a $ssmtp_conf
  echo "mailhub=${smtpHost}:${smtpPort}" | sudo tee -a $ssmtp_conf
  echo "UseSTARTTLS=YES" | sudo tee -a $ssmtp_conf
  echo '[+] Mail configured. YOU MAY WANT TO DOUBLE CHECK THIS #DogScience.'
}


# -----------------------------------------------------------
# Complete the Bro installation
# -----------------------------------------------------------
function bro() {

  # -----------------------------------------------------------
  # Acquire and verify Bro
  # -----------------------------------------------------------
  gpg --keyserver pgp.mit.edu --recv-keys 33F15EAEF8CB8019
  wget -P "${INSTALL_DIR}" https://www.bro.org/downloads/bro-${BRO_LATEST}.tar.gz{,.asc}
  gpg --verify "${INSTALL_DIR}/bro-${BRO_LATEST}.tar.gz.asc" "${INSTALL_DIR}/bro-${BRO_LATEST}.tar.gz" || { echo '[-] FATAL: Bad signature on Bro. Verify integrity of signing key and archive.'; exit 2; }

  echo -n '[+] Good signature on Bro. Extracting... '
  tar xf "${INSTALL_DIR}/bro-${BRO_LATEST}.tar.gz" -C "${INSTALL_DIR}"
  echo 'done.'

  # -----------------------------------------------------------
  # Build Bro, this might take a while.
  # -----------------------------------------------------------
  echo '[+] Building Bro. This might take a while... '
  sleep 5

  sudo mkdir -p /opt/nsm/bro
  cd "${INSTALL_DIR}/bro-${BRO_LATEST}"
  ./configure --prefix=/opt/nsm/bro && make && sudo make install || { echo '[-] FATAL: Failed to build Bro. Verify all necessary dependencies are installed.'; exit 3; }
  cd -
  echo '[+] Bro build complete, bro.'

  # -----------------------------------------------------------
  # Clean up the Bro files
  # -----------------------------------------------------------
  rm -rf "${INSTALL_DIR}/bro-${BRO_LATEST}"*
}


# -----------------------------------------------------------
# Complete the Critical Stack installation
# A bug exists in the version of gnutls with which wget is
# linked. This will cause wget to fail on the download so I
# exported the intel.criticalstack.com certificate to its own
# file. The cert can be used with --ca-certificate= option.
# Google: gnutls bug tracker "hasn't got a known issuer"
# -----------------------------------------------------------
function critical_stack() {
  wget -P "${INSTALL_DIR}" --ca-certificate="${SWEET_SEC}/intel.criticalstack.com.crt" https://intel.criticalstack.com/client/critical-stack-intel-arm.deb
  sudo dpkg -i "${INSTALL_DIR}/critical-stack-intel-arm.deb"
  sudo -u critical-stack critical-stack-intel api $cs_api 
  rm -f "${INSTALL_DIR}/critical-stack-intel-arm.deb"
  echo '[+] Critical Stack installation complete.'
}


# -----------------------------------------------------------
# Complete the Elasticsearch installation
# -----------------------------------------------------------
function elasticsearch() {
  wget -P "${INSTALL_DIR}" https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ES_LATEST}.deb{,.sha1}
  echo -en "\t${INSTALL_DIR}/elasticsearch-${ES_LATEST}.deb" >> "${INSTALL_DIR}/elasticsearch-${ES_LATEST}.deb.sha1"
  sha1sum -c "${INSTALL_DIR}/elasticsearch-${ES_LATEST}.deb.sha1" || { echo '[-] FATAL: Bad SHA-1 checksum for Elasticsearch. Verify integrity of archive.'; exit 5; }
  sudo dpkg -i "${INSTALL_DIR}/elasticsearch-${ES_LATEST}.deb"
  rm -f "${INSTALL_DIR}/elasticsearch-${ES_LATEST}.deb"*
  sudo systemctl enable elasticsearch.service
  echo '[+] Elasticsearch installation complete.'
}


# -----------------------------------------------------------
# Complete the Logstash installation
# -----------------------------------------------------------
function logstash() {

  # -----------------------------------------------------------
  # Base Logstash setup
  # -----------------------------------------------------------
  wget -P "${INSTALL_DIR}" https://artifacts.elastic.co/downloads/logstash/logstash-${LS_LATEST}.deb{,.sha1}
  echo -en "\t${INSTALL_DIR}/logstash-${LS_LATEST}.deb" >> "${INSTALL_DIR}/logstash-${LS_LATEST}.deb.sha1"
  sha1sum -c "${INSTALL_DIR}/logstash-${LS_LATEST}.deb.sha1" || { echo '[-] FATAL: Bad SHA-1 checksum for Logstash. Verify integrity of archive.'; exit 6; }
  sudo dpkg -i "${INSTALL_DIR}/logstash-${LS_LATEST}.deb"
  rm -f "${INSTALL_DIR}/logstash-${LS_LATEST}.deb"*
  echo '[+] Base Logstash installation complete.'

  # -----------------------------------------------------------
  # Java Foreign Function Interface. The `rm -rf` needs sudo
  # else several subdirectories will fail to unlink
  # -----------------------------------------------------------
  cwd="${PWD}"
  git clone https://github.com/jnr/jffi.git "${INSTALL_DIR}/jffi"
  cd "${INSTALL_DIR}/jffi"
  sudo ant jar
  sudo cp -av build/jni/libjffi-*.so /usr/share/logstash/vendor/jruby/lib/jni/arm-Linux
  sudo zip -g /usr/share/logstash/vendor/jruby/lib/jruby.jar /usr/share/logstash/vendor/jruby/lib/jni/arm-Linux/libjffi-*.so
  sudo rm -rf "${INSTALL_DIR}/jffi"
  echo '[+] Base JFFI installation complete.'

  # -----------------------------------------------------------
  # Logstash configuration
  # -----------------------------------------------------------
  sudo mkdir /etc/logstash/custom_patterns /etc/logstash/translate
  sudo cp -av "${SWEET_SEC}/logstash.conf" /etc/logstash/conf.d  
  sudo cp -av "${SWEET_SEC}/bro.rule" /etc/logstash/custom_patterns
  sudo sed -i -e "s/SMTP_HOST/${smtpHost}/g; s/SMTP_PORT/${smtpPort}/g; s/EMAIL_USER/${emailAddr}/g; s/EMAIL_PASS/${emailPwd}/g" /etc/logstash/conf.d/logstash.conf
  echo '[+] Logstash configuration complete.'
}


# -----------------------------------------------------------
# Complete the Kibana installation
# -----------------------------------------------------------
function kibana() {

  # -----------------------------------------------------------
  # Base Kibana setup
  # -----------------------------------------------------------
  wget -P "${INSTALL_DIR}" https://artifacts.elastic.co/downloads/kibana/kibana-${KB_LATEST}-linux-x86.tar.gz{,.sha1}
  echo -en "\t${INSTALL_DIR}/kibana-${KB_LATEST}-linux-x86.tar.gz" >> "${INSTALL_DIR}/kibana-${KB_LATEST}-linux-x86.tar.gz.sha1"
  sha1sum -c "${INSTALL_DIR}/kibana-${KB_LATEST}-linux-x86.tar.gz.sha1" || { echo '[-] FATAL: Bad SHA-1 checksum for Kibana. Verify integrity of archive.'; exit 3; }
  tar xf "${INSTALL_DIR}/kibana-${KB_LATEST}-linux-x86.tar.gz" -C "${INSTALL_DIR}"

  sudo rm -rf /opt/kibana
  sudo mv -v "${INSTALL_DIR}/kibana-${KB_LATEST}-linux-x86" /opt/kibana
  rm -f "${INSTALL_DIR}/kibana-${KB_LATEST}-linux-x86.tar.gz"*
  echo '[+] Base Kibana installation complete.'

  # -----------------------------------------------------------
  # Node setup
  # -----------------------------------------------------------
  sudo apt remove -y nodejs-legacy nodejs nodered
  wget -P "${INSTALL_DIR}" http://node-arm.herokuapp.com/node_latest_armhf.deb
  sudo dpkg -i "${INSTALL_DIR}/node_latest_armhf.deb"
  sudo rm /opt/kibana/node/bin/node /opt/kibana/node/bin/npm "${INSTALL_DIR}/node_latest_armhf.deb"
  sudo ln -s /usr/local/bin/node /opt/kibana/node/bin/node
  sudo ln -s /usr/local/bin/npm /opt/kibana/node/bin/npm
  echo '[+] Node for armhf installation complete.'

  # -----------------------------------------------------------
  # Situate Kibana for systemd
  # -----------------------------------------------------------
  sudo cp -av "${SWEET_SEC}/"{start,stop}_kibana /usr/local/bin
  sudo chmod 0755 /usr/local/bin/{start,stop}_kibana
  sudo cp -av "${SWEET_SEC}/system/kibana.service" /etc/systemd/system
  sudo systemctl enable kibana.service
  echo '[+] Kibana configuration complete.'
}


# -----------------------------------------------------------
# Retrieve some simple IP blacklists
# -----------------------------------------------------------
function get_ip_lists() {
  echo -n '[+] Retrieving IP blacklists: '
  wget -qO- http://www.malwaredomainlist.com/hostslist/ip.txt | tr -d '\r' | while read ip; do echo "\"$ip\": \"YES\""; done | sudo tee /etc/logstash/translate/mdl-ip.yaml
  echo -n 'MalwareDomainList '
  # -----------------------------------------------------------
  # Commented out tor exit nodes because 'Use Signal. Use Tor.'
  # -----------------------------------------------------------
  # wget -qO- https://check.torproject.org/exit-addresses | grep ^ExitAddress | awk '{print $2}' | while read ip; do echo "\"$ip\": \"YES\""; done | sudo tee /etc/logstash/translate/tor-exitnode.yaml
  # echo -n 'TorExitNodes '
  echo
}


# -----------------------------------------------------------
# Restart and deploy ELK and Bro
# -----------------------------------------------------------
function init_services() {
  sudo systemctl restart elasticsearch.service kibana.service logstash.service
  echo '[+] Initialized ELK stack.'

  sudo /opt/nsm/bro/bin/broctl deploy
  sudo /opt/nsm/bro/bin/broctl start
  echo '[+] Deployed and started Bro.'
}


# -----------------------------------------------------------
# Wrap everything up for execution
# -----------------------------------------------------------
function main() {
  dependencies        # Update apt and install the needed dependencies
  mailcall            # Configure mail transmissions
  bro                 # Complete the Bro installation
  critical_stack      # Complete the Critical Stack installation
  elasticsearch       # Complete the Elasticsearch installation
  logstash            # Complete the Logstash installation
  kibana              # Complete the Kibana installation
  get_ip_lists        # Retrieve some simple IP blacklists
  init_services       # Restart and deploy ELK and Bro
}


# -----------------------------------------------------------
# Make it do the thing
# -----------------------------------------------------------
main
