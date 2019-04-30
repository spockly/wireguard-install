#!/bin/bash
#
# https://github.com/LiveChief/wireguard-install
#

WG_CONFIG="/etc/wireguard/wg0.conf"

if [[ "$EUID" -ne 0 ]]; then
    echo "Sorry, you need to run this as root"
    exit
fi

if [[ ! -e /dev/net/tun ]]; then
    echo "The TUN device is not available. You need to enable TUN before running this script"
    exit
fi

if [ -e /etc/debian_version ]; then
    DISTRO=$( lsb_release -is )
else
    echo "Your distribution is not supported (yet)"
    exit
fi

if [ "$( systemd-detect-virt )" == "openvz" ]; then
    echo "OpenVZ virtualization is not supported"
    exit
fi

if [ ! -f "$WG_CONFIG" ]; then
    ### Install server and add default client
    INTERACTIVE=${INTERACTIVE:-yes}
    PRIVATE_SUBNET_V4=${PRIVATE_SUBNET_V4:-"10.8.0.0/24"}
    PRIVATE_SUBNET_MASK_V4=$( echo $PRIVATE_SUBNET_V4 | cut -d "/" -f 2 )
    GATEWAY_ADDRESS_V4="${PRIVATE_SUBNET_V4::-4}1"
    PRIVATE_SUBNET_V6=${PRIVATE_SUBNET_V6:-"fd42:42:42::0/64"}
    PRIVATE_SUBNET_MASK_V6=$( echo $PRIVATE_SUBNET_V6 | cut -d "/" -f 2 )
    GATEWAY_ADDRESS_V6="${PRIVATE_SUBNET_V6::-4}1"

    if [ "$SERVER_HOST" == "" ]; then
        SERVER_HOST="$(wget -O - -q https://checkip.amazonaws.com)"
        if [ "$INTERACTIVE" == "yes" ]; then
            read -p "Servers public IP address is $SERVER_HOST. Is that correct? [y/n]: " -e -i "y" CONFIRM
            if [ "$CONFIRM" == "n" ]; then
                echo "Aborted. Use environment variable SERVER_HOST to set the correct public IP address"
                exit
            fi
        fi
    fi

    	echo "What port do you want WireGuard to listen to?"
	echo "   1) Default: 51820"
	echo "   2) Custom"
	echo "   3) Random [2000-65535]"
	until [[ "$PORT_CHOICE" =~ ^[1-3]$ ]]; do
		read -rp "Port choice [1-3]: " -e -i 1 PORT_CHOICE
	done
	case $PORT_CHOICE in
		1)
			SERVER_PORT="51820"
		;;
		2)
			until [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && [ "$SERVER_PORT" -ge 1 ] && [ "$SERVER_PORT" -le 65535 ]; do
				read -rp "Custom port [1-65535]: " -e -i 51820 SERVER_PORT
			done
		;;
		3)
			# Generate random number within private ports range
			SERVER_PORT=$(shuf -i2000-65535 -n1)
			echo "Random Port: $SERVER_PORT"
		;;
	esac
	
    echo "Are you behind a firewall or NAT?"
    echo "   1) Yes"
    echo "   2) No"
    until [[ "$NAT_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "Nat Choice [1-2]: " -e -i 2 NAT_CHOICE
    done
    case $NAT_CHOICE in
        1)
            NAT_CHOICE="25"
        ;;
        2)
            NAT_CHOICE="0"
        ;;
    esac
 
    echo "What MTU do you want to use?"
    echo "   1) 1500"
    echo "   2) 1420"
    until [[ "$MTU_CHOICE" =~ ^[1-2]$ ]]; do
        read -rp "MTU Choice [1-2]: " -e -i 2 MTU_CHOICE
    done
    case $MTU_CHOICE in
        1)
            MTU_CHOICE="1500"
        ;;
        2)
            MTU_CHOICE="1420"
        ;;
    esac

    if [ "$CLIENT_DNS_FIRST_V4" == "" ]; then
        echo "Which DNS do you want to use with the VPN?"
        echo "   1) Cloudflare"
        echo "   2) Google"
        echo "   3) OpenDNS"
        echo "   4) AdGuard"
        echo "   5) AdGuard Family Protection"
        echo "   6) Quad9"
        echo "   7) FDN"
        echo "   8) DNS.WATCH"
        echo "   9) Yandex Basic"
        echo "   10) Clean Browsing"
        read -p "DNS [1-10]: " -e -i 4 DNS_CHOICE

        case $DNS_CHOICE in
            1)
            CLIENT_DNS_FIRST_V4="1.1.1.1@853"
            CLIENT_DNS_SECOND_V4="1.0.0.1@853"
            CLIENT_DNS_FIRST_V6="2606:4700:4700::1111@853"
            CLIENT_DNS_SECOND_V6="2606:4700:4700::1001@853"
            ;;
            2)
            CLIENT_DNS_FIRST_V4="8.8.8.8@853"
            CLIENT_DNS_SECOND_V4="8.8.4.4@853"
            CLIENT_DNS_FIRST_V6="2001:4860:4860::8888@853"
            CLIENT_DNS_SECOND_V6="2001:4860:4860::8844@853"
            ;;
            3)
            CLIENT_DNS_FIRST_V4="208.67.222.222@853"
            CLIENT_DNS_SECOND_V4="208.67.220.220@853"
            CLIENT_DNS_FIRST_V6="2620:119:35::35@853"
            CLIENT_DNS_SECOND_V6="2620:119:53::53@853"
            ;;
            4)
            CLIENT_DNS_FIRST_V4="176.103.130.130@853"
            CLIENT_DNS_SECOND_V4="176.103.130.131@853"
            CLIENT_DNS_FIRST_V6="2a00:5a60::ad1:0ff@853"
            CLIENT_DNS_SECOND_V6="2a00:5a60::ad2:0ff@853"
            ;;
            5)
            CLIENT_DNS_FIRST_V4="176.103.130.132@853"
            CLIENT_DNS_SECOND_V4="176.103.130.134@853"
            CLIENT_DNS_FIRST_V6="2a00:5a60::bad1:0ff@853"
            CLIENT_DNS_SECOND_V6="2a00:5a60::bad2:0ff@853"
            ;;
            6)
            CLIENT_DNS_FIRST_V4="9.9.9.9@853"
            CLIENT_DNS_SECOND_V4="149.112.112.112@853"
            CLIENT_DNS_FIRST_V6="2620:fe::fe@853"
            CLIENT_DNS_SECOND_V6="2620:fe::9@853"
            ;;
            7)
            CLIENT_DNS_FIRST_V4="80.67.169.40@853"
            CLIENT_DNS_SECOND_V4="80.67.169.12@853"
            CLIENT_DNS_FIRST_V6="2001:910:800::40@853"
            CLIENT_DNS_SECOND_V6="2001:910:800::12@853"
            ;;
            8)
            CLIENT_DNS_FIRST_V4="84.200.69.80@853"
            CLIENT_DNS_SECOND_V4="84.200.70.40@853"
            CLIENT_DNS_FIRST_V6="2001:1608:10:25::1c04:b12f@853"
            CLIENT_DNS_SECOND_V6="2001:1608:10:25::9249:d69b@853"
            ;;
            9)
            CLIENT_DNS_FIRST_V4="77.88.8.8@853"
            CLIENT_DNS_SECOND_V4="77.88.8.1@853"
            CLIENT_DNS_FIRST_V6="2a02:6b8::feed:0ff@853"
            CLIENT_DNS_SECOND_V6="2a02:6b8:0:1::feed:0ff@853"
            ;;
            10)
            CLIENT_DNS_FIRST_V4="185.228.168.9@853"
            CLIENT_DNS_SECOND_V4="185.228.169.9@853"
            CLIENT_DNS_FIRST_V6="2a0d:2a00:1::2@853"
            CLIENT_DNS_SECOND_V6="2a0d:2a00:2::2@853"
            ;;
        esac
        
    fi

    if [ "$DISTRO" == "Ubuntu" ]; then
        apt-get update
        apt-get upgrade -y
        apt-get dist-upgrade -y
        apt-get autoremove -y
        apt-get install build-essential haveged -y
        apt-get install software-properties-common -y
        add-apt-repository ppa:wireguard/wireguard -y
        apt-get update
        apt-get install wireguard qrencode iptables-persistent -y
	apt-get install unattended-upgrades apt-listchanges -y
        wget -q -O /etc/apt/apt.conf.d/50unattended-upgrades "https://raw.githubusercontent.com/LiveChief/wireguard-install/master/unattended-upgrades/50unattended-upgrades.Ubuntu"
	apt-get install unbound unbound-host -y
	wget -O /var/lib/unbound/root.hints  https://www.internic.net/domain/named.cache
  echo "" > /etc/unbound/unbound.conf
  echo "server:
  num-threads: 4	
  do-ip6: yes
  #Enable logs	
  verbosity: 1	
  #list of Root DNS Server	
  root-hints: "/var/lib/unbound/root.hints"	
  #Use the root servers key for DNSSEC	
  auto-trust-anchor-file: "/var/lib/unbound/root.key"	
  #Respond to DNS requests on all interfaces	
  interface: 0.0.0.0	
  max-udp-size: 3072	
  #Authorized IPs to access the DNS Server	
  access-control: 0.0.0.0/0                 refuse	
  access-control: 127.0.0.1                 allow	
  access-control: 10.8.0.0/24               allow	
  #not allowed to be returned for public internet  names	
  private-address: 10.8.0.0/24	
  # Hide DNS Server info	
  hide-identity: yes	
  hide-version: yes	
  #Limit DNS Fraud and use DNSSEC	
  harden-glue: yes	
  harden-dnssec-stripped: yes	
  harden-referral-path: yes	
  #Add an unwanted reply threshold to clean the cache and avoid when possible a DNS Poisoning	
  unwanted-reply-threshold: 10000000	
  #Have the validator print validation failures to the log.	
  val-log-level: 1	
  #Minimum lifetime of cache entries in seconds	
  cache-min-ttl: 1800	
  #Maximum lifetime of cached entries	
  cache-max-ttl: 14400	
  prefetch: yes	
  prefetch-key: yes
  forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: $CLIENT_DNS_FIRST_V4
  forward-addr: $CLIENT_DNS_SECOND_V4
  forward-addr: $CLIENT_DNS_FIRST_V6
  forward-addr: $CLIENT_DNS_SECOND_V6" > /etc/unbound/unbound.conf
  	chown -R unbound:unbound /var/lib/unbound
	systemctl enable unbound
	service unbound restart
	chattr -i /etc/resolv.conf
	sed -i "s|nameserver|#nameserver|" /etc/resolv.conf
	sed -i "s|search|#search|" /etc/resolv.conf
	echo "nameserver 127.0.0.1" >> /etc/resolv.conf
	chattr +i /etc/resolv.conf
	
    elif [ "$DISTRO" == "Debian" ]; then
        echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable
        apt-get update
        apt-get upgrade -y
        apt-get dist-upgrade -y
        apt-get autoremove -y
        apt-get install build-essential haveged -y
        apt-get install wireguard qrencode iptables-persistent -y
	apt-get install unattended-upgrades apt-listchanges -y
        wget -q -O /etc/apt/apt.conf.d/50unattended-upgrades "https://raw.githubusercontent.com/LiveChief/wireguard-install/master/unattended-upgrades/50unattended-upgrades.Debian"
	apt-get install unbound unbound-host -y
	wget -O /var/lib/unbound/root.hints  https://www.internic.net/domain/named.cache
  echo "" > /etc/unbound/unbound.conf
  echo "server:
  num-threads: 4	
  do-ip6: yes
  #Enable logs	
  verbosity: 1	
  #list of Root DNS Server	
  root-hints: "/var/lib/unbound/root.hints"	
  #Use the root servers key for DNSSEC	
  auto-trust-anchor-file: "/var/lib/unbound/root.key"	
  #Respond to DNS requests on all interfaces	
  interface: 0.0.0.0	
  max-udp-size: 3072	
  #Authorized IPs to access the DNS Server	
  access-control: 0.0.0.0/0                 refuse	
  access-control: 127.0.0.1                 allow	
  access-control: 10.8.0.0/24               allow	
  #not allowed to be returned for public internet  names	
  private-address: 10.8.0.0/24	
  # Hide DNS Server info	
  hide-identity: yes	
  hide-version: yes	
  #Limit DNS Fraud and use DNSSEC	
  harden-glue: yes	
  harden-dnssec-stripped: yes	
  harden-referral-path: yes	
  #Add an unwanted reply threshold to clean the cache and avoid when possible a DNS Poisoning	
  unwanted-reply-threshold: 10000000	
  #Have the validator print validation failures to the log.	
  val-log-level: 1	
  #Minimum lifetime of cache entries in seconds	
  cache-min-ttl: 1800	
  #Maximum lifetime of cached entries	
  cache-max-ttl: 14400	
  prefetch: yes	
  prefetch-key: yes
  forward-zone:
  name: "."
  forward-tls-upstream: yes
  forward-addr: $CLIENT_DNS_FIRST_V4
  forward-addr: $CLIENT_DNS_SECOND_V4
  forward-addr: $CLIENT_DNS_FIRST_V6
  forward-addr: $CLIENT_DNS_SECOND_V6" > /etc/unbound/unbound.conf
  	chown -R unbound:unbound /var/lib/unbound
	systemctl enable unbound
	service unbound restart
	chattr -i /etc/resolv.conf
	sed -i "s|nameserver|#nameserver|" /etc/resolv.conf
	sed -i "s|search|#search|" /etc/resolv.conf
	echo "nameserver 127.0.0.1" >> /etc/resolv.conf
	chattr +i /etc/resolv.conf
    fi

    SERVER_PRIVKEY=$( wg genkey )
    SERVER_PUBKEY=$( echo $SERVER_PRIVKEY | wg pubkey )
    CLIENT_PRIVKEY=$( wg genkey )
    CLIENT_PUBKEY=$( echo $CLIENT_PRIVKEY | wg pubkey )
    CLIENT_ADDRESS_V4="${PRIVATE_SUBNET_V4::-4}3"
    CLIENT_ADDRESS_V6="${PRIVATE_SUBNET_V6::-4}3"

    mkdir -p /etc/wireguard
    touch $WG_CONFIG && chmod 600 $WG_CONFIG

    echo "# $PRIVATE_SUBNET_V4 $PRIVATE_SUBNET_V6 $SERVER_HOST:$SERVER_PORT $SERVER_PUBKEY $MTU_CHOICE $NAT_CHOICE
