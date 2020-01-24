set -e
# Capture current folder
startFolder=`pwd`
easyRsaFolder='/usr/share/easy-rsa'

#####################################################################
# Copy vars and server.conf                                         #
#####################################################################
sudo mkdir /etc/openvpn
sudo mkdir /etc/openvpn/keys
sudo cp ./vars /etc/openvpn/vars
sudo cp ./dh2048.pem /etc/openvpn/keys
#####################################################################

#####################################################################
# Configure server.conf                                         #
#####################################################################
export filename="/etc/openvpn/server-tcp-80.conf"
sudo cp ./server.conf $filename
echo "port 80" | sudo tee --append $filename
echo "proto tcp-server" | sudo tee --append $filename
echo "server 172.16.253.0 255.255.255.0" | sudo tee --append $filename

export filename="/etc/openvpn/server-tcp-443.conf"
sudo cp ./server.conf $filename
echo "port 443" | sudo tee --append $filename
echo "proto tcp-server" | sudo tee --append $filename
echo "server 172.16.255.0 255.255.255.0" | sudo tee --append $filename

export filename="/etc/openvpn/server-udp-1194.conf"
sudo cp ./server.conf $filename
echo "port 1194" | sudo tee --append $filename
echo "proto udp" | sudo tee --append $filename
echo "server 172.16.254.0 255.255.255.0" | sudo tee --append $filename
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

#####################################################################
# Configure client.conf                                             #
#####################################################################
export filename="./client/client.conf"
serverId=`curl ipinfo.io/ip`
sudo cp $filename ./client.conf
# Append server ip
echo "remote" $serverId "1194 udp" | sudo tee --append $filename
echo "remote" $serverId "443 tcp" | sudo tee --append $filename
echo "remote" $serverId "80 tcp" | sudo tee --append $filename
# Append ca
echo "<ca>" | sudo tee --append $filename
sudo cat ./client/ca.crt | sudo tee --append $filename
echo "</ca>" | sudo tee --append $filename
# Append client cert
echo "<cert>" | sudo tee --append $filename
sudo cat ./client/client.crt | sudo tee --append $filename
echo "</cert>" | sudo tee --append ./client/client.conf
# Append client key
echo "<key>" | sudo tee --append $filename
sudo cat ./client/client.key | sudo tee --append $filename
echo "</key>" | sudo tee --append ./client/client.conf
# Append ta
echo "key-direction 1" | sudo tee --append $filename
echo "<tls-auth>" | sudo tee --append $filename
sudo cat ./client/ta.key | sudo tee --append $filename
echo "</tls-auth>" | sudo tee --append $filename
