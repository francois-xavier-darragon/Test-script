#!/bin/bash

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour obtenir les branches mergées, triées par date du dernier commit
get_sorted_merged_branches() {
    git for-each-ref --sort=committerdate refs/remotes/origin/ --format='%(refname:short)' |
    grep -v "origin/develop" | grep -v "origin/main" |
    while read branch; do
        if git merge-base --is-ancestor $branch develop; then
            echo "$branch"
        fi
    done | sed 's/origin\///'
}

# Fonction pour afficher les branches mergées
display_merged_branches() {
    echo -e "${YELLOW}Branches distantes mergées dans develop (de la plus ancienne à la plus récente) :${NC}"
    for branch in $merged_branches; do
        last_commit_date=$(git log -1 --format=%cd --date=short origin/$branch)
        echo "$last_commit_date - $branch"
    done
    echo
}

# Fonction pour archiver une branche avec un tag
archive_branch() {
    branch_name=$1
    
    echo -e "${YELLOW}Archivage de la branche : $branch_name${NC}"
    
    git fetch origin $branch_name
    if git tag "archive/$branch_name" origin/$branch_name; then
        echo -e "${GREEN}Tag 'archive/$branch_name' créé pour la branche '$branch_name'.${NC}"
    else
        echo -e "${RED}Erreur lors de la création du tag pour '$branch_name'.${NC}"
        return 1
    fi
}

# Fonction pour supprimer une branche distante
delete_remote_branch() {
    branch_name=$1
    
    echo -e "${YELLOW}Suppression de la branche distante : $branch_name${NC}"
    
    if git push origin --delete $branch_name; then
        echo -e "${GREEN}La branche distante '$branch_name' a été supprimée.${NC}"
    else
        echo -e "${RED}Erreur lors de la suppression de la branche distante '$branch_name'.${NC}"
        return 1
    fi
}

# Fonction principale
main() {
    git fetch --all --prune
    
    if ! git checkout develop; then
        echo -e "${RED}Erreur : Impossible de basculer sur la branche develop.${NC}"
        exit 1
    fi
    git pull origin develop
    
    merged_branches=$(get_sorted_merged_branches)
    
    if [ -z "$merged_branches" ]; then
        echo -e "${YELLOW}Aucune branche mergée dans develop n'a été trouvée.${NC}"
        exit 0
    fi
    
    display_merged_branches
    
    read -p "Voulez-vous archiver ces branches ? (o/n) " confirm_archive
    if [[ $confirm_archive != [oO] ]]; then
        echo -e "${YELLOW}Opération annulée.${NC}"
        exit 0
    fi
    
    for branch in $merged_branches; do
        if [ ! -z "$branch" ]; then
            archive_branch $branch
        fi
    done
    
    if git push origin --tags; then
        echo -e "${GREEN}Les tags d'archive ont été poussés vers le dépôt distant.${NC}"
    else
        echo -e "${RED}Erreur lors de la poussée des tags vers le dépôt distant.${NC}"
    fi
    
    read -p "Voulez-vous supprimer ces branches distantes ? (o/n) " confirm_delete
    if [[ $confirm_delete != [oO] ]]; then
        echo -e "${YELLOW}Les branches n'ont pas été supprimées. Opération terminée.${NC}"
        exit 0
    fi
    
    for branch in $merged_branches; do
        if [ ! -z "$branch" ]; then
            delete_remote_branch $branch
        fi
    done
    
    echo -e "${GREEN}Opération terminée. Les branches mergées dans develop ont été archivées et supprimées si demandé.${NC}"
}

# Exécuter le script
main