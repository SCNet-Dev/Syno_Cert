#!/bin/bash

#Codes Couleurs
ROUGE='\033[0;31m'
CYAN='\033[0;36m'
BLANC='\033[0m'

error(){
	echo "ERREUR : paramètres invalides !" >&2
	echo "Utilisez l'option -help pour en savoir plus" >&2
	exit 1
}

usage(){
	echo "Usage: ./${0##*/} [options]"
	echo "	-h, --help		: afficher l'aide"
	echo "	-r, --renew		: renouvelez les certificats"
	echo "	-g, --get=<domaine>	: rétourne l'emplacement des fichiers du certificat <domaine>"
	echo "	-v, --vhost		: créer un vhost nginx type avec support ssl et renouvellement certificat"
}

_Ask(){
	#Récupère les réponses possibles et les convertis en un array associatif
	IFS=';' read -ra Array <<< "$3"
	declare -A Reponses
	for key in "${!Array[@]}"; do Reponses[${Array[$key]}]="$key"; done

	#Demande l'information et traite les réponses
	while [[ true ]]; do
		if [[ $5 != 1 ]]; then
			read -p "$2" Result
		else
			read -p "$2" -n 1 Result
		fi
		if [[ $4 != 1 ]]; then
			Result=${Result,,}
		fi
		if [[ -n "${Reponses[$Result]}" ]]; then
			eval "$1='$Result'"
			if [[ $5 = 1 ]]; then
				echo ""
			fi
			break
		else
			echo ""
			echo "Réponse incorrecte"
			echo ""
		fi
	done
}

renew(){
	#Affiche la date et l'heure d'exécution du script
	echo "========================================="
	echo "$(date)"

	#Affiche un résumé des dossier correspondant aux certif.
	cd /usr/syno/etc/certificate/_archive

	for i in *; do
		if test -d "$i"; then
			cert=`awk -F'"' 'NR==3 {print $4}' "./$i/renew.json"`
			echo "$i = $cert"
		fi
	done

	echo "-----------------------------------------"

	#Renouvelle tous les certifs.
	/usr/syno/sbin/syno-letsencrypt renew-all -v

	exit 0
}

getpath(){
	#Recherche le nom du dossier du certificat
	cert=`echo "$1" | sed "s/'//g"`

	cd /usr/syno/etc/certificate/_archive

	for i in *; do
		if test -d "$i"; then
			if [ `awk -F'"' 'NR==3 {print $4}' "./$i/renew.json"` = $cert ]; then
				echo "Les fichiers du certificat $1 sont :"
				echo "	/usr/syno/etc/certificate/_archive/$i/cert.pem"
				echo "	/usr/syno/etc/certificate/_archive/$i/chain.pem"
				echo "	/usr/syno/etc/certificate/_archive/$i/fullchain.pem"
				echo "	/usr/syno/etc/certificate/_archive/$i/privkey.pem"
				echo ""
				echo "Les paramètres pour le vhost NGinx du domaine $1 sont :"
				echo "	ssl on"
				echo "	ssl_certificate /usr/syno/etc/certificate/_archive/$i/fullchain.pem;"
				echo "	ssl_certificate_key /usr/syno/etc/certificate/_archive/$i/privkey.pem;"

				exit 0
			fi
		fi
	done

	echo "Aucun certificat pour le domaine $1"
	exit 1
}

