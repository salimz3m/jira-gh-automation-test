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

# Appel API avec diagnostic complet en cas d'erreur HTTP.
api() {
  local method="$1" path="$2" body="${3:-}" out status
  out=$(mktemp)
  if [[ -n "$body" ]]; then
    status=$(curl -sS -o "$out" -w '%{http_code}' -X "$method" \
      -u "$JIRA_USER_EMAIL:$JIRA_API_TOKEN" \
      -H 'Content-Type: application/json' --max-time 30 \
      --data-binary "$body" "$JIRA_BASE_URL$path")
  else
    status=$(curl -sS -o "$out" -w '%{http_code}' -X "$method" \
      -u "$JIRA_USER_EMAIL:$JIRA_API_TOKEN" \
      -H 'Content-Type: application/json' --max-time 30 \
      "$JIRA_BASE_URL$path")
  fi
  if [[ "$status" -lt 200 || "$status" -ge 300 ]]; then
    echo "ERREUR HTTP $status sur $method $path" >&2
    echo "JIRA_BASE_URL utilise : $JIRA_BASE_URL" >&2
    echo "--- Reponse de Jira ---" >&2
    cat "$out" >&2
    echo "" >&2
    rm -f "$out"
    exit 1
  fi
  cat "$out"
  rm -f "$out"
}

adf() {
  jq -n --arg t "$1" \
    '{body:{type:"doc",version:1,content:[{type:"paragraph",content:[{type:"text",text:$t}]}]}}'
}

comment() {
  api POST "/rest/api/3/issue/$1/comment" "$(adf "$2")" > /dev/null
  echo "Commentaire ajoute sur $1."
}

transition() {
  local key="$1" target="$2" text="${3:-}" tid transitions current
  transitions=$(api GET "/rest/api/3/issue/$key/transitions")
  tid=$(printf '%s' "$transitions" \
        | jq -r --arg t "$target" '.transitions[] | select(.name == $t or .to.name == $t) | .id' \
        | head -n1)
  if [[ -z "${tid// /}" ]]; then
    # Idempotence : si le ticket est deja dans le statut vise, on ne fait rien.
    current=$(api GET "/rest/api/3/issue/$key?fields=status" | jq -r '.fields.status.name')
    if [[ "$current" == "$target" ]]; then
      echo "$key : deja en « $target », rien a faire."
      return 0
    fi
    echo "ERREUR : transition vers « $target » introuvable pour $key (statut actuel : $current)." >&2
    echo "Transitions disponibles pour ce ticket :" >&2
    printf '%s' "$transitions" | jq -r '.transitions[] | "  - \(.name) (vers \(.to.name))"' >&2
    return 1
  fi
  api POST "/rest/api/3/issue/$key/transitions" \
    "$(jq -n --arg id "$tid" '{transition:{id:$id}}')" > /dev/null
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
