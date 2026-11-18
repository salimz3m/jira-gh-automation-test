#!/usr/bin/env bash
# Appels API Jira Cloud (REST v3) pour l'automatisation des statuts.
#
# Usage :
#   jira.sh transition <CLE> "<nom du statut cible>" ["<commentaire optionnel>"]
#   jira.sh comment    <CLE> "<commentaire>"
#
# Requiert les variables d'environnement :
#   JIRA_BASE_URL, JIRA_USER_EMAIL, JIRA_API_TOKEN

set -euo pipefail

: "${JIRA_BASE_URL:?Secret JIRA_BASE_URL manquant}"
: "${JIRA_USER_EMAIL:?Secret JIRA_USER_EMAIL manquant}"
: "${JIRA_API_TOKEN:?Secret JIRA_API_TOKEN manquant}"

CMD="${1:-}"
KEY="${2:-}"
ARG3="${3:-}"
ARG4="${4:-}"

if [[ -z "$CMD" || -z "$KEY" ]]; then
  echo "ERREUR : arguments manquants (commande, cle)." >&2
  exit 1
fi

auth=(-u "$JIRA_USER_EMAIL:$JIRA_API_TOKEN" -H 'Content-Type: application/json' -sS -f --max-time 30)

comment() {
  local key="$1" text="$2"
  jq -n --arg t "$text" \
    '{body:{type:"doc",version:1,content:[{type:"paragraph",content:[{type:"text",text:$t}]}]}}' \
    | curl "${auth[@]}" -X POST --data-binary @- "$JIRA_BASE_URL/rest/api/3/issue/$key/comment" > /dev/null
  echo "Commentaire ajoute sur $key."
}

transition() {
  local key="$1" target="$2" text="${3:-}" tid
  tid=$(curl "${auth[@]}" "$JIRA_BASE_URL/rest/api/3/issue/$key/transitions" \
        | jq -r --arg t "$target" '.transitions[] | select(.name == $t or .to.name == $t) | .id' \
        | head -n1)
  if [[ -z "${tid// /}" ]]; then
    echo "ERREUR : transition vers « $target » introuvable pour $key (statut actuel ou permissions)." >&2
    exit 1
  fi
  jq -n --argjson id "$tid" '{id:$id}' \
    | curl "${auth[@]}" -X POST --data-binary @- "$JIRA_BASE_URL/rest/api/3/issue/$key/transitions" > /dev/null
  echo "$key -> $target."
  if [[ -n "$text" ]]; then
    comment "$key" "$text"
  fi
}

case "$CMD" in
  transition) transition "$KEY" "$ARG3" "$ARG4" ;;
  comment)    comment "$KEY" "$ARG3" ;;
  *) echo "Commande inconnue : $CMD (attendu : transition | comment)" >&2; exit 1 ;;
esac
