# asterisk18-script
Script to install Asterisk 18 with Pjsip and WEBRTC on CentOS 7

This script :
- installs Asterisk 18 with WEBRTC enabled
- installs and configures Bind9 
- Installs and configures apache web server with ssl
- will change your SSH port from 22 to your desired port
- installs webphone from [@InnovateAsterisk/Browser-Phone](https://github.com/InnovateAsterisk/Browser-Phone)

******** Note1: Please replace yourdomain.com with your own domain.
******** Note2: Before you run this script your domain registrar account set your DNS to ns1.yourdomain.com and ns2.yourdomain.com and allow up to 24 hours for your domain DNS to propagate.
******** Note3: This script should be run with options.

-d yourdomain.com
-i your static IP address
-p your desired ssh port
-e your email address for lets encyprt
-t your server timezone


*****************************************************************************************
INSTALLTION:
*****************************************************************************************
1) Install a CentOS 7
2) confirgure your netwrok with static IP address
3) run the following commands:

sudo yum update -y
sudo yum install net-tools npm svn vim curl git telnet wget nano epel-release -y
sudo sed -i s/^SELINUX=.*$/SELINUX=disabled/ /etc/selinux/config
sudo hostnamectl set-hostname voip.yourdomain.com --static
sudo reboot

once your server is back, please download asterisk-webrtc.sh script and run it as follow:
wget 
chmod 777 asterisk-webrtc.sh
./asterisk-webrtc.sh -d example.com -i x.x.x.x -p 2449 -e email@email.com -t America/New_York

