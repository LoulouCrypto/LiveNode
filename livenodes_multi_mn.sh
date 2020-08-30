#!/bin/bash
# Script done by LoulouCrypto
# https://www.louloucrypto.fr

CONFIG_FILE='livenodes.conf'
CONFIGFOLDER='/home/$USER/.livenodes'
COIN_PATH='/usr/local/bin/'
#64 bit only
COIN_TGZ='https://github.com/livenodescoin/livenodes/releases/download/v3.3.5/livenodes-3.3.5-headless-x86_64-linux-gnu.tar.gz'
COIN_DAEMON='livenodesd'
COIN_CLI='livenodes-cli'
COIN_NAME='LivenodesCoinV3'
BOOTSTRAP_TGZ='https://github.com/livenodescoin/livenodes/releases/download/v3.3.5/bootstrap.zip'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

progressfilt () {
  local flag=false c count cr=$'\r' nl=$'\n'
  while IFS='' read -d '' -rn 1 c
  do
    if $flag
    then
      printf '%c' "$c"
    else
      if [[ $c != $cr && $c != $nl ]]
      then
        count=0
      else
        ((count++))
        if ((count > 1))
        then
          flag=true
        fi
      fi
    fi
  done
}

function detect_ubuntu() {
 if [[ $(lsb_release -d) == *18.04* ]]; then
   UBUNTU_VERSION=18
 elif [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
 elif [[ $(lsb_release -d) == *14.04* ]]; then
   UBUNTU_VERSION=14
else
   echo -e "${RED}You are not running Ubuntu 14.04, 16.04 or 18.04 Installation is cancelled.${NC}"
   exit 1
fi
}

function configure_startup() {
  cat << EOF > /etc/init.d/$COIN_NAME-$USER
#! /bin/bash
### BEGIN INIT INFO
# Provides: $COIN_NAME
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: $COIN_NAME
# Description: This file starts and stops $COIN_NAME MN server
#
### END INIT INFO
case "\$1" in
 start)
   sleep $TIMER
   $COIN_PATH/$COIN_DAEMON -daemon -conf=/home/$USER/.livenodes/$CONFIG_FILE -datadir=/home/$USER/.livenodes
   sleep 5
   ;;
 stop)
   $COIN_PATH/$COIN_CLI -conf=/home/$USER/.livenodes/$CONFIG_FILE -datadir=/home/$USER/.livenodes stop
   ;;
 restart)
   $COIN_CLI stop
   sleep 10
   $COIN_PATH/$COIN_CLI -conf=/home/$USER/.livenodes/$CONFIG_FILE -datadir=/home/$USER/.livenodes restart
   ;;
 *)
   echo "Usage: $COIN_NAME-$USER {start|stop|restart}" >&2
   exit 3
   ;;
esac
EOF
chmod +x /etc/init.d/$COIN_NAME-$USER >/dev/null 2>&1
update-rc.d $COIN_NAME-$USER defaults >/dev/null 2>&1
/etc/init.d/$COIN_NAME-$USER start >/dev/null 2>&1
if [ "$?" -gt "0" ]; then
 sleep 5
 /etc/init.d/$COIN_NAME-$USER start >/dev/null 2>&1
fi
}

