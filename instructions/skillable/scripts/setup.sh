#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Skillable version of infra/setup.sh. The Skillable lab VM already grants the
# role assignments, so this copy never creates or checks them.
#
# Provision a Microsoft Foundry resource and project with two model deployments
# (gpt-5.4-mini and gpt-5.4) for the live track, plus a Log Analytics workspace,
# Application Insights and a project connection to it. Signs in to Azure, lets
# you pick a subscription, asks for a resource group and location, then creates
# whatever is missing. Safe to re-run: existing resources are reused. Writes .env
# for the live labs at the end.
#
# With --env-only it creates nothing. It finds the Foundry resource and
# Application Insights already in the resource group and only writes .env.
#
# Needs Contributor on the resource group (read access for --env-only) and Azure
# CLI 2.80.0 or newer.
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
# 2.80.0 adds 'az cognitiveservices account project' and --allow-project-management.
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
ask RESOURCE_GROUP "Resource group name" "rg-lab661-foundry"
[[ "${ENV_ONLY}" == "1" ]] || ask LOCATION "Azure location" "eastus2"

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
    your az login identity, using the roles the lab VM already granted.

      AZURE_API_BASE=${OPENAI_ENDPOINT}
      DEVBOT_MODE=live
      DEVBOT_MODEL=azure/${AGENT_MODEL}
      ASSERT_MODEL=azure/${AGENT_MODEL}
      ASSERT_AZURE_USE_AAD=1
      APPLICATIONINSIGHTS_CONNECTION_STRING=(written to .env, not printed)
