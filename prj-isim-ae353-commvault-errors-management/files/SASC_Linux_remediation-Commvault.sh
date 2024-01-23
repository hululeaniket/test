#!/bin/ksh

########################################################################################################################
# Script: SASC_Linux_remediation-Commvault.ksh
#
# Description: Ce script permet de tenter une remediation suite a une erreur Commvault
# Version: 1.0.0 (ou 1: modification majeure, 2: modification mineure, 3: correction de bug)
#
# Date de creation: 13/05/2019
# Cree par: Jean-Baptiste Meriaux
#
#
# Mise a jour:
#                           Prenom Nom - DD/MM/YYY - Description de la modification
#
# Pre-requis:                           Le serveur est de type Unix
#
# Inputs:
#
# Outputs:
#                           0 : le script s'est correctement deroule
#                                                       1 : Remediation impossible, transfert au groupe N1
#                                                       98: OS incompatible avec le script
#
########################################################################################################################

############
# CONSTANTE
############

COMPLIANT=NO


############
# FONCTIONS
############

SetPercentage ()
{
        PURCENT_USE=$(df -mP $1 2>/dev/null |grep $1 |awk '{print $5}' |cut -d"%" -f1)
}

GetProcess ()
{
        ps aux | grep $1 | grep -v "grep"
        if [ $? -eq 0 ]
        then
                PROCESS=$(ps aux | grep -v "grep" | grep $1)
        else
                PROCESS=""
        fi
}

KillProcess ()
{
        GetProcess $1
        if [ ! -z $PROCESS ]
                then
                        echo "Tentative de suppression normale de $PROCESS"
                        PID=$(echo $PROCESS | awk '{print $2}')
                        kill -15 $PID

                        GetProcess $1
                        if [ ! -z $PROCESS ]
                        then
                                echo "Tentative de suppression forcee de $PROCESS"
                                PID=$(echo $PROCESS | awk '{print $2}')
                                kill -9 $PID
                        fi
        fi
}

#############
# MAIN
#############

OS=$(uname)

