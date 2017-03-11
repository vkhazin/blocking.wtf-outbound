# Capture current folder
startFolder=`pwd`
easyRsaFolder='/usr/share/easy-rsa'

#####################################################################
# Copy vars and server.conf                                         #
#####################################################################
sudo mkdir /etc/openvpn
sudo mkdir /etc/openvpn/keys
sudo cp ./vars /etc/openvpn/vars
sudo cp ./server.conf /etc/openvpn
sudo cp ./dh2048.pem /etc/openvpn/keys
#####################################################################

# Update distro
sudo apt-get update
# Install OpenVpn using Ubuntu repositories
sudo apt-get install openvpn -y
# Install and configure easy-rsa - not sure we need it on every srv
sudo apt-get install easy-rsa -y

#####################################################################
# Generate Server keys                                              #
#####################################################################
cd $easyRsaFolder
source /etc/openvpn/vars
sudo -E ./clean-all
sudo -E ./build-ca --batch
sudo -E ./build-key-server --batch server
sudo -E openvpn --genkey --secret /etc/openvpn/keys/ta.key
# Takes too long to generate on every setup
#openssl dhparam -out ./keys/dh2048.pem 2048
#####################################################################

#####################################################################
# Generate Client keys                                              #
#####################################################################
clientId=client #$(uuidgen)
sudo -E ./build-key --batch $clientId
#####################################################################

#####################################################################
# Copy keys to /etc/openvpn/keys                                    #
#####################################################################
sudo cp $startFolder/dh2048.pem /etc/openvpn/keys
sudo cp -r $easyRsaFolder/keys/ /etc/openvpn
#####################################################################

#####################################################################
# Start Service                                                     #
#####################################################################
sudo service openvpn start
#####################################################################

#####################################################################
# Configure Forwarding and Nat                                      #
#####################################################################
# enable ip forwarding
sudo sysctl -w net.ipv4.ip_forward=1
# setup nat rules
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -j ACCEPT
sudo bash -c "iptables-save > /etc/iptables/rules.v4"
# Persist nat rules
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo -E apt-get install iptables-persistent -y
sudo -E service iptables-persistent start
#####################################################################

#####################################################################
# Copy keys to home directory                                       #
#####################################################################
cd "$startFolder"
mkdir ./client
sudo cp /etc/openvpn/keys/$clientId.crt ./client
sudo cp /etc/openvpn/keys/$clientId.key ./client
sudo cp /etc/openvpn/keys/ca.crt ./client
sudo cp /etc/openvpn/keys/ta.key ./client
sudo curl ipinfo.io/ip > ./client/server.ip
sudo cp ./client.conf ./client/client.conf
echo "remote" `curl ipinfo.io/ip` "udp 1194" >> ./client/client.conf
