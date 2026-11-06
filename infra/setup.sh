#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Provision a Microsoft Foundry resource and project with two model deployments
# (gpt-5.4-mini and gpt-5.4) for the live track by deploying infra/main.bicep,
# which also creates a Log Analytics workspace, Application Insights, a project
# connection to it, Foundry User, Cognitive Services OpenAI User and Log Analytics
# Reader for you, and Log Analytics Reader for the project identity.
# Signs in to Azure, lets you pick a subscription, asks for a resource group and
# location, then deploys. Safe to re-run: the deployment updates resources in
# place. Writes .env for the live labs at the end.
#
# With --env-only it creates nothing. It finds the Foundry resource and
# Application Insights already in the resource group and only writes .env, for
# example in a pre-provisioned Skillable lab.
#
# Needs the Owner role (or Contributor plus User Access Administrator) on the
# resource group so it can create role assignments. --env-only needs read access.
# Needs Azure CLI 2.80.0 or newer.
#
# Optional environment variables skip the matching prompt:
#   SUBSCRIPTION_ID, RESOURCE_GROUP, LOCATION, FOUNDRY_NAME, PROJECT_NAME,
#   MINI_CAPACITY  (gpt-5.4-mini, thousands of tokens per minute, default 500)
#   MODEL_CAPACITY (gpt-5.4, thousands of tokens per minute, default 100)
#
# Prints endpoints and deployment names at the end. It never prints keys or the
# Application Insights connection string; the connection string goes to Azure
# through a private temporary file and into the local .env file. The lab signs in
# with your Azure identity (az login), so no API key is needed.
set -euo pipefail

MODELS=("gpt-5.4-mini" "gpt-5.4")
# ASSERT generates test cases on gpt-5.4-mini with 8 parallel calls, so it needs more headroom.
MINI_CAPACITY="${MINI_CAPACITY:-500}"
MODEL_CAPACITY="${MODEL_CAPACITY:-100}"
capacity_for() { [[ "$1" == "gpt-5.4-mini" ]] && echo "${MINI_CAPACITY}" || echo "${MODEL_CAPACITY}"; }
PROJECT_NAME="${PROJECT_NAME:-lab661-project}"

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[0;32mOK\033[0m   %s\n' "$*"; }
warn() { printf '    \033[0;33mWARN\033[0m %s\n' "$*"; }
die()  { printf '    \033[0;31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

# ask VAR "Prompt" [default]: keeps the value when VAR is already set.
ask() {
    local var="$1" prompt="$2" default="${3:-}" reply
    [[ -n "${!var:-}" ]] && return 0
    if [[ -n "${default}" ]]; then
        read -r -p "    ${prompt} [${default}]: " reply
        printf -v "${var}" '%s' "${reply:-${default}}"
    else
        read -r -p "    ${prompt}: " reply
        [[ -n "${reply}" ]] || die "${prompt} is required"
        printf -v "${var}" '%s' "${reply}"
    fi
}

# az prints "None" for a null value with -o tsv; treat it as empty.
clean() { [[ "$1" == "None" ]] && printf '' || printf '%s' "$1"; }

ENV_ONLY=0
case "${1:-}" in
    "") ;;
    --env-only) ENV_ONLY=1 ;;
    *) die "unknown option '$1'; the only option is --env-only" ;;
esac

FAILED=()

# ensure_jq: installs jq with winget (Git Bash on Windows), apt-get or brew when it is missing.
ensure_jq() {
    command -v jq >/dev/null 2>&1 && return 0
    warn "jq not found; installing it"
    if command -v winget >/dev/null 2>&1; then
        # Exits non-zero when jq is already installed but not yet on this shell's PATH.
        winget install --id jqlang.jq -e --silent \
            --accept-source-agreements --accept-package-agreements >/dev/null 2>&1 || true
        PATH="${PATH}:$(cygpath -u "${LOCALAPPDATA}")/Microsoft/WinGet/Links"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq jq >/dev/null || true
    elif command -v brew >/dev/null 2>&1; then
        brew install jq >/dev/null || true
    fi
    command -v jq >/dev/null 2>&1 || die "jq not found and could not be installed; install jq and re-run"
    ok "jq installed"
}

# ----------------------------------------------------------------- sign in ----
log "Azure sign-in"
command -v az >/dev/null 2>&1 || die "Azure CLI (az) not found"
# Oldest Azure CLI this lab is tested with.
AZ_MIN_VERSION="2.80.0"
AZ_VERSION="$(az version --query '"azure-cli"' -o tsv 2>/dev/null | tr -d '\r' || true)"
[[ "$(printf '%s\n' "${AZ_MIN_VERSION}" "${AZ_VERSION:-0}" | sort -V | head -n1)" == "${AZ_MIN_VERSION}" ]] \
    || die "Azure CLI ${AZ_VERSION:-unknown} is too old; ${AZ_MIN_VERSION} or newer is needed. Run 'az upgrade', then re-run this script"