case $OS in
        "Linux")

                # Recuperation des variables de version RH
                if [ -f /etc/system-release ]
                then
                        RHE=`cat /etc/redhat-release | awk '{print $7}'` # Exemple de sortie 6.6
                        REL=`echo ${RHE} | awk -F\. '{print $1}'` # Exemple de sortie 6

                else
                        RHE=`cat /etc/redhat-release | awk '{print $7}'`
                        REL=`echo ${RHE} | awk -F\. '{print $1}'`
                fi

                # Verification de la signatures
                echo "Verifcation de la signature..."
                if [ ! -f /etc/conf_machine/signatures/svr_commvault-client* ]
                then
                        echo "La signature du package n'est pas presente, veuillez verifier l'installation du produit" && exit 1
                else
                        echo -e "\t OK"
                fi

                echo "Verification des dossiers d'installation Commvault..."
                echo "/commvault_install/..."
                df -h /commvault_install/ > /dev/null 2>&1
                if [ ! $? -eq 0 ]
                then
                        echo -e "\t KO" && exit 1
                else
                        echo -e "\t OK"
                fi
                echo "/logiciels/commvault/..."
                df -h /logiciels/commvault/ > /dev/null 2>&1
                if [ ! $? -eq 0 ]
                then
                        echo -e "\t KO" && exit 1
                else
                        echo -e "\t OK"
                fi

                echo "Verifcation du package VMware Tools..."
                if [ ${REL} -eq 7 ]
                then
                        rpm -qa | grep open-vm-tools > /dev/null 2>&1
                else
                        rpm -qa | grep vmware > /dev/null 2>&1
                fi
                if [ ! $? -eq 0 ]; then
                                echo "Le package Vmware Tools nest pas installe"
                                >&2 && exit 1
                else
                        echo -e "\t OK"
                fi


                echo "Verification du statut des Vmware Tools..."
                if [ ${REL} -eq 7 ]
                then
                    systemctl status vmtoolsd.service | grep running  > /dev/null 2>&1
                    if [ ! $? -eq 0 ]; then
                                    echo "Le package Vmware Tools n'est pas demarre."
                                    >&2 && exit 1
                                                                        systemctl start vmtoolsd.service
                                                                        if [ $? -eq 0 ]
                                                                        then
                                                                                echo "Demarrage des VMware Tools : OK"
                                                                                echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                                                COMPLIANT="YES"
                                                                        fi
                    else
                            echo -e "\t OK"

                    fi
                else
                        /etc/vmware-tools/services.sh status | grep running  > /dev/null 2>&1
                        if [ ! $? -eq 0 ]; then
                                echo "Le package Vmware Tools n'est pas demarre." >&2 && exit 1
                                                                /etc/vmware-tools/services.sh status
                                                                if [ $? -eq 0 ]
                                                                then
                                                                        echo "Demarrage des VMware Tools : OK"
                                                                        echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                                        COMPLIANT="YES"
                                                                fi
                        else
                                echo -e "\t OK"
                        fi
                fi

                echo "Verification des processus Commvault..."
                simpana list | grep 'N/A' >/dev/null
                if [ $? = 0 ]
                then
                        echo -e "\t KO"
                        echo "Demarrage de Commvault..."
                        simpana start
                        simpana list | grep 'N/A' >/dev/null
                        if [ $? != 0 ]
                        then
                                echo "Agent demarre et OK"
                                                                echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                                COMPLIANT="YES"
                        else
                            echo "Demarrage KO... Tentative de relance en supprimant les processus existant..."
                            ps aux | grep 'commvault/Base' | grep -v 'grep --color=auto'
                            if [ $? != 0 ]
                            then
                                    KillProcess commvault/Base/cvlaunchd
                                    KillProcess commvault/Base/cvd
                                    KillProcess commvault/Base/ClMgrS
                                    KillProcess commvault/Base/cvfwd

                                    simpana start
                                    simpana list | grep 'N/A' >/dev/null
                                    if [ $? = 0 ]
                                    then
                                            echo "Impossible de redemarrer l'agent commvault malgre la supression manuelle des process" && >&2 && exit 1
                                    else
                                            echo "Supprimer les process a permis a l'agent de redemarrer."
                                                                                        echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                                                        COMPLIANT="YES"
                                    fi
                            else
                                    if [ -f /tmp/.lock_Galaxy ]
                                    then
                                            rm -f /tmp/.lock_Galaxy
                                            simpana start
                                            simpana list | grep 'N/A' >/dev/null
                                            if [ $? = 0 ]
                                            then
                                                    echo "Impossible de redemarrer l'agent commvault malgre la suppression du fichier /tmp/.lock_Galaxy" && >&2 && exit 1
                                            else
                                                    echo "Suppimer le fichier /tmp/.lock_Galaxy a permis a l'agent de redemarrer."
                                                                                                        echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                                                                        COMPLIANT="YES"
                                            fi
                                    else
                                            echo "Impossible de redemarrer l'agent commvault" && >&2 && exit 1
                                    fi
                            fi
                        fi
                                else
                    echo -e "\t OK"
                fi

                # Verification du rattachement a un commcell
                echo "Verification du rattachament a un commcell..."
                simpana list | head -2 | tail -1 | grep , >/dev/null
                if [ $? != 0 ]
                then
                        echo "Le serveur n'est pas rattache a une commcell." && >&2 && exit 1
                else
                        echo -e "\t OK"
                        Commcell=$(simpana list | head -2 | tail -1 | awk '{print $4}')
                fi

                                # Verification de la bonne commuicatin avec le commcell
                                echo "Verification de la communication avec le commcell"
                                SITE=$(echo ${Commcell} | cut -c 1)
                if [ $SITE = "n" ]
                                then
                                        Commcell=$Commcell".noe.edf.fr"
                                else
                                        Commcell=$Commcell".pcy.edf.fr"
                                fi
                                ping -c 4 $Commcell >/dev/null
                if [ $? = 0 ]
                then
                                        echo -e "\t OK"
                                else
                                        echo "Commcell $Commcell non joignable." && >&2 && exit 1
                                fi

                                # Verification de FS Full

                                # purge /tmp/
                                FS="/tmp"
                                echo "Verification du seuil de $FS..."
                Seuil=98
                SetPercentage $FS
                if [ "$PURCENT_USE" -ge $Seuil ]; then
                        find /tmp -xdev -type f -name core -mtime +5 -exec rm {} \;
                        find /tmp -xdev -type f -name '*.tar' -mtime +1 -exec gzip -9 {} \;
                        find /tmp -xdev -type f \( -name '*.zip' -o -name '*.gz' -o -name '*.iso' \) -mtime +7 -exec rm {} \;
                        find /tmp -xdev -type f -name '*.initrd.cgz' -mtime +1 -exec rm {} \;
                        find /tmp -xdev -name '*rear*' -mtime +1 -exec rm -rf {} \;
                        find /tmp -xdev -type f \( -name 'svr_*.ksh' -o -name 'svr_*.sh' -o -name '*.rpm' \) -mtime +2 -exec rm {} \;
                                                echo "\t Tentative de purge effectuee"
                                                SetPercentage $FS
                                                if [ "$PURCENT_USE" -ge $Seuil ]; then
                                                        echo -e "\t L'occupation du FS $FS est toujourssuperieur au seuil de $Seuil %." && >&2 && exit 1
                                                else
                                                        echo -e "\t L'occupation du FS $FS est maintenant OK"
                                                        echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                        COMPLIANT="YES"
                                                fi
                                else
                                        echo -e "\t OK"
                fi



                #purge /logiciels/commvault
                                FS="/logiciels/commvault"
                                echo "Verification du seuil de $FS..."
                Seuil=86
                SetPercentage $FS
                if [ "$PURCENT_USE" -ge $Seuil ]; then
                        rm -rf /logiciels/commvault/svr_commvault-client.*_linux_el5-el6-el7_n1-n3_1.2/linux-x8664/LooseUpdates/Updates/*
                        echo -e "\t Tentative de purge effectuee"
                                                SetPercentage $FS
                                                if [ "$PURCENT_USE" -ge $Seuil ]; then
                                                        echo -e "\t L'occupation du FS $FS est superieur au seuil de $Seuil %." && >&2 && exit 1
                                                else
                                                        echo -e "\t L'occupation du FS $FS est maintenant OK"
                                                        echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                        COMPLIANT="YES"
                                                fi
                else
                                        echo -e "\t OK"
                fi


                #purge /logiciels/commvault
                                FS="/commvault_install"
                                echo "Verification du seuil de $FS..."
                FREE_SPACE=$(df -m /commvault_install/|tail -1 |awk '{print $4}')
                Seuil="1024"
                if [ $FREE_SPACE -le $Seuil ]
                                then
                        rm -rf /commvault_install/commvault/Updates/*
                                                echo -e "\t Tentative de purge effectuee"
                                                SetPercentage $FS
                                                if [ "$PURCENT_USE" -ge $Seuil ]; then
                                                                echo "L'occupation du FS $FS est superieur au seuil de $Seuil %." && >&2 && exit 1
                                                else
                                                                        echo -e "\t L'occupation du FS $FS est maintenant OK"
                                                                        echo "Vous pouvez verifier de nouveau la sauvegarde"
                                                                        COMPLIANT="YES"
                                                fi
                else
                                        echo -e "\t OK"
                fi

                                if [ $COMPLIANT = "YES" ]
                                then
                                        echo "Une remediation a ete effectue. Vous pouvez relancer la sauvegarde"
                                        exit 0
                                else
                                        echo "Toutes les procedures connues ont ete testee et sont OK."
                                        echo "Vous devez faire une verification manuelle avant de relancer la sauvegarde"
                                        exit 1
                                fi

                ;;

        *)      echo "OS_INCOMPATIBLE_AVEC_CE_SCRIPT"
                exit 98
                ;;
esac

>&2 && exit 0
