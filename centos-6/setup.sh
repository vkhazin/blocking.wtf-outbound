# Capture current folder
startFolder=`pwd`
easyRsaFolder='/usr/share/easy-rsa/2.0'

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
sudo cp ./server.conf /etc/openvpn/server-tcp-443.conf
echo "port 443" | sudo tee --append /etc/openvpn/server-tcp-443.conf
echo "proto tcp-server" | sudo tee --append /etc/openvpn/server-tcp-443.conf
echo "server 172.16.255.0 255.255.255.0" | sudo tee --append /etc/openvpn/server-tcp-443.conf

sudo cp ./server.conf /etc/openvpn/server-udp-1194.conf
echo "port 1194" | sudo tee --append /etc/openvpn/server-udp-1194.conf
echo "proto udp" | sudo tee --append /etc/openvpn/server-udp-1194.conf
echo "server 172.16.254.0 255.255.255.0" | sudo tee --append /etc/openvpn/server-udp-1194.conf
#####################################################################

# Update distro
sudo yum update -y
# Install OpenVpn using epel repositories
sudo yum -y install epel-release
sudo yum install openvpn -y
# Install and configure easy-rsa - not sure we need it on every srv
sudo yum install easy-rsa -y

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
#sudo bash -c "iptables-save > /etc/iptables/rules.v4"
# Persist nat rules
sudo service iptables save
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
serverId=`curl ipinfo.io/ip`
sudo cp ./client.conf ./client/client.conf
# Append server ip
echo "remote" $serverId "1194 udp" | sudo tee --append ./client/client.conf
echo "remote" $serverId "443 tcp" | sudo tee --append ./client/client.conf
# Append ca
echo "<ca>" | sudo tee --append ./client/client.conf
sudo cat ./client/ca.crt | sudo tee --append ./client/client.conf
echo "</ca>" | sudo tee --append ./client/client.conf
# Append client cert
echo "<cert>" | sudo tee --append ./client/client.conf
sudo cat ./client/client.crt | sudo tee --append ./client/client.conf
echo "</cert>" | sudo tee --append ./client/client.conf
# Append client key
echo "<key>" | sudo tee --append ./client/client.conf
sudo cat ./client/client.key | sudo tee --append ./client/client.conf
echo "</key>" | sudo tee --append ./client/client.conf
# Append ta
echo "key-direction 1" | sudo tee --append ./client/client.conf
echo "<tls-auth>" | sudo tee --append ./client/client.conf
sudo cat ./client/ta.key | sudo tee --append ./client/client.conf
echo "</tls-auth>" | sudo tee --append ./client/client.conf