ensure_jq
if az account show >/dev/null 2>&1; then
    ok "signed in as $(az account show --query user.name -o tsv)"
    read -r -p "    Use this sign-in? [Y/n]: " reply
    if [[ "${reply:-Y}" =~ ^[Nn] ]]; then
        az login --use-device-code >/dev/null
    fi
else
    az login --use-device-code >/dev/null
fi

# ------------------------------------------------------------ subscription ----
log "Subscription"
if [[ -z "${SUBSCRIPTION_ID:-}" ]]; then
    mapfile -t SUBS < <(az account list --query "[?state=='Enabled'].[name,id]" -o tsv)
    [[ ${#SUBS[@]} -gt 0 ]] || die "no enabled subscriptions found for this account"
    if [[ ${#SUBS[@]} -eq 1 ]]; then
        SUBSCRIPTION_ID="$(cut -f2 <<<"${SUBS[0]}")"
    else
        i=1
        for s in "${SUBS[@]}"; do
            printf '    %2d) %s  (%s)\n' "${i}" "$(cut -f1 <<<"${s}")" "$(cut -f2 <<<"${s}")"
            i=$((i + 1))
        done
        read -r -p "    Choose a subscription [1-${#SUBS[@]}]: " choice
        [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#SUBS[@]} )) || die "invalid choice"
        SUBSCRIPTION_ID="$(cut -f2 <<<"${SUBS[$((choice - 1))]}")"
    fi
fi
az account set --subscription "${SUBSCRIPTION_ID}"
ok "using $(az account show --query name -o tsv) (${SUBSCRIPTION_ID})"

# ------------------------------------------------- resource group, location ----
log "Resource group and location"
# Skillable labs pre-create a LAB661 group; offer it as the default when present.
DEFAULT_GROUP="rg-lab661-foundry"
if [[ "$(az group exists --name LAB661)" == "true" ]]; then
    DEFAULT_GROUP="LAB661"
fi
ask RESOURCE_GROUP "Resource group name" "${DEFAULT_GROUP}"
DEFAULT_LOCATION="$(clean "$(az group show --name "${RESOURCE_GROUP}" --query location -o tsv 2>/dev/null || true)")"
[[ "${ENV_ONLY}" == "1" ]] || ask LOCATION "Azure location" "${DEFAULT_LOCATION:-eastus2}"

# Reuse a Foundry resource already in the group; otherwise pick a new unique name.
FOUNDRY_NAME="$(clean "${FOUNDRY_NAME:-$(az cognitiveservices account list --resource-group "${RESOURCE_GROUP}" \
    --query "[?kind=='AIServices'] | [0].name" -o tsv 2>/dev/null || true)}")"
if [[ -z "${FOUNDRY_NAME}" ]]; then
    [[ "${ENV_ONLY}" == "0" ]] || die "no Foundry resource found in resource group ${RESOURCE_GROUP}"
    ask FOUNDRY_NAME "Foundry resource name (globally unique)" "lab661-foundry-$(openssl rand -hex 3)"
fi
FOUNDRY_NAME="$(tr '[:upper:]' '[:lower:]' <<<"${FOUNDRY_NAME}")"
[[ "${FOUNDRY_NAME}" =~ ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ ]] \
    || die "Foundry resource name must be 2-64 letters, digits or hyphens, and not start or end with a hyphen"

# An existing Foundry resource cannot move, so deploy into its location.
if [[ "${ENV_ONLY}" == "0" ]]; then
    existing_location="$(clean "$(az cognitiveservices account show --name "${FOUNDRY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" --query location -o tsv 2>/dev/null || true)")"
    if [[ -n "${existing_location}" && "${existing_location}" != "${LOCATION}" ]]; then
        warn "${FOUNDRY_NAME} already exists in ${existing_location}; using that location"
        LOCATION="${existing_location}"
    fi
fi

LOGS_NAME="$(cut -c1-63 <<<"log-${FOUNDRY_NAME}")"
APPI_NAME="appi-${FOUNDRY_NAME}"
CONNECTION_NAME="appinsights"

# Print the summary, stop on failures, then write .env from .env.example.
finish() {
    AGENT_MODEL=""
    for model in "${MODELS[@]}"; do
        if az cognitiveservices account deployment show \
            --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --deployment-name "${model}" >/dev/null 2>&1; then
            AGENT_MODEL="${model}"
            break
        fi
    done
    [[ -n "${AGENT_MODEL}" ]] || FAILED+=("model deployment: none of ${MODELS[*]} found on ${FOUNDRY_NAME}")

    # Read the real OpenAI endpoint; fall back to the custom-domain form the resource was created with.
    OPENAI_ENDPOINT="$(clean "$(az cognitiveservices account show --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" \
        --query 'properties.endpoints."OpenAI Language Model Instance API"' -o tsv 2>/dev/null || true)")"
    OPENAI_ENDPOINT="${OPENAI_ENDPOINT%/}"
    OPENAI_ENDPOINT="${OPENAI_ENDPOINT:-https://${FOUNDRY_NAME}.openai.azure.com}"

    log "Summary"
    printf '    Foundry resource : %s (%s)\n' "${FOUNDRY_NAME}" "${ACCOUNT_LOCATION}"
    printf '    Project          : %s\n' "${PROJECT_NAME}"
    printf '    Project endpoint : https://%s.services.ai.azure.com/api/projects/%s\n' "${FOUNDRY_NAME}" "${PROJECT_NAME}"
    printf '    Deployments      : %s\n' "$(az cognitiveservices account deployment list \
        --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --query "[].name" -o tsv | paste -sd, -)"
    printf '    Log Analytics    : %s\n' "${LOGS_NAME}"
    printf '    App Insights     : %s (project connection: %s)\n' "${APPI_NAME}" "${CONNECTION_NAME}"

    cat <<EOF

    Live settings for .env. No API key is needed: DevBot and ASSERT sign in with
    your az login identity.

      AZURE_API_BASE=${OPENAI_ENDPOINT}
      DEVBOT_MODE=live
      DEVBOT_MODEL=azure/${AGENT_MODEL}
      ASSERT_MODEL=azure/${AGENT_MODEL}
      ASSERT_AZURE_USE_AAD=1
      APPLICATIONINSIGHTS_CONNECTION_STRING=(written to .env, not printed)

    New role assignments can take a few minutes to apply. If the first live call
    returns 401 or 403, wait a few minutes and try again.
EOF

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        printf '\n    \033[0;31m%d item(s) not completed:\033[0m\n' "${#FAILED[@]}"
        printf '      - %s\n' "${FAILED[@]}"
        printf '\n'
        exit 1
    fi

    log "Local environment"
    local repo_root env_file write_env=1
    repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    env_file="${repo_root}/.env"
    if [[ -e "${env_file}" || -L "${env_file}" ]]; then
        read -r -p "    Replace existing .env with this lab's settings? [y/N]: " reply
        if [[ ! "${reply:-N}" =~ ^[Yy]$ ]]; then
            write_env=0
            warn "existing .env kept unchanged; verify its settings before using the live labs"
        fi
    fi
    if [[ "${write_env}" == "1" ]]; then
        ENV_TEMP="$(mktemp)"
        trap 'rm -f -- "${ENV_TEMP}"' EXIT
        chmod 600 "${ENV_TEMP}"
        while IFS= read -r line || [[ -n "${line}" ]]; do
            case "${line}" in
                DEVBOT_MODE=*) printf 'DEVBOT_MODE=live\n' ;;
                AZURE_API_BASE=*) printf 'AZURE_API_BASE=%s\n' "${OPENAI_ENDPOINT}" ;;
                DEVBOT_MODEL=*|ASSERT_MODEL=*) printf '%s=azure/%s\n' "${line%%=*}" "${AGENT_MODEL}" ;;
                ASSERT_AZURE_USE_AAD=*) printf 'ASSERT_AZURE_USE_AAD=1\n' ;;
                APPLICATIONINSIGHTS_CONNECTION_STRING=*)
                    printf 'APPLICATIONINSIGHTS_CONNECTION_STRING='
                    # -r emits the shell-quoted value raw; without it jq adds JSON quotes.
                    printf '%s' "${APPI_CONNECTION_STRING}" | jq -Rrs '@sh'
                    ;;
                *) printf '%s\n' "${line}" ;;
            esac
        done < "${repo_root}/.env.example" > "${ENV_TEMP}"
        mv -f -- "${ENV_TEMP}" "${env_file}"
        ok "created .env for live mode with owner-only permissions; credentials not printed"
    fi

    if [[ "${ENV_ONLY}" == "1" ]]; then
        printf '\n    \033[0;32mLocal environment is ready.\033[0m\n\n'
    else
        printf '\n    \033[0;32mFoundry project, models, monitoring and access are ready.\033[0m\n\n'
    fi
}

if [[ "${ENV_ONLY}" == "1" ]]; then
    log "Existing resources"
    ACCOUNT_LOCATION="$(clean "$(az cognitiveservices account show --name "${FOUNDRY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" --query location -o tsv 2>/dev/null || true)")"
    [[ -n "${ACCOUNT_LOCATION}" ]] || die "Foundry resource ${FOUNDRY_NAME} not found in ${RESOURCE_GROUP}"
    # Pre-provisioned labs may not follow this script's naming, so look these up.
    APPI_NAME="$(clean "$(az resource list --resource-group "${RESOURCE_GROUP}" \
        --resource-type Microsoft.Insights/components --query "[0].name" -o tsv)")"
    [[ -n "${APPI_NAME}" ]] || die "no Application Insights found in ${RESOURCE_GROUP}"
    LOGS_NAME="$(clean "$(az resource list --resource-group "${RESOURCE_GROUP}" \
        --resource-type Microsoft.OperationalInsights/workspaces --query "[0].name" -o tsv)")"
    APPI_CONNECTION_STRING="$(az resource show --resource-group "${RESOURCE_GROUP}" --name "${APPI_NAME}" \
        --resource-type Microsoft.Insights/components --api-version 2020-02-02 --query properties.ConnectionString -o tsv)"
    ok "found ${FOUNDRY_NAME} and ${APPI_NAME}; nothing will be created"
    finish
    exit 0
fi

log "Plan"
printf '    Subscription     : %s\n' "${SUBSCRIPTION_ID}"
printf '    Resource group   : %s\n' "${RESOURCE_GROUP}"
printf '    Location         : %s\n' "${LOCATION}"
printf '    Foundry resource : %s\n' "${FOUNDRY_NAME}"
printf '    Project          : %s\n' "${PROJECT_NAME}"
printf '    Models           : gpt-5.4-mini (%sK TPM), gpt-5.4 (%sK TPM)\n' "${MINI_CAPACITY}" "${MODEL_CAPACITY}"
printf '    Monitoring       : %s, %s (connected to the project)\n' "${LOGS_NAME}" "${APPI_NAME}"
printf '    Role assignments : Foundry User, Cognitive Services OpenAI User and Log Analytics Reader for you, Log Analytics Reader for the project identity\n'
read -r -p "    Deploy infra/main.bicep with these settings? [Y/n]: " reply
if [[ "${reply:-Y}" =~ ^[Nn] ]]; then
    echo "    Cancelled. Nothing was created."
    exit 0
fi

# ------------------------------------------------------- resource provider ----
log "Resource providers"
for namespace in Microsoft.CognitiveServices Microsoft.Insights Microsoft.OperationalInsights; do
    if [[ "$(az provider show --namespace "${namespace}" --query registrationState -o tsv)" != "Registered" ]]; then
        az provider register --namespace "${namespace}" --wait
    fi
    ok "${namespace} is registered"
done

# ---------------------------------------------------------- resource group ----
log "Resource group"
if [[ "$(az group exists --name "${RESOURCE_GROUP}")" == "true" ]]; then
    ok "using existing group ${RESOURCE_GROUP}"
else
    az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}" --output none
    ok "created ${RESOURCE_GROUP} in ${LOCATION}"
