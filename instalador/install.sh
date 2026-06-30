#!/usr/bin/env bash
# =====================================================================
#  Sincro IA - install.sh  (instalador Linux/macOS, espejo de bootstrap.ps1)
#  Instala el entorno (sin IA). Ejecuta las FASES 0 a 5.
#  La inteligencia (Claude) recien arranca DESPUES, ya instalado.
#
#  Uso:
#    chmod +x install.sh
#    ./install.sh --license "XXXX-XXXX" --gemini "AIza..." [--template ./plantilla]
#  O por entorno:
#    LICENSE_KEY=XXXX GEMINI_KEY=AIza... ./install.sh
#  Si falta la licencia/gemini, se piden de forma interactiva.
# =====================================================================

set -uo pipefail   # NO set -e: ningun hipo de un prerrequisito debe abortar todo

# --------------------------------------------------------------------
# Parametros
# --------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LICENSE_KEY="${LICENSE_KEY:-}"
GEMINI_KEY="${GEMINI_KEY:-}"
TEMPLATE_DIR="${TEMPLATE_DIR:-$SCRIPT_DIR/plantilla}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/SincroIA}"
LICENSE_API="${LICENSE_API:-https://sincro-ia-licencias.agustinhfernandez.workers.dev}"
LOG_FILE="${TMPDIR:-/tmp}/sincro-ia-install.log"

while [ $# -gt 0 ]; do
    case "$1" in
        --license)  LICENSE_KEY="$2"; shift 2 ;;
        --gemini)   GEMINI_KEY="$2";  shift 2 ;;
        --template) TEMPLATE_DIR="$2"; shift 2 ;;
        --install)  INSTALL_DIR="$2"; shift 2 ;;
        *) echo "Argumento desconocido: $1"; shift ;;
    esac
done

# --------------------------------------------------------------------
# Helpers de log + barra de progreso
# --------------------------------------------------------------------
C_CYAN='\033[36m'; C_GREEN='\033[32m'; C_YELLOW='\033[33m'; C_RED='\033[31m'; C_OFF='\033[0m'
STEP_N=0; STEP_TOTAL=8

: > "$LOG_FILE"
echo "Sincro IA - instalacion $(date)" >> "$LOG_FILE"

progress_bar() {  # $1 = label
    STEP_N=$((STEP_N + 1))
    local pct=$(( STEP_N * 100 / STEP_TOTAL ))
    local filled=$(( pct / 5 )) bar=""
    local i; for ((i=0;i<20;i++)); do [ $i -lt $filled ] && bar+="#" || bar+="-"; done
    printf "\n[%s] %3d%%  %s (%d/%d)\n" "$bar" "$pct" "$1" "$STEP_N" "$STEP_TOTAL"
}
step() { progress_bar "$1"; printf "${C_CYAN}=== %s ===${C_OFF}\n" "$1"; echo "=== $1 ===" >> "$LOG_FILE"; }
ok()   { printf "  ${C_GREEN}[OK]${C_OFF} %s\n" "$1"; echo "[OK] $1" >> "$LOG_FILE"; }
info() { printf "  %s\n" "$1"; echo "$1" >> "$LOG_FILE"; }
warn() { printf "  ${C_YELLOW}[!]${C_OFF} %s\n" "$1"; echo "[!] $1" >> "$LOG_FILE"; }
die()  { printf "\n  ${C_RED}[X]${C_OFF} %s\n" "$1"; echo "[X] $1" >> "$LOG_FILE"; echo "Log: $LOG_FILE"; exit 1; }

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# Detecta gestor de paquetes (para git/python si faltan). Usa sudo si hace falta.
PKG=""
detect_pkg() {
    if   have_cmd apt-get; then PKG="apt"
    elif have_cmd dnf;     then PKG="dnf"
    elif have_cmd pacman;  then PKG="pacman"
    elif have_cmd zypper;  then PKG="zypper"
    elif have_cmd brew;    then PKG="brew"
    fi
}
SUDO=""; [ "$(id -u)" -ne 0 ] && have_cmd sudo && SUDO="sudo"
pkg_install() {  # $1 = nombre de paquete
    case "$PKG" in
        apt)    $SUDO apt-get update -y >/dev/null 2>&1; $SUDO apt-get install -y "$1" >/dev/null 2>&1 ;;
        dnf)    $SUDO dnf install -y "$1" >/dev/null 2>&1 ;;
        pacman) $SUDO pacman -Sy --noconfirm "$1" >/dev/null 2>&1 ;;
        zypper) $SUDO zypper --non-interactive install "$1" >/dev/null 2>&1 ;;
        brew)   brew install "$1" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}
