# [AE353] Commvault error management



## Prérequis et dépendances

Le package python xlrd doit etre présent dans le venv/EE.
Le fichier a traité doit etre déposé sur le Tower.

## Usage

Variables d'entrées:
- mailstd_smtpTo: liste de mails (comma separated) qui recevront le rapport d'execution.
- vCommvaultFile: nom du fichier xls à lire (pour incident NETWORKER envoyé à ITO_ISIM2_EXPL-N1)
- vSipsirFile: nom du fichier xls à lire (pour incident SIPSIR envoyé à ITO_ISIM2_SUPERVISION)