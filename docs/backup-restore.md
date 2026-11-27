# Backup et restore

## État actuel

- `make etcd-backup` fait un snapshot etcd manuel dans `backups/` (gitignored).
- Il n'y a **pas** de backup automatisé CNPG, Longhorn ou NFS.
- La clé age n'a pas de copie offline documentée.

C'est le risque principal du cluster : les données d'Immich, Securo, Hermes et
les configurations des apps vivent sur des PVC ou des exports NFS.

## Inventaire des données

| Donnée | Emplacement | Criticité |
|---|---|---|
| Photos Immich | NFS `/mnt/data/photos` | Critique |
| DB Immich | PVC CNPG `immich-db` (Longhorn) | Critique |
| DB Securo | PVC CNPG `securo-db` (Longhorn) | Critique |
| Configs *arr/Plex/Tautulli/Mixarr/Qui/Autobrr | PVC Longhorn | Moyenne |
| Données Hermes | PVC Longhorn `hermes-data` | Élevée (tokens OAuth) |
| Manifests/secrets | Git + SOPS | Critique |
| Clé age | `.config/age.agekey` + state Terraform | Critique |
| etcd | control plane | Critique |

## Cible recommandée

### CNPG

Ajouter un `barmanObjectStore` vers un endpoint S3/MinIO (TrueNAS) pour
`immich-db` et `securo-db`, avec :

- `ScheduledBackup` quotidien,
- rétention définie,
- test de restore dans un namespace scratch.

### Longhorn

- Configurer un `defaultBackupStore` (NFS ou S3 sur TrueNAS).
- Ajouter un `RecurringJob` pour les PVC de configuration.
- Vérifier le `reclaimPolicy: Retain`.

### etcd

- Snapshot automatisé (cron sur la machine d'admin ou workflow planifié).
- Chiffrement du snapshot avant stockage.
- Copie hors cluster.
- Documenter la procédure de restore Talos.

### NFS / TrueNAS

- Snapshots ZFS périodiques pour `/mnt/data/photos` et `/mnt/data/media`.
- Réplication vers un second pool/disque si disponible.
- Vérifier la restauration d'un fichier et d'un dataset.

### Clé age

- Copie offline dans un gestionnaire de mots de passe.
- Ne pas dépendre uniquement de `.config/age.agekey` et du state Terraform.

## Procédures à tester

1. Restore d'un fichier depuis un snapshot TrueNAS.
2. Restore d'une base CNPG dans un namespace scratch.
3. Restore d'un PVC Longhorn.
4. Restore etcd sur un cluster de test (ou procédure Talos documentée).
5. Redémarrage d'ArgoCD et vérification que les secrets SOPS se déchiffrent.

## RPO / RTO

À définir avec l'usage réel :

- RPO acceptable pour les photos : 24 h ? 1 h ?
- RPO pour Securo : 24 h ? moins ?
- RTO : combien de temps acceptable pour reconstruire le cluster ?

Tant que ces valeurs ne sont pas définies, les backups ne peuvent pas être
dimensionnés correctement.

## Commandes actuelles

```bash
# snapshot etcd manuel avant un upgrade
make etcd-backup

# vérifier un secret SOPS
make secret-keys FILE=argocd/base/securo/secrets/securo-secret.yaml
```

## Règles

- Ne jamais commiter `backups/`, `*.snapshot` ou un state Terraform.
- Ne jamais tester une restauration sur les données de prod.
- Un backup non testé n'est pas un backup.