detect_pkg

# Instala VSCode (proporciona el CLI 'code', necesario para extensiones y 'code tunnel').
install_vscode() {
    case "$PKG" in
        apt)
            $SUDO apt-get install -y wget gpg apt-transport-https >/dev/null 2>&1
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/ms.gpg 2>/dev/null
            $SUDO install -D -o root -g root -m 644 /tmp/ms.gpg /etc/apt/keyrings/packages.microsoft.gpg 2>/dev/null
            echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | $SUDO tee /etc/apt/sources.list.d/vscode.list >/dev/null
            $SUDO apt-get update -y >/dev/null 2>&1; $SUDO apt-get install -y code >/dev/null 2>&1 ;;
        dnf)
            $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null
            printf '[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n' | $SUDO tee /etc/yum.repos.d/vscode.repo >/dev/null
            $SUDO dnf install -y code >/dev/null 2>&1 ;;
        zypper)
            $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null
            $SUDO zypper -n ar -f https://packages.microsoft.com/yumrepos/vscode vscode >/dev/null 2>&1
            $SUDO zypper -n install code >/dev/null 2>&1 ;;
        brew) brew install --cask visual-studio-code >/dev/null 2>&1 ;;
        *) : ;;
    esac
    # Fallback universal: snap
    if ! have_cmd code && have_cmd snap; then $SUDO snap install code --classic >/dev/null 2>&1; fi
    have_cmd code
}

# Instala y habilita el servidor SSH (para Remote-SSH y como acceso de servidor).
install_sshd() {
    case "$PKG" in
        apt)    pkg_install openssh-server ;;
        dnf)    pkg_install openssh-server ;;
        pacman) pkg_install openssh ;;
        zypper) pkg_install openssh ;;
        *) : ;;
    esac
    if have_cmd systemctl; then
        $SUDO systemctl enable --now sshd 2>/dev/null || $SUDO systemctl enable --now ssh 2>/dev/null || true
    fi
    have_cmd sshd || have_cmd /usr/sbin/sshd
}

echo
echo "###############################################"
echo "#         Sincro IA - Instalador (Linux)      #"
echo "###############################################"

# Gemini key opcional (la licencia NO se pide: en Linux es gratis y no bloquea)
[ -z "$GEMINI_KEY" ]  && read -rp "Gemini API key (opcional, Enter para omitir): " GEMINI_KEY

# ====================================================================
# FASE -1 : Licencia (no-bloqueante: Sincro IA es gratis)
#   Si pasas --license intenta validarla best-effort, pero nunca corta.
# ====================================================================
step "Licencia"
if ! have_cmd curl; then pkg_install curl || true; fi
if [ -n "$LICENSE_KEY" ] && have_cmd curl; then
    MACHINE_ID="$( (cat /etc/machine-id 2>/dev/null) || (cat /var/lib/dbus/machine-id 2>/dev/null) || hostname )"
    RESP="$(curl -s -X POST "$LICENSE_API/validate" \
            -H "Content-Type: application/json" \
            -d "{\"license_key\":\"$LICENSE_KEY\",\"machine_id\":\"$MACHINE_ID\"}" 2>>"$LOG_FILE")"
    if echo "$RESP" | grep -q '"valid":[[:space:]]*true'; then ok "Licencia valida"
    else warn "Licencia no validada (sigo igual, es gratis). Respuesta: $RESP"; fi
else
    ok "Sin licencia: instalacion gratuita, continuo."
fi

# ====================================================================
# FASE 0 : Prerrequisitos
# ====================================================================
step "FASE 0 - Prerrequisitos"

# Node.js >= 18 (via nvm, sin root, multi-distro)
node_major() { have_cmd node && node -v 2>/dev/null | sed -E 's/v([0-9]+).*/\1/' || echo 0; }
if [ "$(node_major)" -ge 18 ] 2>/dev/null; then
    ok "Node.js presente"
