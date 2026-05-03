#!/bin/bash

# Activer le mode strict pour éviter les erreurs dramatiques
set -euo pipefail

# 1. Détection dynamique de l'utilisateur
# Si lancé avec sudo, on prend l'utilisateur d'origine. Sinon, l'utilisateur courant.
USER_TARGET="${SUDO_USER:-$USER}"

# 2. Récupération dynamique du répertoire personnel et du groupe
HOME_DIR=$(getent passwd "$USER_TARGET" | cut -d: -f6)
USER_GROUP=$(id -gn "$USER_TARGET")

# Vérification de l'existence du répertoire de l'utilisateur
if [ ! -d "$HOME_DIR" ]; then
    echo "Erreur : Le répertoire $HOME_DIR n'existe pas."
    exit 1
fi

# Liste exhaustive des dossiers standards (Français et Anglais)
ALLOWED_DIRS=(
    "Bureau" "Desktop"
    "Téléchargements" "Downloads"
    "Documents"
    "Musique" "Music"
    "Images" "Pictures"
    "Public"
    "Modèles" "Templates"
    "Vidéos" "Videos"
)

echo "Démarrage du nettoyage pour l'utilisateur $USER_TARGET dans $HOME_DIR..."

# Parcourir uniquement les éléments visibles (non cachés) à la racine du Home.
for item in "$HOME_DIR"/*; do
    # Sécurité si le dossier est totalement vide (évite de traiter la string littérale "*")
    [ -e "$item" ] || continue

    BASENAME=$(basename "$item")
    IS_ALLOWED=0

    # Vérifier si l'élément fait partie de la liste ET si c'est bien un répertoire
    for allowed in "${ALLOWED_DIRS[@]}"; do
        if [ "$BASENAME" == "$allowed" ] && [ -d "$item" ]; then
            IS_ALLOWED=1
            break
        fi
    done

    if [ $IS_ALLOWED -eq 1 ]; then
        echo "Vidage du dossier standard : $BASENAME"
        find "$item" -mindepth 1 -delete
    else
        echo "Suppression de l'élément non standard : $BASENAME"
        rm -rf "$item"
    fi
done

# Réparer les permissions dynamiquement avec le bon utilisateur et son groupe principal
chown -R "$USER_TARGET":"$USER_GROUP" "$HOME_DIR"

echo "Nettoyage terminé avec succès."

# -----------------------------------------------------------------------------
# INSTALLATION ET PRÉPARATION DE L'ENVIRONNEMENT
# -----------------------------------------------------------------------------
echo "Mise à jour et installation des paquets prérequis..."
sudo apt-get update
sudo apt-get install -y git build-essential dkms linux-headers-$(uname -r)
sudo modprobe vboxdrv

# Se placer explicitement dans le dossier de l'utilisateur ciblé
cd "$HOME_DIR"

# Cloner le dépôt en tant que l'utilisateur (pour éviter que les fichiers appartiennent à root)
echo "Clonage du dépôt k8s-install..."
sudo -u "$USER_TARGET" git clone https://github.com/wizetraining/k8s-install.git

cd k8s-install

# Lancement du script d'installation
echo "Lancement de install.sh..."
./install.sh