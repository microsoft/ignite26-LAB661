#!/usr/bin/env bash
# Dev container setup for LAB661: checks the tooling, installs opa and Python requirements.
# Non-interactive and credential-free; it never signs in to Azure.

set -uo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAILURES=()

log()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[0;32mOK\033[0m   %s\n' "$*"; }
warn() { printf '    \033[0;33mWARN\033[0m %s\n' "$*"; }
fail() { printf '    \033[0;31mFAIL\033[0m %s\n' "$*"; FAILURES+=("$1"); }

# ---------------------------------------------------------------- python ----
log "Python"
if command -v python3 >/dev/null 2>&1; then
    ok "python $(python3 -c 'import platform; print(platform.python_version())')"
else
    fail "python3 not found"
fi

# ------------------------------------------------------------- azure cli ----
log "Azure CLI"
if command -v az >/dev/null 2>&1; then
    az config set core.collect_telemetry=false --only-show-errors >/dev/null 2>&1
    ok "az $(az version --query '"azure-cli"' -o tsv 2>/dev/null)"
else
    fail "az not found"
fi

# ------------------------------------------------------------- az bicep ----
log "Bicep"
if command -v az >/dev/null 2>&1; then
    BICEP_VERSION="$(az bicep version --only-show-errors 2>/dev/null | head -n1)"
    if [[ -n "${BICEP_VERSION}" ]]; then
        ok "${BICEP_VERSION}"
    else
        fail "az bicep is not available"
    fi
else
    fail "az bicep skipped because az is missing"
fi

# ------------------------------------------------------------ shell tools ----
# infra/setup.sh needs jq and openssl.
log "Shell tools"
for tool in jq openssl; do
    if command -v "${tool}" >/dev/null 2>&1; then
        ok "${tool} found"
    elif sudo apt-get update -qq >/dev/null 2>&1 && sudo apt-get install -y -qq "${tool}" >/dev/null 2>&1; then
        ok "${tool} installed"
    else
        fail "could not install ${tool}"
    fi
done

# ------------------------------------------------------------------ opa ----
log "Open Policy Agent"
OPA_VERSION="v0.70.0"
if command -v opa >/dev/null 2>&1; then
    ok "$(opa version | head -n1)"
else
    case "$(uname -m)" in
        x86_64)        OPA_ARCH="amd64" ;;
        aarch64|arm64) OPA_ARCH="arm64" ;;
        *)             OPA_ARCH="" ;;
    esac
    if [[ -z "${OPA_ARCH}" ]]; then
        fail "unsupported architecture for opa: $(uname -m)"
    else
        OPA_URL="https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${OPA_ARCH}_static"
        OPA_TMP="$(mktemp -d)"
        if curl -fsSL -o "${OPA_TMP}/opa" "${OPA_URL}" \
            && curl -fsSL -o "${OPA_TMP}/opa.sha256" "${OPA_URL}.sha256" \
            && (cd "${OPA_TMP}" && echo "$(cut -d' ' -f1 opa.sha256)  opa" | sha256sum -c --quiet -) \
            && sudo install -m 0755 "${OPA_TMP}/opa" /usr/local/bin/opa; then
            ok "$(opa version | head -n1)"
        else
            fail "could not install opa ${OPA_VERSION}"
        fi
        rm -rf "${OPA_TMP}"
    fi
fi

# --------------------------------------------------------- dependencies ----
log "Python dependencies"
if [[ -f requirements.txt ]]; then
    python3 -m pip install --quiet --disable-pip-version-check -r requirements.txt \
        && ok "installed requirements.txt" \
        || fail "could not install requirements.txt"
else
    warn "no requirements.txt found, skipping"
fi

# -------------------------------------------------------------- summary -----
log "Summary"
if [[ ${#FAILURES[@]} -eq 0 ]]; then
    printf '    \033[0;32mAll required tools are present.\033[0m\n\n'
    exit 0
fi

printf '    \033[0;31m%d check(s) failed:\033[0m\n' "${#FAILURES[@]}"
for failure in "${FAILURES[@]}"; do
    printf '      - %s\n' "${failure}"
done
printf '\n'
exit 1
