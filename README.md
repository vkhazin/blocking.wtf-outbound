# Goodbye Censorship and Blocking! #

# Objectives #
* By-pass Internet Service Provider, Country, Organizational, or geo-blocking
* No more: "Sorry, access to this site is blocked!"
* No more: "Sorry this service is not available outside of Antarctica!"
* Pay least amount of money for the service - $5/month or less

# How is it different from commercial Vpn Services? #
* Commercial Services are well known and hence are easy blocked 
* Commercial Services carry detectable patterns, e.g. volume of traffic from a single/few ips
* Involved parties can implement automated detection and blocking processes
* Commercial Services are subject to legal and illegal actions possibly compromising consumer security

# Why this solution would work differently #
* Large number of small, near individual vpn servers are harder to track
* One of the ports in use (443) is nearly impossible to block as it is the same port every secure web site using to serve encrypted traffic
* Vpn Servers are not accessible to anyone but you
* You can re-provision vpn server often to minimize traceability and blocking
* You can re-provision vpn server with a new vps provider/country to jump jurisdictions

# Is it bullet Proof? #
* It is not 100% untraceable or undetectable
* It is just less likely to be flagged out than commercial services and to be blocked

# What are the risks? #
* Destination service can trace traffic to the VPN server on hosted provider network
* Hosted server provider can trace the traffic between their network and your ISP network
* ISP can trace traffic from their network to your ip and hence location
* Once the 3 parties trace is established you are exposed

# How does it work? #
* Subscribe to any VPS (virtual private server) service and create an instance of Ubuntu 16.04 TLS: Aws, Azure, DigitalOcean, Linode, or anywhere else
* Pick the cheapest instances available: 1 core and 0.75GB RA will do, network speed is more important and monthly traffic should be reasonable, e.g. 1TB/month
* With Aws, Azure and other private network providers: configure inbound security groups for incoming traffic: 22 - tcp, 443 - tcp and 1194 - udp.
* Login into your instance using ssh from MacOS/Linux terminal or using Windows Putty
* Clone this repo using git:
```
git clone https://github.com/vkhazin/blocking-bash-outbound.git
```
* Change into the directory:
```
cd ./blocking-bash-outbound/ubuntu-16-04
```
* Enable execution of the setup script:
```
chmod +x ./setup.sh
```
* Execute the script:
```
./setup.sh
```
* When the execution is finished, print out the content of ./client/client.conf
```
cat ./client/client.conf
```
* Highlight the entire content of the client.conf print-out and copy into the clipboard using ctrl-c or command-c
* Logout from the virtual server:
```
exit
```
* When back to your operating system, create a text file client.conf, paste the content of the clipboard into the file, and save the file
* Download and Install [OpenVpn Client](https://openvpn.net/index.php/open-source/downloads.html) or [Pritunl Client](https://client.pritunl.com/)
* Using the installed import the clien.conf file to connect to the newly installed Vpn Server
* Connect and verify that all your traffic now flows through the Vpn Server by accessing http://ipinfo.io
* ipinfo.io should list ip address and map of your Vpn Server location rather than you actual location
* From that moment all traffic from you machine will be tunneled via the Vpn Server hiding your actual ip and location
* You can also use a dd-wrt custom firmware to route all your traffic through the router


# DD-WRT Configuration #
* Server IP/Name: public ip of your vpn server
* Port: 1194
* Tunnel Device: TUN
* Tunnel Protocol: UDP
* Encryption Cipher: Blowfish CBC
* Has Algorithm: SHA1
* Advanced Options: Enable
* TLS Cipher: None
* LZO Compression: Adaptive
* NAT: Enable
* IP Address: empty
* Subnet Mask: empty
* Tunnel MTU setting: 1500
* Tunnel UDP Fragment: empty
* Tunnel UDP MSS-Fix: Enable
* nsCertType verification: unselected
* TLS Auth Key: content of the client.conf between tls-auth xml-like tags
* Additional Config: empty
* Policy based Routing: empty
* PKCS12 Key: empty
* Static Key: empty
* CA Cert: content of the client.conf between ca xml-like tags
* Public Client Cert: content of the client.conf between cert xml-like tags
* Private Client Key: content of the client.conf between key xml-like tags
* To confirm or to troubleshoot check dd-wrt status->OpenVpn page, look for the 'Initialization Sequence Completed' statement or for errors/warnings
* Don't forget to check http://ipinfo.io as the final confirmation - it must list Vpn Server public IP not yours

# P.S. #
* dh2048.pem has been pre-generated as it takes a long time to generate
* Should you choose to generate your own run following command before running ubuntu-16-04.sh:
```
openssl dhparam -out dh2048.pem 2048
```
* Rest of the secrets and certificates are re-generated every time you run ubuntu-16-04.sh