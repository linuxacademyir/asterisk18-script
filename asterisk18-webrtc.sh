#!/bin/bash
set -e
# Get the options
while getopts d:i:p:e:t: option
do
    case "${option}" in
        d) ltd=${OPTARG};;
        i) ip=${OPTARG};;
        p) port=${OPTARG};;
        e) email=${OPTARG};;
        t) timezone=${OPTARG};;
       \?) echo "Error: Invalid option"
         exit;;
    esac
done
echo "Domain: $ltd";
echo "IP: $ip";
echo "Port: $port";
echo "Email: $email";
echo "TimeZone: $timezone";




echo "------------------------------------------------------------------------- Setting timezone"
timedatectl set-timezone ${timezone}

echo "------------------------------------------------------------------------- Configuring Bind9"
sudo yum install -y bind bind-utils
sudo sed "s|\{ 127.0.0.1; };|{ any; };|" -i /etc/named.conf
sudo sed "s|\listen-on port 53 { 127.0.0.1; };|listen-on port 53 { any; };|" -i /etc/named.conf
sudo sed "s|\allow-query     { localhost; };|allow-query     { any; };|" -i /etc/named.conf
sudo sed "s|\recursion yes;|recursion no;|" -i /etc/named.conf

cat > /var/named/${ltd}.db <<EOF
@    86400        IN      SOA     ns1.${ltd}. admin.${ltd}. (
                                2021071262 ; serial, todays date+todays
                                3600            ; refresh, seconds
                                7200            ; retry, seconds
                                1209600         ; expire, seconds
                                86400 )         ; minimum, seconds
;Name Server Recirds
@                       86400       IN      NS      ns1.${ltd}.
@                       86400       IN      NS      ns2.${ltd}.
;A Records
@                       86400       IN      A       ${ip}
voip.${ltd}.            86400       IN      A       ${ip}
voip                    86400       IN      A       ${ip}
ns1.${ltd}.             86400       IN      A       ${ip}
ns1                     86400       IN      A       ${ip}
ns2.${ltd}.             86400       IN      A       ${ip}
ns2                     86400       IN      A       ${ip}
www                     86400       IN      A       ${ip}
EOF

cat > /var/named/voip.${ltd}.db <<EOF
@    86400        IN      SOA     ns1.${ltd}. admin.${ltd}. (
                                2021071262 ; serial, todays date+todays
                                3600            ; refresh, seconds
                                7200            ; retry, seconds
                                1209600         ; expire, seconds
                                86400 )         ; minimum, seconds
;Name Server Recirds
@                       86400       IN      NS      ns1.${ltd}.
@                       86400       IN      NS      ns2.${ltd}.
;A Records
@                       86400       IN      A       ${ip}
voip.${ltd}.            86400       IN      A       ${ip}
voip                    86400       IN      A       ${ip}
ns1.${ltd}.             86400       IN      A       ${ip}
ns1                     86400       IN      A       ${ip}
ns2.${ltd}.             86400       IN      A       ${ip}
ns2                     86400       IN      A       ${ip}
EOF


cat >> /etc/named.conf <<EOF
zone "${ltd}" {type master; file "/var/named/${ltd}.db";};
zone "voip.${ltd}" {type master; file "/var/named/voip.${ltd}.db";};
EOF

sudo systemctl restart named

echo "**************************************************************************************"
echo "  BIND HAS BEEN CONFIGURED"
echo "**************************************************************************************"


echo "------------------------------------------------------------------------- Enabling SSH extra security"
sudo sed "s|\#PasswordAuthentication yes|PasswordAuthentication no|" -i /etc/ssh/sshd_config
sudo sed "s|\#Port 22|Port ${port}|" -i /etc/ssh/sshd_config

echo "**************************************************************************************"
echo "  SSH HAS BEEN SECURED"
echo "**************************************************************************************"

echo "------------------------------------------------------------------------- Installing Firewalld"
sudo yum install firewalld -y
sudo systemctl enable firewalld
sudo systemctl start firewalld

