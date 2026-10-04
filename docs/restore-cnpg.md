# Restaurer une base CloudNativePG

Sauvegardes via le plugin barman-cloud vers Silo (`192.168.1.7:9000`),
un bucket par base : `cnpg-securo`, `cnpg-immich`. Exemples avec securo,
remplacer `securo` par `immich` au besoin.

## Verifier l'etat des sauvegardes

```bash
kubectl get scheduledbackups,backups -n securo
kubectl get objectstore securo-s3 -n securo -o yaml   # status: firstRecoverabilityPoint
```

## Test de restauration (a faire une fois, puis apres chaque gros changement)

Restaure dans un cluster temporaire, a cote de la base de production, sans la
toucher. Pas de bloc `plugins` : le cluster de test n'archive rien et ne pollue
donc pas le bucket.

```bash
kubectl apply -f - <<'YAML'
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: securo-db-restore
  namespace: securo
spec:
  instances: 1
  imageName: tensorchord/cloudnative-vectorchord:17
  storage:
    size: 10Gi
    storageClass: longhorn
  bootstrap:
    recovery:
      source: origin
      # Optionnel, restauration a un instant precis :
      # recoveryTarget:
      #   targetTime: "2026-10-04 14:30:00+02"
  externalClusters:
    - name: origin
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: securo-s3
          serverName: securo-db
YAML

kubectl get cluster securo-db-restore -n securo -w        # attendre "healthy"
kubectl cnpg psql securo-db-restore -n securo -- securo -c '\dt+'
kubectl cnpg psql securo-db -n securo -- securo -c '\dt+'  # comparer
kubectl delete cluster securo-db-restore -n securo
```

## Restauration reelle (base perdue ou corrompue)

1. Suspendre l'auto-sync de l'Application (`securo` a une derogation prevue).
2. Supprimer le cluster casse : `kubectl delete cluster securo-db -n securo`
   (ArgoCD ne le fera pas, `Prune=false`).
3. Dans `cluster.yaml`, remplacer `bootstrap.initdb` par le bloc
   `bootstrap.recovery` + `externalClusters` ci-dessus, et ajouter
   `serverName: securo-db-r1` dans `plugins[].parameters` : le nouveau cluster
   ne peut pas archiver dans le dossier de l'ancien.
4. PR, merge, sync. Une fois la base saine, le bloc `bootstrap` n'est plus lu :
   il peut rester tel quel.
