#!/bin/bash

tiDIR="/opt/tiri.build/_TEST1"
tiBASE="$tiDIR/tpotce"
tiRELEASE="$PWD/honeypot.release"
tiFLAVOR="HP"   # tiri.SENSOR, INDUSTRIAL or FULL
tiPERSISTENCE="NO"
tiBUILDISO="YES"
tiBUILDcert="NO"
#
tiGITHUB="https://github.com/zerohat/tiri.pot.git"
#
tiCopytoXEN="NO"
tiXENhost="192.168.23.1"
tiXENpath="/var/run/sr-mount/5d6ebe8e-8909-4913-197e-f96b7854680d"
#
tiPOTHOSTNAME="tiriPOT-$(date +%m-%d)-$RANDOM"
#
tiKEYS="$PWD/tiri.vorlagen/authorized_keys"
tiNTP="$PWD/tiri.vorlagen/ntp.conf"
tiUBUNTUISO="$tiBASE/ubuntu-14.04.4-server-amd64.iso"
tiUBUNTULINK="http://releases.ubuntu.com/14.04.4/ubuntu-14.04.4-server-amd64.iso"
tiTMP="$tiBASE/tmp"
tiISSUEtpl="$PWD/tiri.vorlagen/issue.tpl"
tiISSUE="$PWD/tiri.vorlagen/issue"
tiPRESEED="$PWD/tiri.vorlagen/tiri_pot.seed"
tiRCLOCAL="$PWD/tiri.vorlagen/rc.local"
tiINSTALLERPATH="$tiBASE/installer/install.sh"
tiTPOTISO="tiri.pot_$(cat $tiRELEASE |cut -d' ' -f1).iso"
tiTPOTDIR="tpotiso"
tiOPENVPNconf="$PWD/tiri.vorlagen/openvpn"
tiFILEBEATconf="$PWD/tiri.vorlagen/filebeat"
tiOSSECconf="$PWD/tiri.vorlagen/ossec"
tiCERTliste="/usr/local/bin/tiri.hostliste"
tiCERTbin="/usr/local/bin/tiri.generate-certs.sh"


if [ "$tiDIR" == "CHANGE_ME" ]; then
  echo ""
  echo "SORRY, tiDIR Variable muss gesetzt werden!"
  echo ""
  exit 0
fi

echo "## fetch latest tiri.pot installer ###"
cd $PWD
git pull

echo "## Cleanup ##"
if [ -d "$tiBASE/$tiTPOTDIR" ]
  then
    rm -fr $tiBASE/$tiTPOTDIR
fi

if [ -f "$tiDIR/$tiTPOTISO" ]
  then
    rm -f $tiDIR/$tiTPOTISO
fi

if [ ! -d "$tiDIR" ]
 then
   mkdir -p $tiDIR
   cp $tiRELEASE $tiDIR/$tiRELEASE
fi


if [ -d "$tiBASE" ]
 then
  echo "## UPDATE vom T-POT GITHUB ##"
  cd $tiBASE
  git pull
 else
  cd $tiDIR
  git clone https://github.com/dtag-dev-sec/tpotce.git -b master
fi


### customization

cd $tiDIR
echo "## Anpassung Preseed - iPXE in Use - not needed! ##"
if [ -f "$tiBASE/preseed/tpot.seed" ]
  then
    cp $tiBASE/preseed/tpot.seed $tiBASE/preseed/tpot.seed.orig
  if [ -f "$tiPRESEED" ]
   then
    echo "kopiere tpot.seed"
    cp $tiPRESEED $tiBASE/preseed/tpot.seed
  fi
fi

echo "## Anpassung Kickstart ##"
if [ -f "$tiBASE/kickstart/ks.cfg" ]
 then
  sed -i "s/#keyboard .*$/keyboard de/" $tiBASE/kickstart/ks.cfg
  sed -i "s/^#timezone Europe.*$/timezone Europe\/Berlin/" $tiBASE/kickstart/ks.cfg
