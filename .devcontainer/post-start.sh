#!/bin/bash
# Changes from upstream Anthropic template (github.com/anthropics/claude-code/tree/main/.devcontainer):
#   - Added: -exist flag to all ipset add commands (prevents errors on duplicate entries)
#   - Added: TCP DNS outbound rule (port 53/tcp) for large DNS response fallback
#   - Added: Copilot/GitHub domains to allowlist
#   - Fixed: Removed duplicate domains
#   - Fixed: Removed trailing space in "o33249.ingest.sentry.io "
#   - Fixed: DNS resolution failure now warns instead of exit 1 (CDN domains are CNAME-only)
#   - Fixed: Invalid IP in loop uses continue instead of exit 1
#   - Added: VS Code WebView/Service Worker domains
#   - Added: Groq, Anthropic, npm registry domains
set -euo pipefail

IFS=$'\n\t'

# ─── 1. Extrair regras DNS do Docker ANTES de limpar ─────────────────────────
DOCKER_DNS_RULES=$(iptables-save -t nat | grep "127\.0\.0\.11" || true)

# ─── 2. Limpar regras e ipsets existentes ────────────────────────────────────
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

# ─── 3. Restaurar DNS interno do Docker ──────────────────────────────────────
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "Restoring Docker DNS rules..."
    iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
    iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
    echo "$DOCKER_DNS_RULES" | xargs -L 1 iptables -t nat
else
    echo "No Docker DNS rules to restore"
fi

# ─── 4. Regras base: DNS, SSH, localhost ─────────────────────────────────────
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 18789 -j ACCEPT
iptables -A INPUT  -p tcp --sport 18789 -m state --state ESTABLISHED -j ACCEPT
iptables -A INPUT  -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# ─── 5. Criar ipset ──────────────────────────────────────────────────────────
ipset create allowed-domains hash:net