echo "------------------------------------------------------------------------- Opening Ports in Firewalld"
sudo firewall-cmd --zone=public --add-port=10000-20000/udp --permanent
sudo firewall-cmd --zone=public --add-port=10000-20000/tcp --permanent
sudo firewall-cmd --zone=public --add-port=5060/udp --permanent
sudo firewall-cmd --zone=public --add-port=5061/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8089/tcp --permanent
sudo firewall-cmd --zone=public --add-port=8088/tcp --permanent
sudo firewall-cmd --zone=public --add-port=5038/tcp --permanent
sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=53/tcp --permanent
sudo firewall-cmd --zone=public --add-port=53/udp --permanent
sudo firewall-cmd --zone=public --add-port=${port}/tcp --permanent
sudo firewall-cmd --reload

sudo systemctl restart sshd

echo "**************************************************************************************"
echo "  FIREWALL HAS BEEN INSTALLED AND CONFIGURED"
echo "**************************************************************************************"

echo "------------------------------------------------------------------------- Installing Asterisk"
cd /usr/src/
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18-current.tar.gz
sudo tar -zxvf asterisk-18-current.tar.gz
sudo rm -rf asterisk*.tar.gz
cd asterisk-18*
sudo ./contrib/scripts/get_mp3_source.sh
sudo contrib/scripts/install_prereq install
sudo ./configure --libdir=/usr/lib64 --with-jansson-bundled --with-pjproject-bundled
sudo make menuselect
sudo make && sudo make install 
sudo make samples && sudo make config


echo "------------------------------------------------------------------------- Creating Asterisk User Group"
sudo groupadd asterisk
sudo useradd -r -d /var/lib/asterisk -g asterisk asterisk
sudo usermod -aG audio,dialout asterisk
sudo chown asterisk. -R /etc/asterisk
sudo chown asterisk. -R /var/{lib,log,spool}/asterisk
sudo chown -R asterisk.asterisk /usr/lib64/asterisk
sudo sed "s|\#AST_USER="asterisk"|AST_USER="asterisk"|" -i /etc/sysconfig/asterisk
sudo sed "s|\#AST_GROUP="asterisk"|AST_GROUP="asterisk"|" -i /etc/sysconfig/asterisk
chkconfig asterisk on

echo "------------------------------------------------------------------------- Restarting Asterisk"
sudo systemctl restart asterisk

echo "------------------------------------------------------------------------- Asterisk Configuration"
sudo mv /etc/asterisk/http.conf /etc/asterisk/http.conf.bak
cat > /etc/asterisk/http.conf <<EOF
[general]
servername=Asterisk
tlsbindaddr=0.0.0.0:8089
bindaddr=0.0.0.0
bindport=8088
enabled=yes
tlsenable=yes
tlscertfile=/etc/letsencrypt/live/${ltd}/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/${ltd}/privkey.pem
EOF


sudo mv /etc/asterisk/pjsip.conf /etc/asterisk/pjsip.conf.bak
cat > /etc/asterisk/pjsip.conf <<EOF
[system]
type=system
timer_t1=500
timer_b=32000
disable_tcp_switch=yes

[global]
type=global
max_initial_qualify_time=0
keep_alive_interval=90
contact_expiration_check_interval=30
default_voicemail_extension=*97
unidentified_request_count=3
unidentified_request_period=5
unidentified_request_prune_interval=30
mwi_tps_queue_high=500
mwi_tps_queue_low=-1
mwi_disable_initial_unsolicited=yes
send_contact_status_on_update_registration=yes