else
    info "Instalando Node.js LTS via nvm..."
    export NVM_DIR="$HOME/.nvm"
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash >>"$LOG_FILE" 2>&1
    fi
    # shellcheck disable=SC1090
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts >>"$LOG_FILE" 2>&1
    if [ "$(node_major)" -ge 18 ] 2>/dev/null; then ok "Node.js instalado"; else warn "No se pudo instalar Node.js. Instalalo manual: https://nodejs.org"; fi
fi

# Python >= 3.10
py_ok() { have_cmd python3 && python3 -c 'import sys; exit(0 if sys.version_info[:2] >= (3,10) else 1)' 2>/dev/null; }
if py_ok; then ok "Python presente"; else
    info "Instalando Python 3..."
    pkg_install python3 || true
    if py_ok; then ok "Python instalado"; else warn "Instala Python 3.10+ manual: https://www.python.org/downloads/"; fi
fi

# git
if have_cmd git; then ok "git presente"; else
    info "Instalando git..."; pkg_install git || true
    if have_cmd git; then ok "git instalado"; else warn "Instala git manual: https://git-scm.com/download/linux"; fi
fi

# VSCode (instalacion automatica: da el CLI 'code' para extensiones y 'code tunnel')
if have_cmd code; then ok "VSCode presente"; else
    info "Instalando VSCode..."
    if install_vscode; then ok "VSCode instalado"; else warn "No se pudo instalar VSCode automatico. Descarga: https://code.visualstudio.com"; fi
fi
if have_cmd code; then
    info "Instalando extension de Claude en VSCode..."
    code --install-extension anthropic.claude-code --force >>"$LOG_FILE" 2>&1 && ok "Extension de Claude en VSCode" || warn "No se pudo instalar la extension de Claude."
fi

# Servidor SSH (para Remote-SSH desde otra maquina y acceso de servidor)
if install_sshd; then ok "Servidor SSH habilitado (sshd)"; else warn "No se pudo configurar sshd automatico (instalalo manual: openssh-server)."; fi

# uv (gestor Python para graphify y notebooklm-py)
if have_cmd uv; then ok "uv presente"; else
    info "Instalando uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >>"$LOG_FILE" 2>&1
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if have_cmd uv; then ok "uv instalado"; else warn "No se pudo instalar uv: https://docs.astral.sh/uv/"; fi
fi

# Asegurar npm en PATH (nvm) para esta sesion
export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1 || true

# Claude Code CLI (npm global)
if have_cmd claude; then ok "Claude Code presente"; else
    info "Instalando Claude Code CLI..."
    if have_cmd npm; then
        npm install -g @anthropic-ai/claude-code </dev/null >>"$LOG_FILE" 2>&1
        if have_cmd claude; then ok "Claude Code instalado"; else warn "No se pudo instalar Claude Code CLI."; fi
    else warn "npm no disponible (falta Node). Claude Code no instalado."; fi
fi

# ====================================================================
# FASE 1 : Graphify + NotebookLM
# ====================================================================
step "FASE 1 - Graphify + NotebookLM"
if have_cmd uv; then
    uv tool install graphifyy </dev/null >>"$LOG_FILE" 2>&1 && ok "Graphify instalado" || warn "Graphify fallo (ver log)."
    uv tool install "notebooklm-py[browser]" </dev/null >>"$LOG_FILE" 2>&1 && ok "notebooklm-py instalado" || warn "notebooklm-py fallo (ver log)."
else
    warn "uv ausente: se omiten Graphify y notebooklm-py."
fi

# ====================================================================
# FASE 2 : Ruflo  (con timeout duro: init a veces espera input)
# ====================================================================
step "FASE 2 - Ruflo"
mkdir -p "$INSTALL_DIR"
if have_cmd npm; then
    ( cd "$INSTALL_DIR" && npm install -g ruflo@latest </dev/null >>"$LOG_FILE" 2>&1 )
    if have_cmd timeout; then
        ( cd "$INSTALL_DIR" && timeout 120 npx -y ruflo@latest init </dev/null >>"$LOG_FILE" 2>&1 )
        rc=$?
        if [ $rc -eq 124 ]; then warn "Ruflo init tardo demasiado; se omitio (Ruflo es secundario)."
        elif [ $rc -eq 0 ]; then ok "Ruflo instalado e inicializado en $INSTALL_DIR"
        else warn "Ruflo init devolvio codigo $rc (no critico)."; fi
    else
        ( cd "$INSTALL_DIR" && npx -y ruflo@latest init </dev/null >>"$LOG_FILE" 2>&1 ) && ok "Ruflo inicializado" || warn "Ruflo init fallo."
    fi