fi

# --------------------------------------------------------------- deployment ----
log "Deploy infra/main.bicep"
USER_OID="$(clean "$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)")"
PARAMS=(location="${LOCATION}" foundryName="${FOUNDRY_NAME}" projectName="${PROJECT_NAME}"
    miniCapacity="${MINI_CAPACITY}" modelCapacity="${MODEL_CAPACITY}")
if [[ -n "${USER_OID}" ]]; then
    PARAMS+=(userPrincipalId="${USER_OID}")
else
    warn "could not look up your user in Entra ID; deploying without your role assignments"
    FAILED+=("role: your access to the models (ask an admin for Foundry User and Cognitive Services OpenAI User on ${FOUNDRY_NAME})")
fi
TEMPLATE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/main.bicep"
echo "    This takes a few minutes."
if ! deploy_error="$(az deployment group create \
    --resource-group "${RESOURCE_GROUP}" \
    --name lab661-foundry \
    --template-file "${TEMPLATE}" \
    --parameters "${PARAMS[@]}" \
    --only-show-errors --output none 2>&1)"; then
    die "deployment failed: $(head -n3 <<<"${deploy_error}")"
fi
ok "deployed ${FOUNDRY_NAME}, ${PROJECT_NAME}, ${MODELS[*]}, ${LOGS_NAME} and ${APPI_NAME}"

ACCOUNT_LOCATION="$(az cognitiveservices account show --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --query location -o tsv)"
APPI_CONNECTION_STRING="$(az resource show --resource-group "${RESOURCE_GROUP}" --name "${APPI_NAME}" \
    --resource-type Microsoft.Insights/components --api-version 2020-02-02 --query properties.ConnectionString -o tsv)"

finish
