#!/bin/bash
# ===============================================================================================================================
# Nom ...........: Syno_Cert
# DEscription ...: Créé des fichiers vhosts pour synology. Permet aussi de récupérer le chemin d'accès des certificats et de les
#                  renouveller automatiquement.
# Version .......: v1.0
# Author ........: SCNet
# ===============================================================================================================================

#Codes Couleurs
ROUGE='\033[0;31m'
CYAN='\033[0;36m'
BLANC='\033[0m'

# FONCTION ======================================================================================================================
# Nom .............: _Error
# Description .....: Affiche le message d'erreur de paramètres invalides
# Syntaxe .........: _Error
# Valeur de retour.: Aucune
# ===============================================================================================================================
_Error(){
	echo "ERREUR : paramètres invalides !" >&2
	echo "Utilisez l'option --help pour en savoir plus" >&2
	exit 1
}	#==> _Error

# FONCTION ======================================================================================================================
# Nom .............: _Help
# Description .....: Affiche l'aide sur les commandes
# Syntaxe .........: _Help
# Valeur de retour.: Aucune
# ===============================================================================================================================
_Help(){
	echo "Usage : ./${0##*/} [options]"
	echo "	-h, --help		: affiche l'aide"
	echo "	-r, --renew		: renouvelle les certificats"
	echo "	-g, --get=<domaine>	: retourne l'emplacement des fichiers du certificat <domaine>"
	echo "	-v, --vhost		: créé un vhost nginx type avec support ssl et renouvellement certificat"
} #==> _Help

# FONCTION ======================================================================================================================
# Nom .............: _Ask
# Description .....: Demande une information à l'utilisateur
# Syntaxe .........: _Ask $Reponse_Var $Demande $Reponses [$Casse] [$Impultionnel] [$Optionnel] [$Defaut]
# Paramètres ......: $Reponse_Var					- Nom de la variable dans laquelle retourner la réponse.
#										 $Demande             - Question à afficher.
#                    $Reponses            - Différentes réponses possibles séparés par ";". Mettre ".*" pour autoriser toutes les réponses.
#										 $Casse								- [optionnel] 1 = Respecter la casse, 0 = Ne pas tenir compte de la casse (par défaut).
#                    $Impultionnel        - [optionnel] 1 = Pas de validation par touche entrée, 0 = Validation par touche entrée (par défaut).
#																						Possible uniquement si réponse de 1 caractère.
#										 $Optionnel						- [optionnel] 1 = Réponse vide autorisée, 0 = Réponse vide interdite (par défaut).
#										 $Defaut							- [optionnel] Réponse proposée par défaut (uniquement si pas Impultionnel)
# Valeur de retour.: Réponse de l'utilisateur
# Exemple .........: _Ask Resultat "Etes-vous sûr ? [o/n]" "o|n" 0 1
# ===============================================================================================================================
_Ask(){
	#Récupère les réponses possibles et les convertis en un array associatif
	IFS=';' read -ra Array <<< "$3"
	declare -A Reponses
	for key in "${!Array[@]}"; do Reponses[${Array[$key]}]="$key"; done

	#Demande l'information et traite les réponses
	while [[ true ]]; do
		if [[ $5 != 1 ]]; then
			if [[ ! -z $7 ]]; then
				read -p "$2" -e -i "$7" Result
			else
				read -p "$2" Result
			fi
		else
			read -p "$2" -n 1 Result
		fi
		if [[ $4 != 1 ]]; then
			Result=${Result,,}
		fi
		if [[ ! -z $Result ]] || [[ $6 = 1 ]]; then
			if [[ -n "${Reponses[$Result]}" ]] || [[ -n "${Reponses[".*"]}" ]]; then
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
		else
			echo ""
			echo "Réponse incorrecte"
			echo ""
		fi
	done
}	#==> _Ask

