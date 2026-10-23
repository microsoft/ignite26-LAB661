#!/usr/bin/env bash
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Provision a Microsoft Foundry resource and project with two model deployments
# (gpt-5.4-mini and gpt-5.4) for the live track, plus the monitoring resources and
# role assignments tracing needs: a Log Analytics workspace, Application Insights,
# a project connection to it, and Log Analytics Reader for the project identity.
# Signs in to Azure, lets you pick a subscription, asks for a resource group and
# location, then creates whatever is missing. Safe to re-run: existing resources
# are reused.
#
# Needs the Owner role (or Contributor plus User Access Administrator) on the
# resource group so it can create role assignments.
#
# Optional environment variables skip the matching prompt:
#   SUBSCRIPTION_ID, RESOURCE_GROUP, LOCATION, FOUNDRY_NAME, PROJECT_NAME,
#   MODEL_CAPACITY (thousands of tokens per minute per deployment, default 30)
#
# Prints endpoints and deployment names at the end. It never prints or writes keys
# or the Application Insights connection string.
set -euo pipefail

MODELS=("gpt-5.4-mini" "gpt-5.4")
MODEL_CAPACITY="${MODEL_CAPACITY:-30}"
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

FAILED=()

# assign_role PRINCIPAL_ID TYPE ROLE SCOPE LABEL: creates the role assignment unless it exists.
assign_role() {
    local principal="$1" type="$2" role="$3" scope="$4" label="$5" existing error
    existing="$(az role assignment list --assignee "${principal}" --role "${role}" --scope "${scope}" \
        --query "length(@)" -o tsv 2>/dev/null || echo 0)"
    if [[ "${existing}" != "0" ]]; then
        ok "${label} (already assigned)"
        return 0
    fi
    if error="$(az role assignment create --assignee-object-id "${principal}" \
        --assignee-principal-type "${type}" --role "${role}" --scope "${scope}" --output none 2>&1)"; then
        ok "${label}"
    else
        warn "${label} failed: $(head -n1 <<<"${error}")"
        FAILED+=("role: ${label}")
    fi
}

# ----------------------------------------------------------------- sign in ----
log "Azure sign-in"
command -v az >/dev/null 2>&1 || die "Azure CLI (az) not found"
command -v jq >/dev/null 2>&1 || die "jq not found"
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
ask LOCATION "Azure location" "eastus2"

# Reuse a Foundry resource already in the group; otherwise pick a new unique name.
FOUNDRY_NAME="$(clean "${FOUNDRY_NAME:-$(az cognitiveservices account list --resource-group "${RESOURCE_GROUP}" \
    --query "[?kind=='AIServices'] | [0].name" -o tsv 2>/dev/null || true)}")"
if [[ -z "${FOUNDRY_NAME}" ]]; then
    ask FOUNDRY_NAME "Foundry resource name (globally unique)" "lab661-foundry-$(openssl rand -hex 3)"
fi
FOUNDRY_NAME="$(tr '[:upper:]' '[:lower:]' <<<"${FOUNDRY_NAME}")"
[[ "${FOUNDRY_NAME}" =~ ^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$ ]] \
    || die "Foundry resource name must be 2-64 letters, digits or hyphens, and not start or end with a hyphen"

LOGS_NAME="$(cut -c1-63 <<<"log-${FOUNDRY_NAME}")"
APPI_NAME="appi-${FOUNDRY_NAME}"
CONNECTION_NAME="appinsights"

log "Plan"
printf '    Subscription     : %s\n' "${SUBSCRIPTION_ID}"
printf '    Resource group   : %s\n' "${RESOURCE_GROUP}"
printf '    Location         : %s\n' "${LOCATION}"
printf '    Foundry resource : %s\n' "${FOUNDRY_NAME}"
printf '    Project          : %s\n' "${PROJECT_NAME}"
printf '    Models           : %s (capacity %sK TPM each)\n' "${MODELS[*]}" "${MODEL_CAPACITY}"
printf '    Monitoring       : %s, %s (connected to the project)\n' "${LOGS_NAME}" "${APPI_NAME}"
printf '    Role assignments : Foundry User and Log Analytics Reader for you, Log Analytics Reader for the project identity\n'
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
    for sku in GlobalStandard DataZoneStandard Standard; do
        if last_error="$(az cognitiveservices account deployment create \
            --name "${FOUNDRY_NAME}" \
            --resource-group "${RESOURCE_GROUP}" \
            --deployment-name "${model}" \
            --model-name "${model}" \
            --model-version "${version}" \
            --model-format OpenAI \
            --sku-name "${sku}" \
            --sku-capacity "${MODEL_CAPACITY}" \
            --output none 2>&1)"; then
            deployed_sku="${sku}"
            break
        fi
        warn "${model} ${version} not deployed with ${sku}: $(head -n1 <<<"${last_error}")"
    done

    if [[ -n "${deployed_sku}" ]]; then
        ok "deployed ${model} ${version} (${deployed_sku}, ${MODEL_CAPACITY}K TPM)"
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