fi

echo "## Anpassung Isolinux ##"
if [ -f "$tiBASE/isolinux/txt.cfg" ]
 then
   sed -i "s/menu label .*$/menu label \^Install tiri.pot $(cat $tiRELEASE |cut -d',' -f1)/" $tiBASE/isolinux/txt.cfg
fi

echo "## Anpassungen tpot installer ##"
sed -i 's#^myFLAVOR=.*#myFLAVOR="'$tiFLAVOR'"#' $tiINSTALLERPATH

echo "## Anpassungen tpot images - wir brauchen alles ausser elkstack und elkpot"
if [ -f "$tiBASE/installer/data/imgcfg/hp_images.conf" ]
 then
  rm -f $tiBASE/installer/data/imgcfg/hp_images.conf 
fi

echo "conpot
emobility
suricata
cowrie
dionaea
glastopf
honeytrap" >>$tiBASE/installer/data/imgcfg/hp_images.conf


if [ -f "$tiRCLOCAL" ]; then
 echo "## Kopiere tiri rc.local ##"
 cp -p $tiRCLOCAL $tiBASE/installer/etc/
fi

if [ -d "$tiOPENVPNconf" ]; then
 if [ "$tiCERTbin" == "YES" ]; then
  echo "## Generiere Certs ##"
  echo $tiPOTHOSTNAME >$tiCERTliste
  $tiCERTbin 
 fi
  echo "## Kopiere tiri openvpn config ##"
  cp -pr $tiOPENVPNconf $tiBASE/installer/etc/
fi


echo "## Anpassungen tiri.pot hostname und ssh port ##"
egrep "tiriPOT" $tiBASE/$tiINSTALLERPATH 2>/dev/null
if [ $? -ne 0 ]
  then
    sed -i 's#^myHOST.*$#myHOST="'$tiPOTHOSTNAME'"#' $tiINSTALLERPATH
fi
sed -i 's#Port 64295#Port 65001#' $tiINSTALLERPATH
sed -i 's#64295#65001#' $tiINSTALLERPATH
##kein ELK wird installiert, also auch kein cronjob notwendig
echo "## ELK Cronjob entfernen, da kein ELK zum Einsatz kommt ##"
sed -i 's/27 4 .*$//' $tiINSTALLERPATH
sed -i 's/^myEXTIP.*$/myEXTIP=0.0.0.0/' $tiINSTALLERPATH

# tiri special
echo "## openvpn, ossec & logging  anpassungen ##"
sed -i '/^# Final .*$/i \
## tiri openvpn config \
fuECHO "### tiri.pot OpenVPN Setup ..." \
apt-get install openvpn -y \
cp -pr /root/tpot/etc/openvpn/* /etc/openvpn/ \
## tiri ossec config \
wget -qO - http://ossec.wazuh.com/repos/apt/conf/ossec-key.gpg.key | sudo apt-key add - \
echo "deb http://ossec.wazuh.com/repos/apt/ubuntu trusty main" > /etc/apt/sources.list.d/ossec.list \
apt-get update && apt-get -y ossec-hids-agent \
cp -pr /root/tpot/data/ossec/* /var/ossec/etc/ \
## tiri filebeat config \
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - \
echo "deb https://packages.elastic.co/beats/apt stable main"  > /etc/apt/sources.list.d/beats.list \
apt-get update && apt-get install -y filebeat \
cp -pr /root/tpot/data/filebeat/* /etc/filebeat/ \
### end of tiri special' $tiINSTALLERPATH



if [ "$tiPERSISTENCE" == "YES" ]
 then
   echo "## persistence der logdaten einschalten##"
   sed -i 's#^touch \/data\/persistence.off#touch \/data\/persistence.on#' $tiINSTALLERPATH
fi

echo "## sshd auf Port 65001 einschalten ##"
sed -i 's#echo "manual".*$##' $tiINSTALLERPATH