# FONCTION ======================================================================================================================
# Nom .............: _Renew
# Description .....: Lance le renouvellement des certificats.
# Syntaxe .........: _Renew
# Valeur de retour.: Aucune
# ===============================================================================================================================
_Renew(){
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

	#Relance le service Web
	synoservicecfg --restart pkgctl-WebStation

	exit 0
}	#==> _Renew

# FONCTION ======================================================================================================================
# Nom .............: _GetPath
# Description .....: Retourne le chemin d'accès des fichiers du certificat
# Syntaxe .........: _GetPath $Domaine
# Paramètres ......: $Domaine							- Nom du domaine pour lequel récupérer les chemins des fichiers du certificat.
# Valeur de retour.: Aucune
# Exemple .........: _GetPath "mondomaine.fr"
# ===============================================================================================================================
_Getpath(){
	#Recherche le nom du dossier du certificat
	cert=`echo "$1" | sed "s/'//g"`

	cd /usr/syno/etc/certificate/_archive

	for i in *; do
		if test -d "$i"; then
			if [[ `awk -F'"' 'NR==3 {print $4}' "./$i/renew.json"` = $cert ]]; then
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
}	#==> _Getpath

# FONCTION ======================================================================================================================
# Nom .............: _Vhost
# Description .....: Créer un fichier vhost suivant les besoins de l'utilisateur
# Syntaxe .........: _Vhost
# Valeur de retour.: Aucune
# ===============================================================================================================================
_Vhost(){
	#Récupère les informations nécessaire pour le vhost
	echo ""
	echo -e "${CYAN}Création d'un vhost type${BLANC}"
	echo "------------------------"
	echo ""
	_Ask 'Path' 'Emplacement de stockage : ' '.*' 0 0 0 '/volume1/'
	Path=${Path%/}
	echo ""
	_Ask 'Domain' 'Nom de domaine : ' '.*'
	echo ""
	_Ask 'Cible' 'Serveur cible : [l]ocal ou [d]istant ? ' 'l;d' 0 1
	echo ""
	if [[ $Cible = "l" ]]; then
		_Ask 'HttpAccess' "Autoriser l'accès en http ? [o/n] " 'o;n' 0 1
		if [[ $HttpAccess = "o" ]]; then
			echo ""
			_Ask 'PortHttp' 'Port http à utiliser ? ' '.*'
			echo ""
			_Ask 'RedirSSL' 'Activer une redirection automatique vers SSL ? [o/n] ' 'o;n' 0 1
		fi
		echo ""
		_Ask 'PortSSL' 'Port SSL a utiliser : ' '.*'
		echo ""
		_Ask 'DossierWeb' 'Emplacement du dossier web : ' '.*' 0 0 0 '/volume1/web'
		DossierWeb=${DossierWeb%/}
		echo ""
		_Ask 'Php' 'Activer Php ? [o/n] ' 'o;n' 0 1
		if [[ $Php = "o" ]]; then
			echo ""
			_Ask 'PhpVersion' 'Version de Php ? [5/7] ' '5;7' 0 1
		fi
	else
		_Ask 'HttpAccess' "Autoriser l'accès en http ? [o/n] " 'o;n' 0 1
		if [[ $HttpAccess = "o" ]]; then
			echo ""
			_Ask 'PortHttp' 'Port http à utiliser ? ' '.*'
			echo ""
			_Ask 'RedirSSL' 'Activer une redirection automatique vers SSL ? [o/n] ' 'o;n' 0 1
		fi
		if [[ $RedirSSL != "o" ]]; then
			echo ""
			_Ask 'SSLAccess' "Autoriser l'accès en SSL ? [o/n] " 'o;n' 0 1
		fi
		if [[ $SSLAccess = "o" ]] || [[ $RedirSSL = "o" ]]; then
			echo ""
			_Ask 'Certif' "Permettre également la création et le renouvellement d'un certificat par le serveur distant (pour un accès type DSM) ? [o/n] " 'o;n' 0 1
			echo ""
			_Ask 'PortSSL' 'Port SSL a utiliser : ' '.*'
		fi
		echo ""
		_Ask 'AdressCible' 'Adresse du serveur distant : ' '.*'
		if [[ $HttpAccess = "o" ]]; then
			echo ""
			_Ask 'PortCible' 'Port http du serveur distant : ' '.*'
		fi
	fi
	echo ""

	#On récupère le chemin du certificat (si serveur local ou distant avec SSL)
	if [[ $Cible = "d" ]]; then
		if [[ $RedirSSL = "o" ]] || [[ $SSLAccess = "o" ]]; then
			CertLocal="o"
		fi
	fi
	if [[ $Cible = "l" ]] || [[ $CertLocal = "o" ]]; then
		cd /usr/syno/etc/certificate/_archive

		for i in *; do
			if test -d "$i"; then
				if [[ `awk -F'"' 'NR==3 {print $4}' "./$i/renew.json"` = $Domain ]]; then
					DossierCert=$i
					continue
				fi
			fi
		done
		if [[ -z "$DossierCert" ]]; then
			echo ""
			echo -e "${ROUGE}Erreur - Certificat inexistant${BLANC}"
			echo "------------------------------"
			echo -e "${ROUGE}Arrêt du script${BLANC}"
			echo ""
			exit 1
		fi
	fi

	#Verifie si un fichier existe déjà et si oui demande si on écrase
	if [[ -f "$Path/$Domain" ]]; then
		echo ""
		echo -e "${CYAN}Un VHost existe déjà pour ce domaine${BLANC}"
		echo "------------------------------------"
		read -p "Ecraser le VHost existant ? [o/n] " -e -i n Ecrase
		echo ""
		Ecrase=${Ecrase,,}
		if [[ $Ecrase != "o" ]] && [[ $Ecrase != "n" ]]; then
			echo -e "${ROUGE}Erreur - Réponse incorrecte${BLANC}"
			echo -e "${ROUGE}Utilisation de la valeur par défaut :${BLANC} n"
			echo ""
			exit 1
		elif [[ $Ecrase = "n" ]]; then
			echo "Création du VHost annulée."
			echo ""
			exit 0
		fi
	fi

	#Créer le répertoire sible si il existe pas
	if [[ ! -d "$Path" ]]; then
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
	if [[ $Cible = "l" ]]; then
		if [[ $HttpAccess = "o" ]] && [[ $PortHttp = 80 ]]; then
			if [[ $RedirSSL = "o" ]]; then
				echo "	return 302 https://$Domain:$PortSSL\$request_uri;" >> "$Path/$Domain"
			else
				echo "	root $DossierWeb;" >> "$Path/$Domain"
				if [[ $Php = "o" ]]; then
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
		if [[ $Php = "o" ]] && [[ $HttpAccess = "o" ]] && [[ $PortHttp = 80 ]]; then
			echo "" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "	########## GESTION DU PHP ##########" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location ~* \.php$ {" >> "$Path/$Domain"
			echo "		try_files \$uri =404;" >> "$Path/$Domain"
			if [[ $PhpVersion = 5 ]]; then
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
		if [[ $HttpAccess = "o" ]] && [[ $PortHttp = 80 ]]; then
			if [[ $RedirSSL = "o" ]]; then
				echo "	return 302 https://$Domain:$PortSSL\$request_uri;" >> "$Path/$Domain"
			else
				echo "	location / {" >> "$Path/$Domain"
				echo "		proxy_set_header   X-Real-IP \$remote_addr;" >> "$Path/$Domain"
				echo "		proxy_set_header   Host      \$host;" >> "$Path/$Domain"
				echo "		proxy_http_version 1.1;" >> "$Path/$Domain"
				echo "		proxy_set_header   Upgrade \$http_upgrade;" >> "$Path/$Domain"
				echo "		proxy_set_header   Connection 'upgrade';" >> "$Path/$Domain"
				echo "		proxy_cache_bypass \$http_upgrade;" >> "$Path/$Domain"
				echo "		proxy_pass         http://$AdressCible:$PortCible;" >> "$Path/$Domain"
				echo "	}" >> "$Path/$Domain"
			fi
			if [[ $Certif = "o" ]]; then
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
		else
			echo "	location / {" >> "$Path/$Domain"
			echo "		deny all;" >> "$Path/$Domain"
			echo "		return 444;" >> "$Path/$Domain"
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
		fi
	fi
	echo "}" >> "$Path/$Domain"
	echo "" >> "$Path/$Domain"
	#Serveur Http Autre Port
	if [[ $HttpAccess = "o" ]] && [[ $PortHttp != 80 ]]; then
		echo "server {" >> "$Path/$Domain"
		echo "	listen $PortHttp;" >> "$Path/$Domain"
		echo "	listen [::]:$PortHttp;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	server_name $Domain;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		if [[ $Cible = "l" ]]; then
			if [[ $RedirSSL = "o" ]]; then
				echo "	return 302 https://$Domain:$PortSSL\$request_uri;" >> "$Path/$Domain"
			else
				echo "	root $DossierWeb;" >> "$Path/$Domain"
				if [[ $Php = "o" ]]; then
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
				if [[ $Php = "o" ]]; then
					echo "	####################################" >> "$Path/$Domain"
					echo "	########## GESTION DU PHP ##########" >> "$Path/$Domain"
					echo "	####################################" >> "$Path/$Domain"
					echo "" >> "$Path/$Domain"
					echo "	location ~* \.php$ {" >> "$Path/$Domain"
					echo "		try_files \$uri =404;" >> "$Path/$Domain"
					if [[ $PhpVersion = 5 ]]; then
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
			echo "		proxy_pass         http://$AdressCible:$PortCible;" >> "$Path/$Domain"
			echo "	}" >> "$Path/$Domain"
		fi
		echo "}" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
	fi
	#Serveur Https
	if [[ $Cible = "l" ]]; then
		echo "server {" >> "$Path/$Domain"
		echo "	listen $PortSSL ssl http2;" >> "$Path/$Domain"
		echo "	listen [::]:$PortSSL ssl http2;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	server_name $Domain;" >> "$Path/$Domain"
		echo "" >> "$Path/$Domain"
		echo "	root $DossierWeb;" >> "$Path/$Domain"
		if [[ $Php = "o" ]]; then
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
		if [[ $Php = "o" ]]; then
			echo "" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "	########## GESTION DU PHP ##########" >> "$Path/$Domain"
			echo "	####################################" >> "$Path/$Domain"
			echo "" >> "$Path/$Domain"
			echo "	location ~* \.php$ {" >> "$Path/$Domain"
			echo "		try_files \$uri =404;" >> "$Path/$Domain"
			if [[ $PhpVersion = 5 ]]; then
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
		if [[ $SSLAccess = "o" ]] || [[ $RedirSSL = "o" ]]; then
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
			echo "		proxy_pass         http://$AdressCible:$PortCible;" >> "$Path/$Domain"
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
}	#==> _Vhost

# PROGRAMME PRINCIPAL ===========================================================================================================
# ===============================================================================================================================

# Pas de paramètre
[[ $# -lt 1 ]] && _Error

# -o : options courtes
# -l : options longues
options=$(getopt -o h,r,g:,v -l help,renew,get:,vhost -- "$@")

# éclatement de $options en $1, $2...
set -- $options
while true; do
	case "$1" in
		-g|--get)
			_Getpath "$2"
			shift 2;;
		-r|--renew)
			_Renew
			shift;;
		-v|--vhost)
			_Vhost
			shift;;
		-h|--help)
			_Help
			shift;;
		--) # fin des options
			shift
			break;;
		*)
			_Error
			shift;;
	esac
done
