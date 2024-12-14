#!/bin/bash

# Afficher les disques disponibles
clear
echo "Disques disponibles :"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E 'disk|part'

# Demander à l'utilisateur de choisir un disque à monter
read -p "Entrez le nom du disque (ex: sdb ou sdb1) : " disk

# Construire le chemin complet du périphérique
selected_disk="/dev/$disk"

# Vérifier si le disque sélectionné existe
if ! lsblk | grep -q "$disk"; then
    echo "Erreur : le disque sélectionné n'existe pas."
    exit 1
fi

# Lancer fdisk pour partitionner le disque
read -p "Voulez-vous partitionner ce disque avec fdisk ? (o/n) : " partition_choice
if [[ "$partition_choice" == "o" || "$partition_choice" == "O" ]]; then
    echo "Lancement de fdisk pour $selected_disk. Veuillez suivre les instructions pour créer une nouvelle partition."
    sudo fdisk "$selected_disk"
fi

# Demander le format de fichier pour le disque
read -p "Sous quel format souhaitez-vous formater le disque ? (ex: ext4) : " filesystem
if [[ -z "$filesystem" ]]; then
    echo "Erreur : aucun format spécifié."
    exit 1
fi

# Formater la partition (supposons que la première partition est utilisée, exemple : /dev/sdb1)
partition="${selected_disk}1"
echo "Formatage de $partition en $filesystem..."
sudo mkfs -t "$filesystem" "$partition"

# Demander si un dossier doit être créé dans /mnt
read -p "Souhaitez-vous créer un dossier dans /mnt pour monter le disque ? (o/n) : " create_folder
if [[ "$create_folder" == "o" || "$create_folder" == "O" ]]; then
    read -p "Entrez le nom du dossier à créer dans /mnt (ex: mydisk) : " folder_name
    mount_point="/mnt/$folder_name"
    if [[ ! -d "$mount_point" ]]; then
        echo "Création du dossier $mount_point..."
        sudo mkdir -p "$mount_point"
    fi
else
    read -p "Entrez le chemin complet d'un dossier existant pour monter le disque : " mount_point
    if [[ ! -d "$mount_point" ]]; then
        echo "Erreur : le dossier $mount_point n'existe pas."
        exit 1
    fi
fi

# Monter le disque
sudo mount "$partition" "$mount_point"
echo "Le disque a été monté sur $mount_point."

# Afficher l'état du montage
lsblk -o NAME,MOUNTPOINT | grep "$disk"

# Récupérer l'UUID de la partition
UUID=$(blkid -s UUID -o value "$partition")
if [[ -z "$UUID" ]]; then
    echo "Erreur : impossible de récupérer l'UUID du disque."
    exit 1
fi

# Demander à l'utilisateur s'il veut rendre le montage permanent
read -p "Voulez-vous rendre ce montage permanent (o/n) : " choice
if [[ "$choice" == "o" || "$choice" == "O" ]]; then
    entry="UUID=$UUID $mount_point $filesystem defaults 0 2"
    if ! grep -q "$entry" /etc/fstab; then
        echo "$entry" | sudo tee -a /etc/fstab > /dev/null
        echo "Entrée ajoutée à /etc/fstab : $entry"
    else
        echo "Une entrée similaire existe déjà dans /etc/fstab."
    fi
    echo "Montage permanent configuré avec succès."
else
    echo "D'accord, le disque ne sera pas monté de façon permanente."
fi