[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0:8089
external_media_address=194.9.80.148
external_signaling_address=194.9.80.148
allow_reload=yes

[webrtc-phones](!)
context=main-context
transport=transport-wss
allow=!all,opus,ulaw,alaw,vp8,vp9
webrtc=yes

[100](webrtc-phones)
type=endpoint
callerid=100
auth=100
aors=100

[100]
type=aor
max_contacts=3

[100]
type=auth
auth_type=userpass
username=100
password=1234

[200](webrtc-phones)
type=endpoint
callerid=200
auth=200
aors=200

[200]
type=aor
max_contacts=3

[200]
type=auth
auth_type=userpass
username=200
password=1234
EOF

echo "------------------------------------------------------------------------- Adding PJSIP user"

sudo mv /etc/asterisk/extensions.conf /etc/asterisk/extensions.conf.bak

cat > /etc/asterisk/extensions.conf <<EOF
[general]
static=yes
writeprotect=yes
priorityjumping=no
autofallthrough=no

[globals]
ATTENDED_TRANSFER_COMPLETE_SOUND=beep

[main-context]
include => from-extensions
include => subscriptions
include => textmessages
include => echo-test
include => speak-exte-nnum

[echo-test]
exten => 777,1,NoOp(FEATURE: ECHO TEST)
 same => n,Answer
 same => n,Wait(1)
 same => n,Playback(demo-echotest)
 same => n,Echo()
 same => n,Playback(demo-echodone)
 same => n,Hangup()
;END of [echo-test]

[textmessages]
exten => 100,1,Gosub(send-text,s,1,(100))
exten => 200,1,Gosub(send-text,s,1,(200))

[subscriptions]
exten => 100,hint,PJSIP/100
exten => 200,hint,PJSIP/200

[from-extensions]
; Feature Codes:
exten => *65,1,Gosub(moh,s,1)
; Extensions
exten => 100,1,Gosub(dial-extension,s,1,(100))
exten => 200,1,Gosub(dial-extension,s,1,(200))

exten => e,1,Hangup()

[moh]
exten => s,1,NoOp(Music On Hold)
exten => s,n,Ringing()
exten => s,n,Wait(2)
exten => s,n,Answer()
exten => s,n,Wait(1)
exten => s,n,MusicOnHold()

EOF

sudo chown asterisk. /etc/asterisk/pjsip.conf
sudo chown asterisk. /etc/asterisk/extensions.conf
sudo chown asterisk. /etc/asterisk/http.conf

echo "**************************************************************************************"
echo "  ASTERISK HAS BEEN INSTALLED"
echo "**************************************************************************************"

echo "------------------------------------------------------------------------- Installing Apache"
sudo yum install httpd -y
sudo systemctl enable httpd
sudo systemctl start httpd

echo "------------------------------------------------------------------------- Configuring Apache"
sudo mkdir -p /var/www/html/${ltd}/{public_html,logs}
sudo touch  /var/www/html/${ltd}/logs/error.log
sudo touch /var/www/html/${ltd}/logs/access.log

cat > /etc/httpd/conf.d/${ltd}.conf <<EOF
NameVirtualHost *:80
<VirtualHost *:80>
       ServerAdmin webmaster@${ltd}
       ServerName ${ltd}
       ServerAlias ${ltd}

       DocumentRoot /var/www/html/${ltd}/public_html/
       ErrorLog /var/www/html/${ltd}/logs/error.log
       CustomLog /var/www/html/${ltd}/logs/access.log combined
</VirtualHost>
EOF

sudo systemctl restart httpd

echo "**************************************************************************************"
echo "  APACHE HAS BEEN INSTALLED AND CONFIGURED"
echo "**************************************************************************************"

echo "------------------------------------------------------------------------- Creating SSL certificates"
sudo yum install certbot python2-certbot-apache mod_ssl -y
certbot --apache  --noninteractive --agree-tos  -d ${ltd} -m ${email} 

sudo mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.bak
sudo mv /etc/httpd/conf.d/welcome.conf /etc/httpd/conf.d/welcome.conf.bak
sudo mv /etc/httpd/conf.d/${ltd}.conf /etc/httpd/conf.d/${ltd}.conf.bak

echo "------------------------------------------------------------------------- adding to CronTab"

sudo crontab -l > cron_bkp
sudo echo "45 3 * * 6 /usr/local/letsencrypt/certbot-auto renew" >> cron_bkp
sudo crontab cron_bkp
sudo rm cron_bkp

echo "**************************************************************************************"
echo "  SSL HAS BEEN INSTALLED AND CONFIGURED"
echo "**************************************************************************************"



echo "------------------------------------------------------------------------- Webphone Installtion"
git clone https://github.com/InnovateAsterisk/Browser-Phone.git /var/www/html/${ltd}/public_html/Phone
sudo mv /var/www/html/${ltd}/public_html/Phone/Phone/* /var/www/html/${ltd}/public_html/
sudo chown -R apache:apache /var/www/*

sudo systemctl restart httpd
sudo systemctl restart asterisk

echo "***********************************************************************************************"
echo "  INSTALLATION DONE"
echo "  Please Visit your website and try to configure your phone with following username and password"
echo "  User:100 Pass:1234 | User:200 Pass:1234 |"
echo "***********************************************************************************************"