function configure_systemd() {
cd ~/

sudo cat << EOF > $COIN_NAME-$USER.service
[Unit]
Description=$COIN_NAME-$USER service
After=network.target
[Service]
User=$USER
Type=forking
#PIDFile=/home/$USER/.livenodes/$COIN_NAME.pid
TimeoutStartSec=infinity
ExecStartPost=/bin/sleep $TIMER
ExecStart=$COIN_PATH/$COIN_DAEMON -daemon -conf=/home/$USER/.livenodes/$CONFIG_FILE -datadir=/home/$USER/.livenodes
ExecStop=-$COIN_PATH/$COIN_CLI -conf=/home/$USER/.livenodes/$CONFIG_FILE -datadir=/home/$USER/.livenodes stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF
sudo mv $COIN_NAME-$USER.service /etc/systemd/system/

  sudo systemctl daemon-reload
  sleep 3
  sudo systemctl start $COIN_NAME-$USER.service
  sudo systemctl enable $COIN_NAME-$USER.service >/dev/null 2>&1
  
  if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
    echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $COIN_NAME-$USER.service"
    echo -e "systemctl status $COIN_NAME-$USER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}


function create_config() {
  cd ~/
  mkdir .livenodes >/dev/null 2>&1
  sleep 2
  cd .livenodes
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  cat << EOF > livenodes.conf
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
listen=1
server=1
daemon=0
rpcport=$RPC_PORT
port=$COIN_PORT
EOF
cd ~/
}

function create_key() {
  echo -e "Enter your ${RED}$COIN_NAME Masternode Private Key${NC}.\nLeave it blank to generate a new ${RED}$COIN_NAME Masternode Private Key${NC} for you:"
  read -e COINKEY
  echo -e "Enter your ${RED}$COIN_NAME TX_OUTPUT${NC}.\nLeave it blank if you want to put it manualy"
  read -e TX_OUTPUT
  echo -e "Enter your ${RED}$COIN_NAME TX_INDEX${NC}.\nLeave it blank if you want to put it manualy"
  read -e TX_INDEX
  sleep 2
  if [[ -z "$COINKEY" ]]; then
	$COIN_DAEMON -daemon
      sleep 45
    COINKEY=$($COIN_CLI masternode genkey)
    if [ "$?" -gt "0" ];
      then
      echo -e "${RED}Wallet not fully loaded. Let us wait for 30s and try again to generate the Private Key${NC}"
      sleep 30
      COINKEY=$($COIN_CLI masternode genkey)
      if [ "$?" -gt "0" ];
      then
        echo -e "${RED}Wallet not fully loaded. Let us wait for another 30s and try again to generate the Private Key${NC}"
        sleep 30
        COINKEY=$($COIN_CLI masternode genkey)
      fi
    fi
  $COIN_CLI stop
  sleep 10

fi
clear
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' /home/$USER/.livenodes/livenodes.conf
  cat << EOF >> /home/$USER/.livenodes/livenodes.conf
logintimestamps=1
maxconnections=256
#bind=
staking=0
masternode=1
externalip=[$NODEIP]
masternodeaddr=[$NODEIP]:40555
masternodeprivkey=$COINKEY

#User : $USER
# $USER [$NODEIP]:40555 $COINKEY  $TX_OUTPUT $TX_INDEX
EOF
sleep 2
  cd /home/$USER/.livenodes
  rm -rf blocks chainstate 
  sleep 1
  echo -e "Downloading BootStrap"
  wget --progress=bar:force $BOOTSTRAP_TGZ 2>&1 | progressfilt
  unzip bootstrap.zip >/dev/null 2>&1
  sleep 2
  cd ..
  rm -rf bootstrap.zip
  cd ~
  sleep 2
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN} $COIN_PORT ${NC}"
  sudo ufw allow ssh >/dev/null 2>&1
  sudo ufw allow $COIN_PORT >/dev/null 2>&1
  sudo ufw default allow outgoing >/dev/null 2>&1
  echo "y" | sudo ufw enable >/dev/null 2>&1
  sudo ufw reload
}

