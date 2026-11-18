# jira-gh-automation-test

Repo **de test** pour l'automatisation des statuts Jira (projet **SCRAP**, site `ourabahsalim.atlassian.net`) déclenchée par GitHub Actions.

> ⚠️ Ce repo sert uniquement à valider le mécanisme. Il ne remplace pas `voteer` et ne doit pas être utilisé en production. Une fois validé ici, les mêmes fichiers seront transposés sur `voteer`.

## Architecture

Pas de règle Jira Automation ni d'application « GitHub for Jira » : les workflows appellent directement l'API REST Jira v3 (transition + commentaire) avec un token API stocké dans les secrets GitHub. Les jobs de déploiement utilisent `environment:` (dev / staging / prod), ce qui les rendra aussi compatibles avec un mode « GitHub for Jira + règles Automation » plus tard si besoin.

## Conventions de branches

La clé Jira complète est **obligatoire** dans le nom de branche :

- `Sprint/Fix/SCRAP-18-nom-court`
- `feature/SCRAP-18-nom-court`

## Mapping testé (statuts du projet SCRAP)

| Événement GitHub | Action Jira automatique |
|---|---|
| Push d'une branche (hors `main`) contenant une clé Jira | Transition → **En cours** + commentaire |
| PR ouverte (clé dans le titre ou la branche) | Commentaire |
| PR fusionnée | Commentaire |
| Déploiement `dev` (workflow manuel) | Commentaire |
| Déploiement `staging` (workflow manuel) | Commentaire |
| Déploiement `prod` (workflow manuel) | Transition → **Terminé** + commentaire |

## Secrets requis (Settings → Secrets and variables → Actions)

| Nom du secret | Valeur |
|---|---|
| `JIRA_BASE_URL` | `https://ourabahsalim.atlassian.net` |
| `JIRA_USER_EMAIL` | email du compte Atlassian |
| `JIRA_API_TOKEN` | token créé sur https://id.atlassian.com/manage-profile/security/api-tokens |

## Procédure de test (ticket véhicule : SCRAP-18)

1. Pousser la branche `feature/SCRAP-18-test-automatisation` → SCRAP-18 passe **En cours**
2. Ouvrir une PR → commentaire sur SCRAP-18
3. Fusionner la PR → commentaire sur SCRAP-18
4. Lancer le workflow sur `dev` puis `staging` → commentaires
5. Lancer le workflow sur `prod` → SCRAP-18 passe **Terminé**
6. Vérifier chaque étape dans l'onglet commentaires/statut de SCRAP-18

## Fichiers

- `.github/workflows/jira-sync.yml` — le seul workflow (branche, PR, déploiements)
- `.github/scripts/jira.sh` — appels API Jira (transition par nom de statut, commentaire)