# ─── 5.1 Regra temporária para permitir HTTPS durante bootstrap ──────────────
# Necessário para curl buscar ranges do GitHub antes do ipset estar populado
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT
iptables -A OUTPUT -p tcp --dport 18789  -j ACCEPT
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "Processing GitHub IPs..."
while read -r cidr; do
    if [[ ! "$cidr" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "ERROR: Invalid CIDR range from GitHub meta: $cidr"
        exit 1
    fi
    echo "Adding GitHub range $cidr"
    ipset add allowed-domains "$cidr" -exist
done < <(echo "$ " | jq -r '(.web + .api + .git)[]' | aggregate -q)



# ─── 7. IPs estáticos adicionais ─────────────────────────────────────────────
for ip in \
    "104.18.0.0/16" \
    "172.64.0.0/13" \
    "140.82.112.5" \
    "140.82.114.6"; do
    echo "Adding static IP $ip"
    ipset add allowed-domains "$ip" -exist
done

# ─── 8. Domínios permitidos (sem duplicatas) ─────────────────────────────────
ALLOWED_DOMAINS=(

    # OpenAI Codex / API
    "api.openai.com"
    "codex.openai.com"
    "openai.com"
    "platform.openai.com"
    "auth0.openai.com"
    "cdn.auth0.com"
    "challenges.cloudflare.com"
    "auth.openai.com"
    "cdn.oaistatic.com"
    "persistent.oaistatic.com"
    "chatgpt.com"

    # GitHub
    "api.github.com"
    "github.com"
    "raw.githubusercontent.com"
    "objects.githubusercontent.com"
    "githubusercontent.com"
    "copilot-proxy.githubusercontent.com"
    "origin-tracker.githubusercontent.com"
    "copilot-telemetry.githubusercontent.com"
    "collector.github.com"
    "chat.openai.com"    
    "cdn.oaistatic.com"
    "persistent.oaistatic.com"
    "files.oaiusercontent.com"
    "chatgptusercontent.com"
    "ab.chatgpt.com"


    # npm
    "registry.npmjs.org"

    # Anthropic / Claude
    "api.anthropic.com"
    "statsig.anthropic.com"

    # Groq
    "api.groq.com"

    # Microsoft / VS Code marketplace e updates
    "login.microsoftonline.com"
    "mobile.events.data.microsoft.com"
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"
    "gallerycdn.vsassets.io"
    "vscode-cdn.net"
    "cdn1.vsassets.io"
    "cdn2.vsassets.io"
    "az764295.vo.msecnd.net"
    "download.visualstudio.microsoft.com"
    "dc.services.visualstudio.com"
    "visualstudio-devdiv-c2s.msedge.net"

    # VS Code sync e WebView / Service Worker
    "vscode-sync.trafficmanager.net"
    "vscode-sync-insiders.trafficmanager.net"
    "wus2.vscode-unpkg.net"
    "vscode.dev"
    "insiders.vscode.dev"

)

# ─── 8.1 Remover regras temporárias de bootstrap ────────────────────────────
(
    IDLE_TIME=0
    CHECK_INTERVAL=30
    MAX_IDLE=300

    while true; do
        if ss -tan state established '( dport = :443 or dport = :80 )' 2>/dev/null | grep -q ESTAB; then
            IDLE_TIME=0
        else
            IDLE_TIME=$((IDLE_TIME + CHECK_INTERVAL))
        fi

        if [ "$IDLE_TIME" -ge "$MAX_IDLE" ]; then
            echo "No HTTP/HTTPS connections for 5 minutes. Removing bootstrap rules..."

            iptables -D OUTPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
            iptables -D OUTPUT -p tcp --dport 80  -j ACCEPT 2>/dev/null || true
            iptables -D OUTPUT -p tcp --dport 18789  -j ACCEPT 2>/dev/null || true

            iptables -D INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

            break
        fi

        sleep "$CHECK_INTERVAL"
    done
) &

# ─── 9. Resolver e adicionar domínios ────────────────────────────────────────
for domain in "${ALLOWED_DOMAINS[@]}"; do
    echo "Resolving $domain..."
    ips=$(dig +noall +answer A "$domain" | awk '$4 == "A" {print $5}')

    if [ -z "$ips" ]; then
        echo "WARNING: No A records for $domain — skipping"
        continue
    fi

    while read -r ip; do
        if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "WARNING: Invalid IP from DNS for $domain: $ip — skipping"
            continue
        fi
        echo "Adding $ip for $domain"
        ipset add allowed-domains "$ip" -exist
    done < <(echo "$ips")
done

# ─── 10. Detectar rede do host ───────────────────────────────────────────────
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -z "$HOST_IP" ]; then
    echo "ERROR: Failed to detect host IP"
    exit 1
fi

HOST_NETWORK=$(echo "$HOST_IP" | sed "s/\.[0-9]*$/.0\/24/")
echo "Host network detected as: $HOST_NETWORK"

iptables -A INPUT  -s "$HOST_NETWORK" -j ACCEPT
iptables -A OUTPUT -d "$HOST_NETWORK" -j ACCEPT


# ─── 10.1 Garantir acesso explícito ao host na porta 18789 (WebSocket) ──────
# host.docker.internal normalmente resolve para o mesmo IP do gateway padrão
# (HOST_IP, calculado na seção 10). A regra de HOST_NETWORK já libera esse
# range inteiro, mas aqui fixamos a porta explicitamente por clareza e para
# não depender de o serviço estar na mesma sub-rede /24.
echo "Adding explicit rule for host WebSocket service on port 18789..."
iptables -A OUTPUT -d "$HOST_IP" -p tcp --dport 18789 -j ACCEPT
iptables -A INPUT  -s "$HOST_IP" -p tcp --sport 18789 -m state --state ESTABLISHED -j ACCEPT

# Se o container resolver "host.docker.internal" para outro IP (ex: Docker
# Desktop no Mac/Windows usa um IP virtual dedicado), garanta que ele também
# está liberado:
if getent hosts host.docker.internal >/dev/null 2>&1; then
    HDI_IP=$(getent hosts host.docker.internal | awk '{print $1}' | head -n1)
    if [[ "$HDI_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && [ "$HDI_IP" != "$HOST_IP" ]; then
        echo "Adding host.docker.internal IP $HDI_IP for port 18789"
        iptables -A OUTPUT -d "$HDI_IP" -p tcp --dport 18789 -j ACCEPT
        iptables -A INPUT  -s "$HDI_IP" -p tcp --sport 18789 -m state --state ESTABLISHED -j ACCEPT
    fi
fi

# ─── 11. Políticas padrão DROP ───────────────────────────────────────────────
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  DROP

# ─── 12. Permitir conexões estabelecidas e tráfego autorizado ────────────────
iptables -A INPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A INPUT  -j DROP

# ─── 13. Verificação final ───────────────────────────────────────────────────
echo "🛡️ Firewall configuration complete"
sleep 2 
clear
exec "$@"