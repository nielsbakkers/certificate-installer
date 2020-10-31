#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
dirL=$DIR/dirCA
dir=dirCA
devide=$' \n'"---------------------------------------------------------------------"$'\n'

read -p $'Welke webserver wilt u installeren? Apache or Nginx\n' webserver 

while true
do
  case $webserver in
   [aA]* ) #echo "You chose Apache"
	   webserver=Apache
	   webinstall=apache2
	   echo "$devide"
	   break;;
   [nN]* ) #echo "You chose Nginx"
	   webserver=Nginx
	   webinstall=nginx 
	   echo "$devide"
           break;;

   * )     echo "Kies een juiste waarde"; exit ;;
  esac
done

read -p "Wilt u de machine updaten voor de installatie van $webserver"$' \n' update

while true
do
  case $update in
   [yY]* ) #echo "Oke de server wordt geupdate voordat de installatie begint"
	   update=yes
	   echo "$devide"
	   break;;
   [nN]* ) #echo "Oke de server wordt niet geupdate voordat de installatie begint"
           update=no
	   echo "$devide"
           break;;

   * )     echo "Kies een juiste waarde"; exit ;;
  esac
done

read -p "Voor welk domein moet het certificaat geinstalleerd worden? Voer de domeinnaam in:"$' \n' domainname

while true
do
  case $domainname in
   *.com | *.nl | *.nu | *.local | *.technology | *.localhost) #echo "juiste domainname"
	   echo "$devide"
           break;;
   * )     echo "Kies een juiste domainname"$' \n'; exit ;;
  esac
done

read -p "De volgende onderdelen worden gedaan:"$' \n'"$webserver wordt geinstalleerd"$' \n'"De server wordt $update geupdate"$' \n'"Er wordt een certificaat voor de domainame $domainname geinstalleerd"$' \n'"Gaat u hier mee akkoord?"$' \n' agree

while true
do
  case $agree in
   [yY]* ) #echo "You chose Yes"
	   agree=Yes
	   echo "$devide"
	   break;;
   [nN]* ) #echo "You chose No"
	   agree=No
	   echo "$devide"
           break;;

   * )     echo "Kies een juiste waarde"; exit ;;
  esac
done

if [ $update == "yes" ]
then 
	echo "update wordt uitgevoerd"
	sudo apt-get update
fi

sudo apt-get install $webinstall -y

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:65537 -out $DIR/cakey.pem

openssl req -new -x509 -key $DIR/cakey.pem -out $DIR/cacert.pem -days 1095 -subj "/C=NL/ST=Noord-brabant/L=Eindhoven/O=nbakkers/OU=nbakkers/CN=$domainname"

cd
mkdir "$dirL"
mkdir "$dirL/certs"
mkdir "$dirL/crl"
mkdir "$dirL/newcerts"
mkdir "$dirL/private"
touch "$dirL/index.txt"
echo 02 > "$dirL/serial"
mv "$DIR/cacert.pem" "$dirL/"
mv "$DIR/cakey.pem" "$dirL/private"

export domainname
export dirL
export dir

perl -p -i -e 's/countryName		= optional/countryName		= match/g' /usr/lib/ssl/openssl.cnf
perl -p -i -e 's/stateOrProvinceName	= match/stateOrProvinceName	= optional/g' /usr/lib/ssl/openssl.cnf
perl -p -i -e 's/organizationName	= match/organizationName	= optional/g' /usr/lib/ssl/openssl.cnf
perl -p -i -e 's/organizationalUnitName = match/organizationalUnitName  = optional/g' /usr/lib/ssl/openssl.cnf
perl -p -i -e 's/emailAddress           = match/emailAddress            = optional/g' /usr/lib/ssl/openssl.cnf
perl -p -i -e 's/RANDFILE/#RANDFILE/g' /usr/lib/ssl/openssl.cnf
perl -p -i -e 's/\.\/demoCA/$ENV{dirL}/g' /usr/lib/ssl/openssl.cnf

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:65537 -out $dirL/privkey-$domainname.pem
openssl req -new -key $dirL/privkey-$domainname.pem -out $dirL/certreq-$domainname.csr -subj "/C=NL/ST=Noord-brabant/L=Eindhoven/O=nbakkers/OU=nbakkers/CN=$domainname" -batch
openssl ca -batch -in $dirL/certreq-$domainname.csr -out $dirL/cert-$domainname.pem 

cp $dirL/cacert.pem $dirL/cert-ourca.crt
openssl verify -CAfile $dirL/cert-ourca.crt $dirL/cert-$domainname.pem

sudo cp $dirL/cert-$domainname.pem /etc/ssl/certs/
sudo cp $dirL/cert-ourca.crt /etc/ssl/certs/
sudo cp $dirL/privkey-$domainname.pem /etc/ssl/private/

sed -i "4i                ServerName \\${domainname}:443" "/etc/apache2/sites-available/default-ssl.conf"

perl -p -i -e 's/SSLCertificateFile      \/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/SSLCertificateFile    \/etc\/ssl\/certs\/cert-$ENV{domainname}.pem/g' /etc/apache2/sites-available/default-ssl.conf
perl -p -i -e 's/SSLCertificateKeyFile \/etc\/ssl\/private\/ssl-cert-snakeoil.key/SSLCertificateKeyFile \/etc\/ssl\/private\/privkey-$ENV{domainname}.pem/g' /etc/apache2/sites-available/default-ssl.conf

awk 'NR==34{$0="                SSLCACertificateFile /etc/ssl/certs/cert-ourca.crt"$0}1' /etc/apache2/sites-available/default-ssl.conf > $dirL/temp.conf
cp $dirL/temp.conf /etc/apache2/sites-available/default-ssl.conf
rm -R $dirL/temp.conf


sudo a2enmod ssl
sudo a2ensite default-ssl
sudo systemctl reload apache2















