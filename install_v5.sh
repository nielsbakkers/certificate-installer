#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
dirL=$DIR/dirCA
dir=dirCA
devide=$' \n'"---------------------------------------------------------------------"$'\n'
ip="$(hostname -I)"

read -p $'Welke webserver wilt u installeren? \n1) Apache \n2) Nginx\n' webserver 

while true
do
  case $webserver in
   a/A/Apache/apache/1 ) #echo "You chose Apache"
	   webserver=Apache
	   webinstall=apache2
	   echo "$devide"
	   break;;
   n/N/Nginx/nginx/2 ) #echo "You chose Nginx"
	   webserver=Nginx
	   webinstall=nginx 
	   echo "$devide"
           break;;

   * )     echo "Dit is geen geldige waarde! Start het programma opnieuw en voer een geldige waarde in."; exit ;;
  esac
done
echo "Wilt u de machine updaten voor de installatie van $webserver"
read -p $'1) Ja \n2) Nee \n' update
#read -p $'Wilt u de machine updaten voor de installatie van '"$webserver"' \n 1) Ja \n 2) Nee \n' update

while true
do
  case $update in
   y/Y/yes/Yes/1 ) 
	   update=yes
	   updatechoice=wel
	   echo "$devide"
	   break;;
   n/N/no/No/2 ) 
           update=no
	   updatechoice=niet
	   echo "$devide"
           break;;

   * )     echo "Dit is geen geldige waarde! Start het programma opnieuw en voer een geldige waarde in."; exit ;;
  esac
done

read -p $'Voor welk domein moet het ceritificaat geinstalleerd worden? \nBijvoorbeeld: example.com \nVoer de domeinnaam in: ' domainname

while true
do
  case $domainname in
   *.com | *.nl | *.nu | *.local | *.technology | *.localhost) #echo "juiste domainname"
	   echo "$devide"
           break;;
   * )     echo "Dit is geen geldige waarde! Start het programma opnieuw en voer een geldige waarde in."$' \n'; exit ;;
  esac
done

read -p "De volgende acties worden uitgevoerd:"$' \n\n'"1) $webserver wordt geinstalleerd"$' \n'"2) De server wordt $updatechoice geupdate"$' \n'"3) Er wordt een certificaat voor de domainame $domainname geinstalleerd"$' \n'"Gaat u hier mee akkoord? (y/n)"$' \n' agree

while true
do
  case $agree in
   y/Y/yes/Yes ) #echo "You chose Yes"
	   agree=Yes
	   echo "$devide"
	   break;;
   n/N/no/No ) #echo "You chose No"
	   agree=No
	   echo "$devide"
	   echo "Je ging niet akkoord met de acties die uitgevoerd werden. Start het programma opnieuw."
	   exit;;

   * )     echo "Dit is geen geldige waarde! Start het programma opnieuw en voer een geldige waarde in."; exit ;;
  esac
done

if [ $update == "yes" ]
then 
	echo "update wordt uitgevoerd"
	sudo apt-get update
fi

sudo apt-get install $webinstall -y

if [ $webserver == "Apache" ]
then
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

	perl -p -i -e 's/SSLCertificateFile	\/etc\/ssl\/certs\/ssl-cert-snakeoil.pem/SSLCertificateFile    \/etc\/ssl\/certs\/cert-$ENV{domainname}.pem/g' /etc/apache2/sites-available/default-ssl.conf
	perl -p -i -e 's/SSLCertificateKeyFile \/etc\/ssl\/private\/ssl-cert-snakeoil.key/SSLCertificateKeyFile \/etc\/ssl\/private\/privkey-$ENV{domainname}.pem/g' /etc/apache2/sites-available/default-ssl.conf

	awk 'NR==35{$0="                SSLCACertificateFile /etc/ssl/certs/cert-ourca.crt"$0}1' /etc/apache2/sites-available/default-ssl.conf > $dirL/temp.conf
	cp $dirL/temp.conf /etc/apache2/sites-available/default-ssl.conf
	rm -R $dirL/temp.conf

	sed -i "13i                Redirect '/' 'https://\\${ip}'" "/etc/apache2/sites-available/000-default.conf"

	sudo a2enmod ssl
	sudo a2ensite default-ssl
	sudo systemctl reload apache2
	sudo systemctl start apache2
fi

if [ $webserver == "Nginx" ]
then
	sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $domainname.key -out $domainname.crt -subj "/C=NL/ST=Noord-brabant/L=Eindhoven/O=nbakkers/OU=nbakkers/CN=$domainname"
	sudo cp $domainname.crt /etc/ssl/certs/$domainname.crt
	sudo cp $domainname.key /etc/ssl/private/$domainname.key
	
	perl -p -i -e 's/listen 80 default_server;/listen 80;/g' /etc/nginx/sites-available/default
	perl -p -i -e 's/listen \[\:\:\]\:80 default_server;/listen 443 ssl http2;/g' /etc/nginx/sites-available/default
	#sed -i "23i listen 443 ssl http2;" "/etc/nginx/sites-available/default"
	sed -i "24i server_name \\${domainname};" "/etc/nginx/sites-available/default"
	sed -i "25i ssl_certificate /etc/ssl/certs/\\${domainname}.crt;" "/etc/nginx/sites-available/default"
	sed -i "26i ssl_certificate_key /etc/ssl/private/\\${domainname}.key;" "/etc/nginx/sites-available/default"
	sed -i "27i ssl_protocols TLSv1.2 TLSv1.1 TLSv1;" "/etc/nginx/sites-available/default"
	
	sudo service nginx reload
	sudo service nginx start
fi
