#!/bin/bash
# Menatech — Recuperación automática de gateways tras apagón
# ----------------------------------------------------------
# Uso: bash menatech-recover.sh
# Asume: mt02 encendido, Tailscale funcionando, mt03 accesible vía SSH
# NO requiere Hermes corriendo — usa comandos directos

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

check() { 
    if [ $? -eq 0 ]; then echo -e "${GREEN}✅ $1${NC}"; else echo -e "${RED}❌ $1${NC}"; fi 
}

echo "================================================"
echo "  MENATECH RECOVERY $(date +%Y-%m-%d)"
echo "================================================"
echo ""

# ---- Fase 1: Conectividad ----
echo "=== FASE 1: Conectividad ==="

# Tailscale
tailscale status > /dev/null 2>&1
check "Tailscale corriendo"

# mt03
ssh -o ConnectTimeout=5 mt03 "echo OK" > /dev/null 2>&1
check "SSH a mt03"

# ---- Fase 2: Montajes ----
echo ""
echo "=== FASE 2: Montajes Obsidian ==="

for mp in /mnt/obsidian/menatech /mnt/obsidian/personal; do
    if mountpoint -q "$mp" 2>/dev/null; then
        touch "$mp/.write-test" 2>/dev/null && rm -f "$mp/.write-test" && echo -e "${GREEN}✅ $mp OK${NC}" || {
            echo -e "${YELLOW}⚠️  $mp STALE — remontando...${NC}"
            fusermount -uz "$mp" 2>/dev/null
            sleep 2
        }
    fi
    
    if ! mountpoint -q "$mp" 2>/dev/null; then
        if [ "$mp" = "/mnt/obsidian/menatech" ]; then
            src="mt03:/mnt/multimedia/vault/menatech"
        else
            src="mt03:/mnt/multimedia/vault/personal"
        fi
        sshfs "$src" "$mp" -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3
        check "Montado $mp"
    fi
done

# ---- Fase 3: Gateways Hermes ----
echo ""
echo "=== FASE 3: Gateways Hermes ==="

# Detener gateways existentes (si hay)
pkill -f "hermes.*gateway run" 2>/dev/null && sleep 2 || true

# Gateway principal: alfred + sub-perfiles
echo "Iniciando alfred..."
nohup hermes --profile alfred gateway run > /home/gonzalo/.hermes/profiles/alfred/logs/gateway.log 2>&1 &
sleep 5
pgrep -f "alfred.*gateway" > /dev/null 2>&1
check "Gateway alfred"

# Gateway menatech
echo "Iniciando menatech..."
nohup hermes --profile menatech gateway run --replace > /home/gonzalo/.hermes/profiles/menatech/logs/gateway.log 2>&1 &
sleep 3
pgrep -f "menatech.*gateway" > /dev/null 2>&1
check "Gateway menatech"

# Gateway communitymanager
echo "Iniciando communitymanager..."
nohup hermes --profile communitymanager gateway run --replace > /home/gonzalo/.hermes/profiles/communitymanager/logs/gateway.log 2>&1 &
sleep 3
pgrep -f "communitymanager.*gateway" > /dev/null 2>&1
check "Gateway communitymanager"

echo ""
echo "================================================"
echo "  RECUPERACIÓN COMPLETA"
echo "================================================"
echo ""
echo "📋 Verificaciones post-recuperación:"
echo "  1. Revisar logs: tail -f ~/.hermes/profiles/*/logs/gateway.log"
echo "  2. Telegram: cada bot debería responder"
echo "  3. Backups en mt03: borg list /mnt/multimedia/backups/borg/mt02-pull"
echo ""