EOF

    if [[ ${#FAILED[@]} -gt 0 ]]; then
        printf '\n    \033[0;31m%d item(s) not completed:\033[0m\n' "${#FAILED[@]}"
        printf '      - %s\n' "${FAILED[@]}"
        printf '\n'
        exit 1
    fi

    log "Local environment"
    local repo_root env_file write_env=1
    repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)"
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
printf '    Role assignments : skipped (already granted by the lab VM)\n'
read -r -p "    Create anything that is missing? [Y/n]: " reply
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

# --------------------------------------------------------- foundry resource ----
log "Foundry resource"
if az cognitiveservices account show --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" >/dev/null 2>&1; then
    ok "using existing resource ${FOUNDRY_NAME}"
else
    az cognitiveservices account create \
        --name "${FOUNDRY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --location "${LOCATION}" \
        --kind AIServices \
        --sku S0 \
        --custom-domain "${FOUNDRY_NAME}" \
        --allow-project-management \
        --assign-identity \
        --yes \
        --output none
    ok "created ${FOUNDRY_NAME}"
fi
ACCOUNT_LOCATION="$(az cognitiveservices account show --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --query location -o tsv)"

# ----------------------------------------------------------------- project ----
log "Foundry project"
if az cognitiveservices account project show \
    --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --project-name "${PROJECT_NAME}" >/dev/null 2>&1; then
    ok "using existing project ${PROJECT_NAME}"
else
    az cognitiveservices account project create \
        --name "${FOUNDRY_NAME}" \
        --resource-group "${RESOURCE_GROUP}" \
        --project-name "${PROJECT_NAME}" \
        --location "${ACCOUNT_LOCATION}" \
        --output none
    ok "created ${PROJECT_NAME}"
fi

# ------------------------------------------------------------------ models ----
for model in "${MODELS[@]}"; do
    log "Model ${model}"
    if az cognitiveservices account deployment show \
        --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --deployment-name "${model}" >/dev/null 2>&1; then
        ok "deployment ${model} already exists"
        continue
    fi

    # Latest non-deprecated version this resource can deploy in its region.
    version="$(clean "$(az cognitiveservices account list-models \
        --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" \
        --query "[?name=='${model}' && format=='OpenAI' && lifecycleStatus!='Deprecated'] | sort_by(@, &version) | [-1].version" \
        -o tsv)")"
    if [[ -z "${version}" ]]; then
        warn "${model} is not offered by ${FOUNDRY_NAME} in ${ACCOUNT_LOCATION}; try another location"
        FAILED+=("${model}")
        continue
    fi

    # SKU support varies by region and list-models does not report it reliably,
    # so try the broadest SKUs first and keep the last error for the warning.
    deployed_sku=""
    last_error=""
    capacity="$(capacity_for "${model}")"
    for sku in GlobalStandard DataZoneStandard Standard; do
        if last_error="$(az cognitiveservices account deployment create \
            --name "${FOUNDRY_NAME}" \
            --resource-group "${RESOURCE_GROUP}" \
            --deployment-name "${model}" \
            --model-name "${model}" \
            --model-version "${version}" \
            --model-format OpenAI \
            --sku-name "${sku}" \
            --sku-capacity "${capacity}" \
            --output none 2>&1)"; then
            deployed_sku="${sku}"
            break
        fi
        warn "${model} ${version} not deployed with ${sku}: $(head -n1 <<<"${last_error}")"
    done

    if [[ -n "${deployed_sku}" ]]; then
        ok "deployed ${model} ${version} (${deployed_sku}, ${capacity}K TPM)"
    else
        warn "could not deploy ${model} in ${ACCOUNT_LOCATION}; try another location or check quota"
        FAILED+=("${model}")
    fi
done

# -------------------------------------------------------------- monitoring ----
log "Log Analytics workspace"
if az monitor log-analytics workspace show \
    --resource-group "${RESOURCE_GROUP}" --workspace-name "${LOGS_NAME}" >/dev/null 2>&1; then
    ok "using existing workspace ${LOGS_NAME}"
else
    az monitor log-analytics workspace create \
        --resource-group "${RESOURCE_GROUP}" \
        --workspace-name "${LOGS_NAME}" \
        --location "${ACCOUNT_LOCATION}" \
        --retention-time 30 \
        --output none
    ok "created ${LOGS_NAME}"
fi
LOGS_ID="$(az monitor log-analytics workspace show \
    --resource-group "${RESOURCE_GROUP}" --workspace-name "${LOGS_NAME}" --query id -o tsv)"

log "Application Insights"
APPI_TYPE="Microsoft.Insights/components"
APPI_API="2020-02-02"
if az resource show --resource-group "${RESOURCE_GROUP}" --name "${APPI_NAME}" \
    --resource-type "${APPI_TYPE}" --api-version "${APPI_API}" >/dev/null 2>&1; then
    ok "using existing ${APPI_NAME}"
else
    az resource create \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${APPI_NAME}" \
        --resource-type "${APPI_TYPE}" \
        --api-version "${APPI_API}" \
        --location "${ACCOUNT_LOCATION}" \
        --properties "{\"Application_Type\":\"web\",\"WorkspaceResourceId\":\"${LOGS_ID}\"}" \
        --output none
    ok "created ${APPI_NAME}, backed by ${LOGS_NAME}"
fi
APPI_ID="$(az resource show --resource-group "${RESOURCE_GROUP}" --name "${APPI_NAME}" \
    --resource-type "${APPI_TYPE}" --api-version "${APPI_API}" --query id -o tsv)"
APPI_CONNECTION_STRING="$(az resource show --resource-group "${RESOURCE_GROUP}" --name "${APPI_NAME}" \
    --resource-type "${APPI_TYPE}" --api-version "${APPI_API}" --query properties.ConnectionString -o tsv)"

# Connects the project to Application Insights so Foundry can show traces.
log "Foundry project connection to Application Insights"
CONNECTION_URI="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY_NAME}/projects/${PROJECT_NAME}/connections/${CONNECTION_NAME}?api-version=2025-04-01-preview"
CONNECTION_BODY="$(mktemp)"
chmod 600 "${CONNECTION_BODY}"
jq -n --arg id "${APPI_ID}" --arg key "${APPI_CONNECTION_STRING}" '{
    properties: {
        category: "AppInsights",
        target: $id,
        authType: "ApiKey",
        isSharedToAll: true,
        credentials: { key: $key },
        metadata: { ApiType: "Azure", ResourceId: $id }
    }
}' > "${CONNECTION_BODY}"
if connection_error="$(az rest --method put --uri "${CONNECTION_URI}" --body "@${CONNECTION_BODY}" --output none 2>&1)"; then
    ok "connected ${PROJECT_NAME} to ${APPI_NAME} as '${CONNECTION_NAME}'"
else
    warn "could not create the project connection: $(head -n1 <<<"${connection_error}")"
    FAILED+=("project connection to Application Insights")
fi
rm -f "${CONNECTION_BODY}"

finish