echo "## Adjust tiri issue ##"
if [ -f "$tiISSUEtpl" ]
 then
  cp $tiISSUEtpl $tiISSUE
  sed -i "s/##RELEASE##/$(cat $tiRELEASE |cut -d',' -f1)\"/" $tiISSUE
  sed -i "s/##RELEASE-DATE##/$(cat $tiRELEASE |cut -d',' -f2)\"/" $tiISSUE
  cp $tiISSUE $tiBASE/installer/etc/
fi

echo "## Add tiri.soc config templates ##"
cp $tiKEYS $tiBASE/installer/keys/authorized_keys
cp $tiNTP $tiBASE/installer/etc/ntp
cp -pr $tiFILEBEATconf $tiBASE/installer/data/
cp -pr $tiOSSECconf $tiBASE/installer/data/

echo "## Kein Logging zur DTAG sicherheitstacho.eu ##"
if [ -f "$tiDIR/tpotce/installer/data/ews/conf/ews.cfg" ]
  then
  sed -i "s/^send_malware = true/send_malware = false/" $tiDIR/tpotce/installer/data/ews/conf/ews.cfg
  sed -i "s/^ews = true/ews = false/" $tiDIR/tpotce/installer/data/ews/conf/ews.cfg
  sed -i "s/^contact = .*$/contact = tsoc@tiri.li/" $tiDIR/tpotce/installer/data/ews/conf/ews.cfg
  sed -i "s/^json = false/json = true/" $tiDIR/tpotce/installer/data/ews/conf/ews.cfg
  sed -i "s/community-.*$/tiri-pot-01/" $tiDIR/tpotce/installer/data/ews/conf/ews.cfg
fi


if [ "$tiBUILDISO" == "YES" ]
  then
echo "## Building tiri.honeypot.iso ##"
if [ ! -f $tiUBUNTUISO ]
  then
    echo "## Download $tiUBUNTUISO ##"
    cd $tiBASE
    wget $tiUBUNTULINK --progress=dot 2>&1
  else
    echo "## Verwende $tiUBUNTUISO ##"
fi

echo "## Mount Ubuntu iso ##"
cd $tiBASE && mkdir -p $tiTMP $tiTPOTDIR
losetup /dev/loop0 $tiUBUNTUISO
mount /dev/loop0 $tiTMP
cp -rT $tiTMP $tiTPOTDIR
chmod 777 -R $tiTPOTDIR
umount $tiTMP
losetup -d /dev/loop0

echo "## Add tiri files ##"
mkdir -p $tiTPOTDIR/tpot
cp installer/* -R $tiTPOTDIR/tpot/
cp isolinux/* $tiTPOTDIR/isolinux/
cp kickstart/* $tiTPOTDIR/tpot/
cp preseed/* $tiTPOTDIR/tpot/

if [ -d images ];
  then
    cp -R images $tiTPOTDIR/tpot/images/
fi
chmod 777 -R $tiTPOTDIR


# Let's create the new .iso
cd $tiTPOTDIR

mkisofs -gui -D -r -V "tiri.honeypot" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../$tiTPOTISO ../$tiTPOTDIR 2>/dev/null

cd ..
isohybrid $tiTPOTISO
mv $tiTPOTISO $tiDIR

echo ""
echo  "### ISO READY TO MOUNT! ####"
echo  "### $(ls -h $tiDIR/$tiTPOTISO) ####"
echo ""

fi

if [ $tiCopytoXEN == "YES" ]
  then
    echo  "### Copy New ISO to XEN-Host $tiXENhost ####"
    scp -p $tiDIR/$tiTPOTISO $tiXENhost:$tiXENpath/$tiTPOTISO
fi


echo ""
echo "#### READY TO LAUNCH.... ####"
if [ "$tiBUILDISO" != "YES" ]; then
 echo "#### ISO wurde nicht gebaut, da in der Config nicht auf YES eingestellt war! ####"
fi
ls -lah $tiBASE/
echo ""
echo ""

exit 0
