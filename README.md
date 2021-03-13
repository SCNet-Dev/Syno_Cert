# SYNOLOGY CERTIFICAT MANAGER

### Fonctionnalités

Ce script permet les fonctionnalités suivantes :
* Récupération des chemins d'accès des fichiers des certificats
* Renouvellement des certificats
* Création de fichier Vhost pour NGinx.

### Pré-requis

Le script nécessite un accès root pour fonctionner.</br>
<b>Le support de l'ipv6 doit être désactivé dans l'interface réseau à cause d'un bug de Synology.</b></br>
Les certificats doivent avoir été créés via l'interface du DSM et avoir été émis par Lets Encrypt.

### Utilisation

```shell
# Afficher l'aide
$ ./syno_cert.sh --help

# Renouveler les certificats
$ ./syno_cert.sh --renew

# Retourner l'emplacement des fichiers du certificat <domaine>
$ ./syno_cert.sh --get <domaine>

# Créer un vhost nginx avec support éventuel de http, ssl, php et renouvellement certificat
$ ./syno_cert.sh --vhost
```

### Licence
  
```
The MIT License (MIT)

Copyright (c) 2018 SCNet

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