[Interface]
Address = $GATEWAY_ADDRESS_V4/$PRIVATE_SUBNET_MASK_V4, $GATEWAY_ADDRESS_V6/$PRIVATE_SUBNET_MASK_V6
ListenPort = $SERVER_PORT
PrivateKey = $SERVER_PRIVKEY
SaveConfig = false" > $WG_CONFIG

    echo "# client
[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = $CLIENT_ADDRESS_V4/32, $CLIENT_ADDRESS_V6/128" >> $WG_CONFIG

    echo "[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_ADDRESS_V4/$PRIVATE_SUBNET_MASK_V4, $CLIENT_ADDRESS_V6/$PRIVATE_SUBNET_MASK_V6
DNS = 10.8.0.1
MTU = $MTU_CHOICE
[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $SERVER_HOST:$SERVER_PORT
PersistentKeepalive = $NAT_CHOICE" > $HOME/client-wg0.conf
qrencode -t ansiutf8 -l L < $HOME/client-wg0.conf

    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "net.ipv4.conf.all.forwarding=1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    sysctl -p

    if [ "$DISTRO" == "Debian" ]; then	
        iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT	
        ip6tables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT	
        iptables -A FORWARD -m conntrack --ctstate NEW -s $PRIVATE_SUBNET_V4 -m policy --pol none --dir in -j ACCEPT	
        ip6tables -A FORWARD -m conntrack --ctstate NEW -s $PRIVATE_SUBNET_V6 -m policy --pol none --dir in -j ACCEPT	
        iptables -t nat -A POSTROUTING -s $PRIVATE_SUBNET_V4 -m policy --pol none --dir out -j MASQUERADE	
        ip6tables -t nat -A POSTROUTING -s $PRIVATE_SUBNET_V6 -m policy --pol none --dir out -j MASQUERADE	
        iptables -A INPUT -p udp --dport $SERVER_PORT -j ACCEPT
        ip6tables -A INPUT -p udp --dport $SERVER_PORT -j ACCEPT
	iptables -A INPUT -s 10.8.0.0/24 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
        iptables-save > /etc/iptables/rules.v4
    else
        iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT	
        ip6tables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT	
        iptables -A FORWARD -m conntrack --ctstate NEW -s $PRIVATE_SUBNET_V4 -m policy --pol none --dir in -j ACCEPT	
        ip6tables -A FORWARD -m conntrack --ctstate NEW -s $PRIVATE_SUBNET_V6 -m policy --pol none --dir in -j ACCEPT	
        iptables -t nat -A POSTROUTING -s $PRIVATE_SUBNET_V4 -m policy --pol none --dir out -j MASQUERADE	
        ip6tables -t nat -A POSTROUTING -s $PRIVATE_SUBNET_V6 -m policy --pol none --dir out -j MASQUERADE	
        iptables -A INPUT -p udp --dport $SERVER_PORT -j ACCEPT
        ip6tables -A INPUT -p udp --dport $SERVER_PORT -j ACCEPT
	iptables -A INPUT -s 10.8.0.0/24 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
        iptables-save > /etc/iptables/rules.v4	
    fi	

    systemctl enable wg-quick@wg0.service
    systemctl start wg-quick@wg0.service

    # TODO: unattended updates, apt install dnsmasq ntp
    echo "Client config --> $HOME/client-wg0.conf"
    echo "Now reboot the server and enjoy your fresh VPN installation! :^)"
else
    ### Server is installed, add a new client
    CLIENT_NAME="$1"
    if [ "$CLIENT_NAME" == "" ]; then
        echo "Tell me a name for the client config file. Use one word only, no special characters."
        read -p "Client name: " -e CLIENT_NAME
    fi
    CLIENT_PRIVKEY=$( wg genkey )
    CLIENT_PUBKEY=$( echo $CLIENT_PRIVKEY | wg pubkey )
    PRIVATE_SUBNET_V4=$( head -n1 $WG_CONFIG | awk '{print $2}')
    PRIVATE_SUBNET_MASK_V4=$( echo $PRIVATE_SUBNET_V4 | cut -d "/" -f 2 )
    PRIVATE_SUBNET_V6=$( head -n1 $WG_CONFIG | awk '{print $3}')
    PRIVATE_SUBNET_MASK_V6=$( echo $PRIVATE_SUBNET_V6 | cut -d "/" -f 2 )
    SERVER_ENDPOINT=$( head -n1 $WG_CONFIG | awk '{print $4}')
    SERVER_PUBKEY=$( head -n1 $WG_CONFIG | awk '{print $5}')
    MTU_CHOICE=$( head -n1 $WG_CONFIG | awk '{print $6}')
    NAT_CHOICE=$( head -n1 $WG_CONFIG | awk '{print $7}')
    LASTIP4=$( grep "/32" $WG_CONFIG | tail -n1 | awk '{print $3}' | cut -d "/" -f 1 | cut -d "." -f 4 )
    LASTIP6=$( grep "/128" $WG_CONFIG | tail -n1 | awk '{print $6}' | cut -d "/" -f 1 | cut -d "." -f 4 )
    CLIENT_ADDRESS_V4="${PRIVATE_SUBNET_V4::-4}$((LASTIP4+1))"
    CLIENT_ADDRESS_V6="${PRIVATE_SUBNET_V6::-4}$((LASTIP4+1))"
    echo "# $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = $CLIENT_ADDRESS_V4/32, $CLIENT_ADDRESS_V6/128" >> $WG_CONFIG

    echo "[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_ADDRESS_V4/$PRIVATE_SUBNET_MASK_V4, $CLIENT_ADDRESS_V6/$PRIVATE_SUBNET_MASK_V6
DNS = 10.8.0.1
MTU = $MTU_CHOICE
[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0, ::/0 
Endpoint = $SERVER_ENDPOINT
PersistentKeepalive = $NAT_CHOICE" > $HOME/$CLIENT_NAME-wg0.conf
qrencode -t ansiutf8 -l L < $HOME/$CLIENT_NAME-wg0.conf

    ip address | grep -q wg0 && wg set wg0 peer "$CLIENT_PUBKEY" allowed-ips "$CLIENT_ADDRESS_V4/32 , $CLIENT_ADDRESS_V6/64"
    echo "Client added, new configuration file --> $HOME/$CLIENT_NAME-wg0.conf"
fi