vhost(){
	#Récupère les informations nécessaire pour le vhost
	echo ""
	echo -e "${CYAN}Création d'un vhost type${BLANC}"
	echo "------------------------"
	echo ""
	read -p "Emplacement de stockage : " -e -i /volume1/etc/vhost Path
	if [ -z "$Path" ]; then
		echo ""
		echo -e "${ROUGE}Erreur - Emplacement obligatoire${BLANC}"
		echo "--------------------------------"
		echo -e "${ROUGE}Arret du script${BLANC}"
		echo ""
		exit 1
	fi
	Path=${Path%/}
	echo ""
	read -p "Nom de domaine : " Domain
	if [ -z "$Domain" ]; then
		echo ""
		echo -e "${ROUGE}Erreur - Nom de domaine obligatoire${BLANC}"
		echo "-----------------------------------"
		echo -e "${ROUGE}Arret du script${BLANC}"
		echo ""
		exit 1
	fi
	echo ""
	read -p "Serveur cible : [l]ocal ou [d]istant ? " -e -i l Cible
	Cible=${Cible,,}
	if [ $Cible != "l" ] && [ $Cible != "d" ]; then
		echo ""
		echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
		echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} l"
		Cible=l
	fi
	echo ""
	if [ $Cible = "l" ]; then
		read -p "Autoriser l'accès en http ? [o/n] " -e -i n HttpAccess
		HttpAccess=${HttpAccess,,}
		if [ $HttpAccess != "o" ] && [ $HttpAccess != "n" ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} n"
			HttpAccess="n"
		elif [ $HttpAccess = "o" ]; then
			echo ""
			read -p "Port http à utiliser ? " -e -i 80 PortHttp
			if [ -z $PortHttp ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Numéro de port obligatoire${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 80"
				PortHttp=80
			fi
			echo ""
			read -p "Activer une redirection automatique vers SSL ? [o/n] " -e -i o RedirSSL
			RedirSSL=${RedirSSL,,}
			if [ $RedirSSL != "o" ] && [ $RedirSSL != "n" ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} o"
				RedirSSL="o"
			fi
		fi
		echo ""
		read -p "Port SSL a utiliser : " -e -i 443 PortSSL
		if [ -z $PortSSL ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Numéro de port obligatoire${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 443"
			PortSSL=443
		fi
		echo ""
		read -p "Emplacement du dossier web : " -e -i /volume1/web DossierWeb
		if [ -z "$DossierWeb" ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Dossier Web obligatoire${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} /volume1/web"
			DossierWeb="/volume1/web"
		fi
		DossierWeb=${DossierWeb%/}
		echo ""
		read -p "Activer Php ? [o/n] " -e -i n Php
		Php=${Php,,}
		if [ $Php != "o" ] && [ $Php != "n" ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} n"
			Php="n"
		elif [ "${Php,,}" = "o" ]; then
			echo ""
			read -p "Version de php [5/7] ? " -e -i 5 PhpVersion
			if [ "$PhpVersion" != 5 ] && [ "$PhpVersion" != 7 ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 5"
				PhpVersion=5
			fi
		fi
	else
		read -p "Autoriser l'accès en http ? [o/n] " -e -i n HttpAccess
		HttpAccess=${HttpAccess,,}
		if [ $HttpAccess != "o" ] && [ $HttpAccess != "n" ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} n"
			HttpAccess="n"
		elif [ $HttpAccess = "o" ]; then
			echo ""
			read -p "Port http à utiliser ? " -e -i 80 PortHttp
			if [ -z $PortHttp ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Numéro de port obligatoire${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 80"
				PortHttp=80
			fi
		fi
		echo ""
		read -p "Autoriser l'accès en SSL ? [o/n] " -e -i n SSLAccess
		SSLAccess=${SSLAccess,,}
		if [ $SSLAccess != "o" ] && [ $SSLAccess != "n" ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} n"
			SSLAccess="n"
		elif [ $SSLAccess = "o" ]; then
			echo ""
			read -p "Port SSL à utiliser ? " -e -i 443 PortSSL
			if [ -z $PortSSL ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Numéro de port obligatoire${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 443"
				PortSSL=443
			fi
		fi
		echo ""
		read -p "Adresse du serveur distant : " AdressCible
		if [ -z $AdressCible ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Adresse obligatoire${BLANC}"
			echo "----------------------------"
			echo -e "${ROUGE}Arret du script${BLANC}"
			echo ""
			exit 1
		fi
		if [ $HttpAccess = "o" ]; then
			echo ""
			read -p "Port http du serveur distant : " -e -i 80 PortHttpCible
			if [ -z $PortHttpCible ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 80"
				PortHttpCible=80
			fi
		fi
		if [ $SSLAccess = "o" ]; then
			echo ""
			read -p "Port SSL du serveur distant : " -e -i 443 PortSSLCible
			if [ -z $PortSSLCible ]; then
				echo ""
				echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
				echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} 443"
				PortSSLCible=80
			fi
		fi
	fi
	echo ""

	#On récupère le chemin du certificat (si serveur local)
	if [ $Cible = "l" ]; then
		cd /usr/syno/etc/certificate/_archive

		for i in *; do
			if test -d "$i"; then
				if [ `awk -F'"' 'NR==3 {print $4}' "./$i/renew.json"` = $Domain ]; then
					DossierCert=$i
					continue
				fi
			fi
		done
		if [ -z "$DossierCert" ]; then
			echo ""
			echo -e "${ROUGE}Erreur - Certificat inexistant${BLANC}"
			echo "------------------------------"
			echo -e "${ROUGE}Arret du script${BLANC}"
			echo ""
			exit 1
		fi
	fi

	#Verifie si un fichier existe déjà et si oui demande si on écrase
	if [ -f "$Path/$Domain" ]; then
		echo ""
		echo -e "${CYAN}Un VHost existe déjà pour ce domaine${BLANC}"
		echo "------------------------------------"
		read -p "Ecraser le VHost existant ? [o/n] " -e -i n Ecrase
		echo ""
		Ecrase=${Ecrase,,}
		if [ $Ecrase != "o" ] && [ $Ecrase != "n" ]; then
			echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} n"
			echo ""
			exit 1
		elif [ $Ecrase = "n" ]; then
			echo "Création du VHost annulée."
			echo ""
			exit 0
		fi
	fi

	#Créer le répertoire sible si il existe pas
	if [ ! -d "$Path" ]; then
		mkdir -p $Path
	fi

	#Ecriture du vhost
	#Serveur Http Port 80
	echo "server {" > "$Path/$Domain"
	echo "	listen 80;" >> "$Path/$Domain"
	echo "	listen [::]:80;" >> "$Path/$Domain"
	echo "" >> "$Path/$Domain"
	echo "	server_name $Domain;" >> "$Path/$Domain"
	echo "" >> "$Path/$Domain"
	if [ $Cible = "l" ]; then
		if [ $HttpAccess = "o" ] && [ $PortHttp = 80 ]; then
			if [ $RedirSSL = "o" ]; then
				echo "	return 302 https://$Domain:$PortSSL\$request_uri;" >> "$Path/$Domain"
			else
				echo "	root $DossierWeb;" >> "$Path/$Domain"
				if [ $Php = "o" ]; then
					echo "	index index.php index.php5 index.html index.htm;" >> "$Path/$Domain"
				else
					echo "	index index.html index.htm;" >> "$Path/$Domain"
				fi
				echo "	charset utf-8;" >> "$Path/$Domain"
				echo "" >> "$Path/$Domain"
				echo "	location / {" >> "$Path/$Domain"
				echo "		try_files \$uri \$uri/ =404;" >> "$Path/$Domain"
				echo "	}" >> "$Path/$Domain"
			fi
		else
			echo "	location / {" >> "$Path/$Domain"
			echo "		deny all;" >> "$Path/$Domain"
			echo "		return 444;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
		fi
		echo "" >> "$Path/$Domain"
		echo "	location ^~ /.well-known/acme-challenge {" >> "$Path/$Domain"
		echo "		root /var/lib/letsencrypt;" >> "$Path/$Domain"
		echo "		default_type text/plain;" >> "$Path/$Domain"
		echo "	}" >> "$Path/$Domain"
		if [ $Php = "o" ] && [ $HttpAccess = "o" ] && [ $PortHttp = 80 ]; then
			echo "" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "	########## GESTION DU PHP ##########" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location ~* \.php$ {" >> "$Path/$Domain"
			echo "		try_files \$uri =404;" >> "$Path/$Domain"
			if [ $PhpVersion = 5 ]; then
				echo "		fastcgi_pass unix:/run/php-fpm/php56-fpm.sock;" >> "$Path/$Domain"
			else
				echo "		fastcgi_pass unix:/run/php-fpm/php70-fpm.sock;" >> "$Path/$Domain"
			fi
			echo "		fastcgi_param HOST \"$Domain\";" >> "$Path/$Domain"
			echo "		include fastcgi.conf;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
		fi
	else
		if [ $HttpAccess = "o" ] && [ $PortHttp = 80 ]; then
			echo "	location / {" >> "$Path/$Domain"
			echo "		proxy_set_header   X-Real-IP \$remote_addr;" >> "$Path/$Domain"
			echo "		proxy_set_header   Host      \$host;" >> "$Path/$Domain"
			echo "		proxy_http_version 1.1;" >> "$Path/$Domain"
			echo "		proxy_set_header   Upgrade \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_set_header   Connection 'upgrade';" >> "$Path/$Domain"
			echo "		proxy_cache_bypass \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_pass         http://$AdressCible:$PortHttpCible;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location ^~ /.well-known/acme-challenge {" >> "$Path/$Domain"
			echo "		proxy_set_header   X-Real-IP \$remote_addr;" >> "$Path/$Domain"
			echo "		proxy_set_header   Host      \$host;" >> "$Path/$Domain"
			echo "		proxy_http_version 1.1;" >> "$Path/$Domain"
			echo "		proxy_set_header   Upgrade \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_set_header   Connection 'upgrade';" >> "$Path/$Domain"
			echo "		proxy_cache_bypass \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_pass         http://$AdressCible:80;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
		else
			echo "	location / {" >> "$Path/$Domain"
			echo "		deny all;" >> "$Path/$Domain"
			echo "		return 444;" >> "$Path/$Domain"
			echo "  }" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location ^~ /.well-known/acme-challenge {" >> "$Path/$Domain"
			echo "		proxy_set_header   X-Real-IP \$remote_addr;" >> "$Path/$Domain"
			echo "		proxy_set_header   Host      \$host;" >> "$Path/$Domain"
			echo "		proxy_http_version 1.1;" >> "$Path/$Domain"
			echo "		proxy_set_header   Upgrade \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_set_header   Connection 'upgrade';" >> "$Path/$Domain"
			echo "		proxy_cache_bypass \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_pass         http://$AdressCible:80;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
		fi
	fi
	echo "}" >> "$Path/$Domain"
	echo "" >> "$Path/$Domain"
	#Serveur Http Autre Port
	if [ $HttpAccess = "o" ] && [ $PortHttp != 80 ]; then
		echo "server {" >> "$Path/$Domain"
		echo "	listen $PortHttp;" >> "$Path/$Domain"
		echo "	listen [::]:$PortHttp;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	server_name $Domain;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		if [ $Cible = "l" ]; then
			if [ $RedirSSL = "o" ]; then
				echo "	return 302 https://$Domain:$PortSSL\$request_uri;" >> "$Path/$Domain"
			else
				echo "	root $DossierWeb;" >> "$Path/$Domain"
				if [ $Php = "o" ]; then
					echo "	index index.php index.php5 index.html index.htm;" >> "$Path/$Domain"
				else
					echo "	index index.html index.htm;" >> "$Path/$Domain"
				fi
				echo "	charset utf-8;" >> "$Path/$Domain"
				echo "" >> "$Path/$Domain"
				echo "	location / {" >> "$Path/$Domain"
				echo "		try_files \$uri \$uri/ =404;" >> "$Path/$Domain"
				echo "	}" >> "$Path/$Domain"
				echo "" >> "$Path/$Domain"
				if [ $Php = "o" ]; then
					echo "	####################################" >> "$Path/$Domain"
					echo "	########## GESTION DU PHP ##########" >> "$Path/$Domain"
					echo "	####################################" >> "$Path/$Domain"
					echo "" >> "$Path/$Domain"
					echo "	location ~* \.php$ {" >> "$Path/$Domain"
					echo "		try_files \$uri =404;" >> "$Path/$Domain"
					if [ $PhpVersion = 5 ]; then
						echo "		fastcgi_pass unix:/run/php-fpm/php56-fpm.sock;" >> "$Path/$Domain"
					else
						echo "		fastcgi_pass unix:/run/php-fpm/php70-fpm.sock;" >> "$Path/$Domain"
					fi
					echo "		fastcgi_param HOST \"$Domain\";" >> "$Path/$Domain"
					echo "		include fastcgi.conf;" >> "$Path/$Domain"
					echo "	}" >> "$Path/$Domain"
					echo "" >> "$Path/$Domain"
					echo "	####################################" >> "$Path/$Domain"
				fi
			fi
		else
			echo "	location / {" >> "$Path/$Domain"
			echo "		proxy_set_header   X-Real-IP \$remote_addr;" >> "$Path/$Domain"
			echo "		proxy_set_header   Host      \$host;" >> "$Path/$Domain"
			echo "		proxy_http_version 1.1;" >> "$Path/$Domain"
			echo "		proxy_set_header   Upgrade \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_set_header   Connection 'upgrade';" >> "$Path/$Domain"
			echo "		proxy_cache_bypass \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_pass         http://$AdressCible:$PortHttpCible;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
		fi
		echo "}" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
	fi
	#Serveur Https
	if [ $Cible = "l" ]; then
		echo "server {" >> "$Path/$Domain"
		echo "	listen $PortSSL ssl http2;" >> "$Path/$Domain"
		echo "	listen [::]:$PortSSL ssl http2;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	server_name $Domain;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	root $DossierWeb;" >> "$Path/$Domain"
		if [ $Php = "o" ]; then
			echo "	index index.php index.php5 index.html index.htm;" >> "$Path/$Domain"
		else
			echo "	index index.html index.htm;" >> "$Path/$Domain"
		fi
		echo "	charset utf-8;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	location / {" >> "$Path/$Domain"
		echo "		try_files \$uri \$uri/ =404;" >> "$Path/$Domain"
		echo "	}" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	####################################" >> "$Path/$Domain"
		echo "	########## CERTIFICAT SSL ##########" >> "$Path/$Domain"
		echo "	####################################" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	ssl on;" >> "$Path/$Domain"
		echo "	ssl_certificate /usr/syno/etc/certificate/_archive/$DossierCert/fullchain.pem;" >> "$Path/$Domain"
		echo "	ssl_certificate_key /usr/syno/etc/certificate/_archive/$DossierCert/privkey.pem;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	####################################" >> "$Path/$Domain"
		if [ $Php = "o" ]; then
			echo "" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "	########## GESTION DU PHP ##########" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location ~* \.php$ {" >> "$Path/$Domain"
			echo "		try_files \$uri =404;" >> "$Path/$Domain"
			if [ $PhpVersion = 5 ]; then
				echo "		fastcgi_pass unix:/run/php-fpm/php56-fpm.sock;" >> "$Path/$Domain"
			else
				echo "		fastcgi_pass unix:/run/php-fpm/php70-fpm.sock;" >> "$Path/$Domain"
			fi
			echo "		fastcgi_param HOST \"$Domain\";" >> "$Path/$Domain"
			echo "		include fastcgi.conf;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
		fi
		echo "}" >> "$Path/$Domain"
	else
		if [ $SSLAccess = "o" ]; then
			echo "server {" >> "$Path/$Domain"
			echo "	listen $PortSSL ssl http2;" >> "$Path/$Domain"
			echo "	listen [::]:$PortSSL ssl http2;" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	server_name $Domain;" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location / {" >> "$Path/$Domain"
			echo "		proxy_set_header   X-Real-IP \$remote_addr;" >> "$Path/$Domain"
			echo "		proxy_set_header   Host      \$host;" >> "$Path/$Domain"
			echo "		proxy_http_version 1.1;" >> "$Path/$Domain"
			echo "		proxy_set_header   Upgrade \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_set_header   Connection 'upgrade';" >> "$Path/$Domain"
			echo "		proxy_cache_bypass \$http_upgrade;" >> "$Path/$Domain"
			echo "		proxy_pass         https://$AdressCible:$PortSSLCible;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
			echo "}" >> "$Path/$Domain"
		fi
	fi

	#Change les droits du fichier
	chmod 644 "$Path/$Domain"
	chown $SUDO_USER:http "$Path/$Domain"

	#Creer le lien symbolique
	cd /etc/nginx/sites-enabled

	ln -s "$Path/$Domain"

	#Lance la vérification de la configuration et avertit l'utilisateur
	nginx -t

	echo ""
	echo "Fichier VHost créé. Vérifiez le résultat du test Nginx ci-dessus et tapez :"
	echo "	- \"nginx -s reload\" si le test est ok."
	echo "	- \"rm /etc/nginx/sites-enabled/$Domain\" si le test a échoué."
	echo ""
}

# Pas de paramètre
[[ $# -lt 1 ]] && error

# -o : options courtes
# -l : options longues
options=$(getopt -o h,r,g:,v -l help,renew,get:,vhost -- "$@")

# éclatement de $options en $1, $2...
set -- $options
while true; do
	case "$1" in
		-g|--get) getpath "$2"
			shift 2;;
		-r|--renew) renew
			shift;;
		-v|--vhost) vhost
			shift;;
		-h|--help) usage
			shift;;
		--) # fin des options
			shift
			break;;
		*) error
			shift;;
	esac
done