else
    warn "npm ausente: Ruflo no instalado."
fi

# ====================================================================
# FASE 3 : GSD
# ====================================================================
step "FASE 3 - GSD"
if have_cmd npx; then
    ( cd "$INSTALL_DIR" && npx -y @opengsd/gsd-core@latest --claude --local </dev/null >>"$LOG_FILE" 2>&1 ) && ok "GSD instalado" || warn "GSD fallo (ver log)."
else warn "npx ausente: GSD no instalado."; fi

# ====================================================================
# FASE 4 : Matt Pocock skills
# ====================================================================
step "FASE 4 - Matt Pocock skills"
if have_cmd npx; then
    ( cd "$INSTALL_DIR" && npx -y skills@latest add mattpocock/skills -y -a '*' -s '*' </dev/null >>"$LOG_FILE" 2>&1 ) && ok "Skills de Matt Pocock instaladas" || warn "Matt Pocock skills fallo (ver log)."
else warn "npx ausente: skills no instaladas."; fi

# ====================================================================
# FASE 5 : Capa B + .env
# ====================================================================
step "FASE 5 - Andamiaje Sincro IA (Capa B)"
[ -d "$TEMPLATE_DIR" ] || die "No se encontro la plantilla Capa B en $TEMPLATE_DIR"
cp -rf "$TEMPLATE_DIR/." "$INSTALL_DIR/"
ok "Capa B desplegada (CLAUDE.md, .mcp.json, scripts, skills propias)"

mkdir -p "$INSTALL_DIR/Workspace/Proyectos"

ENV_PATH="$INSTALL_DIR/.env"
{
    echo "# Sincro IA - credenciales locales (NO compartir, NO commitear)"
    echo "GEMINI_API_KEY=$GEMINI_KEY"
    echo "LICENSE_KEY=$LICENSE_KEY"
} > "$ENV_PATH"
chmod 600 "$ENV_PATH"
ok ".env escrito en $ENV_PATH"

# Lanzador de 'code tunnel' (acceso al VSCode de este servidor desde el navegador)
TUNNEL_SH="$INSTALL_DIR/iniciar-tunnel.sh"
cat > "$TUNNEL_SH" <<'EOF'
#!/usr/bin/env bash
# Expone el VSCode de este servidor via Microsoft Dev Tunnels.
# Primera vez pide login (GitHub/Microsoft). Luego acceder desde https://vscode.dev
exec code tunnel --accept-server-license-terms --name "sincro-ia"
EOF
chmod +x "$TUNNEL_SH"
if have_cmd code; then ok "Tunnel listo: ejecuta $TUNNEL_SH (o 'code tunnel')"; fi

# ====================================================================
# Cierre
# ====================================================================
step "Instalacion completa"
cat <<EOF

  Sincro IA quedo instalado en:
    $INSTALL_DIR

  PRIMER ARRANQUE (pasos que requieren tu navegador):
    1) cd "$INSTALL_DIR"
    2) claude            -> inicia sesion con tu cuenta de Anthropic.
    3) notebooklm login  -> inicia sesion en NotebookLM (abre el navegador).
    4) En Claude escribi:  "lee CLAUDE.md y arranca".

  USAR ESTE VSCODE COMO SERVIDOR (dos formas):
    A) Remote-SSH  -> desde otra PC: VSCode > "Connect to Host" > $(whoami)@$(hostname -I 2>/dev/null | awk '{print $1}')
                      (este equipo ya tiene sshd habilitado).
    B) code tunnel -> en este equipo corre:  $INSTALL_DIR/iniciar-tunnel.sh
                      (login la 1a vez) y entra desde https://vscode.dev en cualquier lado.

  Tu API key de Gemini ya quedo guardada. Internet es obligatorio.
  Si abriste una terminal nueva y no encontras 'node'/'npm', corre:  source ~/.bashrc
  Log de instalacion: $LOG_FILE
EOF

exit 0