function get_ip() {
  declare -a NODE_IPS
  for ips in $(curl --interface $ips --connect-timeout 2 hostname --all-ip-addresses || hostname -i)
  do
    NODE_IPS+=($(/sbin/ip -o addr show scope global | awk '{gsub(/\/.*/,"",$4); print $4}'))
    #NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com && curl --interface $ips --connect-timeout 2 -6 icanhazip.com))
  done
clear
  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
	echo -e "${YELLOW}"
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function detect_ubuntu() {
 if [[ $(lsb_release -d) == *18.04* ]]; then
   UBUNTU_VERSION=18
 elif [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
 elif [[ $(lsb_release -d) == *14.04* ]]; then
   UBUNTU_VERSION=14
else
   echo -e "${RED}You are not running Ubuntu 14.04, 16.04 or 18.04 Installation is cancelled.${NC}"
   exit 1
fi
}

function create_swap() {
 echo -e "Checking if swap space is needed."
 PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
 SWAP=$(swapon -s)
 if [[ "$PHYMEM" -lt "2"  &&  -z "$SWAP" ]]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 6G swap file.${NC}"
    SWAPFILE=$(mktemp)
    sudo dd if=/dev/zero of=$SWAPFILE bs=1024 count=6M
    sudo chmod 600 $SWAPFILE
    sudo mkswap $SWAPFILE
    sudo swapon -a $SWAPFILE
 else
  echo -e "${GREEN}The server running with at least 2G of RAM, or a SWAP file is already in place.${NC}"
 fi
 clear
}


function important_information() {
 echo
 echo -e "================================================================================"
 echo -e "$COIN_NAME Masternode is up and running listening on port ${RED}$COIN_PORT${NC}."
 echo -e "Configuration file is: ${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
 if (( $UBUNTU_VERSION == 16 || $UBUNTU_VERSION == 18 )); then
   echo -e "Start: ${RED}systemctl start $COIN_NAME-$USER.service${NC}"
   echo -e "Stop: ${RED}systemctl stop $COIN_NAME-$USER.service${NC}"
   echo -e "Status: ${RED}systemctl status $COIN_NAME-$USER.service${NC}"
 else
   echo -e "Start: ${RED}/etc/init.d/$COIN_NAME_$USER start${NC}"
   echo -e "Stop: ${RED}/etc/init.d/$COIN_NAME_$USER stop${NC}"
   echo -e "Status: ${RED}/etc/init.d/$COIN_NAME_$USER status${NC}"
 fi
 echo -e "VPS_IP:PORT ${RED}[$NODEIP]:40555${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$COINKEY${NC}"
 echo -e "Check if $COIN_NAME is running by using the following command:\n${RED}ps -ef | grep $COIN_DAEMON | grep -v grep${NC}"
  echo -e "copy to your masternode.conf wallet: ${RED}Your_Alias [$NODEIP]:40555 $COINKEY $TX_OUTPUT $TX_INDEX ${NC}"
 echo -e "================================================================================"
 echo -e "Lunching ${RED}LiveNodes Masternode${NC}, it may take some time due to the${RED} $TIMER Sec Start Delay.${NC}"
}

function nbr_nodes() {
 NBR_DAEMON=$(ps -C livenodesd -o pid= | wc -l)
 figlet -f slant "LiveNodes"
 echo -e "${RED}How many running $COIN_NAME nodes on this server ? $NBR_DAEMON ? ${NC}"
 read -e NBR_NODES
 COIN_PORT=$(expr 40555 + $NBR_NODES '*' 2)
 RPC_PORT=$(expr $COIN_PORT + 1)
 TIMER=$(($NBR_NODES * 30))
}

function prepare_system_for_download() {
echo -e "Prepare the system to install ${GREEN}$COIN_NAME${NC} master node."
sudo apt-get update >/dev/null 2>&1
#echo -e "Upgrading System, it may take some time.${NC}"
#sudo apt-get upgrade -y >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
sudo apt-get install -y  make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev libzmq3-dev ufw pkg-config libevent-dev mc libdb5.3++ curl systemd figlet >/dev/null 2>&1
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt install -y curl sytemd figlet"
 exit 1
fi

clear
}

function setup_node() {
  nbr_nodes
  get_ip
  create_config
  create_key
  update_config
  enable_firewall
  important_information
  if (( $UBUNTU_VERSION == 16 || $UBUNTU_VERSION == 18 )); then
    configure_systemd
  else
    configure_startup
  fi
}


##### Main #####
clear
cd ~/
detect_ubuntu
create_swap
prepare_system_for_download
setup_node
cd ~/
rm -f livenodes_multi_mn.sh

# If you want to support me
# LNO wallet : 
# LL2bfd8uqMemYpW9xmtqmkA5oz1vvnvkKL
