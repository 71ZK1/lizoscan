#!/usr/bin/env bash
#
# install.sh
# Installs only the tools needed for lizoscan.sh that are NOT already
# present on the system. Safe to re-run — every tool is checked first.
#
# For use ONLY against targets you own or are explicitly authorized to test.

set -uo pipefail

GOBIN="${GOBIN:-$HOME/go/bin}"
mkdir -p "$GOBIN"
export PATH="$PATH:$GOBIN"

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"
log()  { echo -e "${GREEN}[+]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!]${RESET} $*"; }
err()  { echo -e "${RED}[-]${RESET} $*"; }

# Checks $PATH first, then falls back to common install locations in case
# a tool was installed in an earlier session whose PATH changes haven't
# been sourced yet in this shell (so we never reinstall something that's
# already sitting on disk).
EXTRA_BIN_DIRS=(
    "$GOBIN"
    "$HOME/go/bin"
    "$HOME/.local/bin"
    "/usr/local/bin"
    "/usr/local/go/bin"
)

need_cmd() {
    local tool="$1"
    command -v "$tool" >/dev/null 2>&1 && return 0
    local dir
    for dir in "${EXTRA_BIN_DIRS[@]}"; do
        [ -x "$dir/$tool" ] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Base dependencies (go, git) — required to build the Go-based tools below.
# ---------------------------------------------------------------------------
if ! need_cmd go; then
    log "Go not found — installing Go..."
    GO_VERSION="1.23.0"
    curl -sSLo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    export PATH="$PATH:/usr/local/go/bin"
    if ! grep -q "/usr/local/go/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"
    fi
else
    log "Go already installed: $(go version)"
fi

if ! need_cmd git; then
    log "git not found — installing..."
    sudo apt-get update -y && sudo apt-get install -y git
else
    log "git already installed."
fi

# ---------------------------------------------------------------------------
# Go-installable tools: name -> module path
# ---------------------------------------------------------------------------
declare -A GO_TOOLS=(
    [httpx]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    [nuclei]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    [gf]="github.com/tomnomnom/gf@latest"
    [qsreplace]="github.com/tomnomnom/qsreplace@latest"
    [anew]="github.com/tomnomnom/anew@latest"
    [unfurl]="github.com/tomnomnom/unfurl@latest"
    [dalfox]="github.com/hahwul/dalfox/v2@latest"
    [ffuf]="github.com/ffuf/ffuf/v2@latest"
    [crlfuzz]="github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest"
)

for tool in "${!GO_TOOLS[@]}"; do
    if need_cmd "$tool"; then
        log "$tool already installed — skipping."
    else
        log "Installing $tool ..."
        GOBIN="$GOBIN" go install -v "${GO_TOOLS[$tool]}" \
            && log "$tool installed." \
            || err "Failed to install $tool"
    fi
done

# ---------------------------------------------------------------------------
# gf patterns (parameter/vuln-pattern matching) — only clone if missing
# ---------------------------------------------------------------------------
GF_DIR="$HOME/.gf"
if [ -d "$GF_DIR" ] && [ "$(ls -A "$GF_DIR" 2>/dev/null)" ]; then
    log "gf patterns already present at $GF_DIR — skipping."
else
    log "Fetching gf patterns..."
    mkdir -p "$GF_DIR"
    TMP_GF=$(mktemp -d)
    git clone --depth 1 https://github.com/1ndianl33t/Gf-Patterns "$TMP_GF/Gf-Patterns" 2>/dev/null
    cp "$TMP_GF"/Gf-Patterns/*.json "$GF_DIR/" 2>/dev/null
    rm -rf "$TMP_GF"
fi

# ---------------------------------------------------------------------------
# nuclei-templates — nuclei pulls/updates these itself on first run, but
# we trigger it here only if the templates dir doesn't exist yet.
# ---------------------------------------------------------------------------
NUCLEI_TEMPLATES_DIR="$HOME/nuclei-templates"
if [ -d "$NUCLEI_TEMPLATES_DIR" ]; then
    log "nuclei-templates already present — skipping initial fetch."
else
    if need_cmd nuclei; then
        log "Fetching nuclei-templates..."
        nuclei -update-templates -silent || warn "nuclei template fetch reported an issue."
    fi
fi


# ---------------------------------------------------------------------------
# nikto — general web vulnerability scanner (apt package, Perl-based)
# ---------------------------------------------------------------------------
if need_cmd nikto; then
    log "nikto already installed — skipping."
else
    log "Installing nikto..."
    sudo apt-get update -y && sudo apt-get install -y nikto \
        && log "nikto installed." \
        || err "Failed to install nikto"
fi

# ---------------------------------------------------------------------------
# sqlmap — automated SQL injection confirmation (git clone, Python-based)
# ---------------------------------------------------------------------------
if need_cmd sqlmap; then
    log "sqlmap already installed — skipping."
else
    log "Installing sqlmap..."
    mkdir -p "$HOME/tools"
    if [ -d "$HOME/tools/sqlmap" ]; then
        log "sqlmap directory already present — skipping clone."
    else
        git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git "$HOME/tools/sqlmap"
    fi
    sudo ln -sf "$HOME/tools/sqlmap/sqlmap.py" /usr/local/bin/sqlmap
    sudo chmod +x /usr/local/bin/sqlmap
    log "sqlmap installed (wrapper at /usr/local/bin/sqlmap)."
fi

# ---------------------------------------------------------------------------
# Corsy — CORS misconfiguration scanner (git clone, Python-based)
# ---------------------------------------------------------------------------
if [ -f "$HOME/tools/Corsy/corsy.py" ]; then
    log "Corsy already installed — skipping."
else
    log "Installing Corsy..."
    mkdir -p "$HOME/tools"
    git clone --depth 1 https://github.com/s0md3v/Corsy.git "$HOME/tools/Corsy" 2>/dev/null
    if [ -f "$HOME/tools/Corsy/requirements.txt" ]; then
        pip3 install -r "$HOME/tools/Corsy/requirements.txt" --quiet 2>/dev/null
    fi
    chmod +x "$HOME/tools/Corsy/corsy.py" 2>/dev/null
    log "Corsy installed at \$HOME/tools/Corsy."
fi

# ---------------------------------------------------------------------------
# Wordlist for ffuf content discovery (SecLists' common list, trimmed)
# ---------------------------------------------------------------------------
WORDLIST_DIR="$HOME/tools/wordlists"
if [ -f "$WORDLIST_DIR/common.txt" ] || [ -f /usr/share/wordlists/dirb/common.txt ]; then
    log "ffuf wordlist already present — skipping."
else
    log "Fetching a wordlist for ffuf..."
    mkdir -p "$WORDLIST_DIR"
    curl -sSLo "$WORDLIST_DIR/common.txt" \
        "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt" \
        || warn "Could not fetch wordlist — ffuf stage will be skipped at scan time."
fi

echo
log "Install check complete. Make sure \$HOME/go/bin is on your PATH:"
echo "    export PATH=\$PATH:\$HOME/go/bin"
log "Run: source ~/.bashrc   (or open a new shell) before running lizoscan.sh"
