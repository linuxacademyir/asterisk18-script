# asterisk18-script
Script to install Asterisk 18 with Pjsip and WEBRTC on CentOS 7

This script :
- installs Asterisk 18 with WEBRTC enabled
- installs and configures Bind9 
- Installs and configures apache web server with ssl
- will change your SSH port from 22 to your desired port
- will enable and configure firewall
- will create 2 sip users 100 and 200
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

wget https://github.com/mehdizeus/asterisk18-script/blob/main/asterisk18-webrtc.sh
chmod 777 asterisk18-webrtc.sh
bash -e asterisk18-webrtc.sh -d example.com -i x.x.x.x -p 2449 -e email@email.com -t America/New_York



during the installtion you will see a prompt like below picture. navigate to "Codec Translators" on the left menu and select coded_opus
asterisk18-webrtc.png![image](https://user-images.githubusercontent.com/58116075/170533514-0da43650-1a32-439e-bde6-0bb1ffdd386e.png)

you can also navigate to "Extra sound package" on the left side and select your prefered sound packages

one the installtion is finished:
vim /etc/asterisk/extensions.conf 

and insert these lines at the end of the file
[speak-exte-nnum]
exten => 888,1,NoOp(FEATURE: SPEAK MY EXTENSION NUMBER)
 same => n,Answer
 same => n,Wait(1)
 same => n,Playback(extension)
 same => n,Wait(1)
 same => n,SayDigits(${CALLERID(num)})
 same => n,Wait(2)
 same => n,Hangup()
;END of [speak-exte-nnum]


[dial-extension]
exten => s,1,NoOp(Calling: ${ARG1})
exten => s,n,Set(JITTERBUFFER(adaptive)=default)
exten => s,n,Dial(PJSIP/${ARG1},30)
exten => s,n,Hangup()

exten => e,1,Hangup()

[send-text]
exten => s,1,NoOp(Sending Text To: ${ARG1})
exten => s,n,Set(PEER=${CUT(CUT(CUT(MESSAGE(from),@,1),<,2),:,2)})
exten => s,n,Set(FROM=${SHELL(asterisk -rx ‘pjsip show endpoint ${PEER}’ | grep ‘callerid ‘ | cut -d’:’ -f2- | sed ‘s/^ *//’ | tr -d ‘‘)})
exten => s,n,Set(CALLERID_NUM=${CUT(CUT(FROM,>,1),<,2)})
exten => s,n,Set(FROM_SIP=${STRREPLACE(MESSAGE(from),
exten => s,n,MessageSend(pjsip:${ARG1},${FROM_SIP})
exten => s,n,Hangup()


then in terminal type
asterisk -rx "reload"


now navigate to yourdomain.com and start configuring webphone
go to webphone settings > account :
Asterisk server Address: yourdomain.com
Websocket Port: 8089
Websocket Path: /ws
Subscribe Extension: 100
Full Name: 100
SIP username: 100
SIP password: 1234
and hit Save

ENJOY!!!