# ------------------------------------------------------------------- access ----
log "Access (RBAC)"
FOUNDRY_USER_ROLE="53ca6127-db72-4b80-b1b0-d745d6d5456d"
LOG_ANALYTICS_READER_ROLE="73c42c96-874c-492b-b04d-ab87d138a893"
ACCOUNT_ID="$(az cognitiveservices account show --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)"

USER_OID="$(clean "$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)")"
if [[ -n "${USER_OID}" ]]; then
    assign_role "${USER_OID}" User "${FOUNDRY_USER_ROLE}" "${ACCOUNT_ID}" "Foundry User for you on ${FOUNDRY_NAME}"
    assign_role "${USER_OID}" User "${LOG_ANALYTICS_READER_ROLE}" "${APPI_ID}" "Log Analytics Reader for you on ${APPI_NAME}"
else
    warn "could not look up your user in Entra ID; skipping your role assignments"
fi

PROJECT_MI="$(clean "$(az cognitiveservices account project show \
    --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --project-name "${PROJECT_NAME}" \
    --query identity.principalId -o tsv 2>/dev/null || true)")"
if [[ -n "${PROJECT_MI}" ]]; then
    assign_role "${PROJECT_MI}" ServicePrincipal "${LOG_ANALYTICS_READER_ROLE}" "${APPI_ID}" \
        "Log Analytics Reader for the project identity on ${APPI_NAME}"
else
    warn "the project has no managed identity; skipping its role assignment"
    FAILED+=("role: project identity")
fi

# ----------------------------------------------------------------- summary ----
# First model from MODELS that is actually deployed, used for the .env hint.
AGENT_MODEL=""
for model in "${MODELS[@]}"; do
    if az cognitiveservices account deployment show \
        --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --deployment-name "${model}" >/dev/null 2>&1; then
        AGENT_MODEL="${model}"
        break
    fi
done

log "Summary"
printf '    Foundry resource : %s (%s)\n' "${FOUNDRY_NAME}" "${ACCOUNT_LOCATION}"
printf '    Project          : %s\n' "${PROJECT_NAME}"
printf '    Project endpoint : https://%s.services.ai.azure.com/api/projects/%s\n' "${FOUNDRY_NAME}" "${PROJECT_NAME}"
printf '    Deployments      : %s\n' "$(az cognitiveservices account deployment list \
    --name "${FOUNDRY_NAME}" --resource-group "${RESOURCE_GROUP}" --query "[].name" -o tsv | paste -sd, -)"
printf '    Log Analytics    : %s\n' "${LOGS_NAME}"
printf '    App Insights     : %s (project connection: %s)\n' "${APPI_NAME}" "${CONNECTION_NAME}"

cat <<EOF

    Values for .env (live track):

      AZURE_API_BASE=https://${FOUNDRY_NAME}.openai.azure.com
      DEVBOT_MODE=live
      DEVBOT_MODEL=azure/${AGENT_MODEL:-gpt-5.4-mini}
      ASSERT_MODEL=azure/${AGENT_MODEL:-gpt-5.4-mini}

    Get the key without printing it into a file by accident, then paste it into .env as AZURE_API_KEY:

      az cognitiveservices account keys list --name ${FOUNDRY_NAME} --resource-group ${RESOURCE_GROUP} --query key1 -o tsv

    Keep AZURE_API_VERSION from .env.example unless a model needs a newer API version.

    For tracing, get the Application Insights connection string and paste it into .env as
    APPLICATIONINSIGHTS_CONNECTION_STRING (treat it as a credential and never commit it):

      az resource show --resource-group ${RESOURCE_GROUP} --name ${APPI_NAME} --resource-type Microsoft.Insights/components --api-version 2020-02-02 --query properties.ConnectionString -o tsv
EOF

if [[ ${#FAILED[@]} -gt 0 ]]; then
    printf '\n    \033[0;31m%d item(s) not completed:\033[0m\n' "${#FAILED[@]}"
    printf '      - %s\n' "${FAILED[@]}"
    printf '\n'
    exit 1
fi
printf '\n    \033[0;32mFoundry project, models, monitoring and access are ready.\033[0m\n\n'
