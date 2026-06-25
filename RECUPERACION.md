# Procedimiento de Recuperación Post-Apagón

> **Leer esto primero** si hubo un corte de luz y las máquinas no volvieron como deberían.

## Resumen de Máquinas

| Máquina | Nombre | IP Tailscale | OS | Rol |
|---------|--------|-------------|-----|-----|
| mt01 | La Forja | 100.74.120.100 | Windows | Obsidian, ComfyUI:8000, RTX 5070 Ti |
| mt02 | El Núcleo | (local) | Linux | Hermes, Ollama, Open WebUI:8080, SSH server |
| mt03 | La Bóveda | 100.101.141.63 | Linux (N100) | Samba, Borg backups, /mnt/multimedia |
| mt04 | El Vagabundo | variable | Windows (laptop) | Portátil |

## 🔴 Fase 1 — Arrancar las máquinas

### mt02 (El Núcleo — prioridad #1)
```bash
# 1. Encender físicamente
# 2. Verificar que arrancó
ping localhost
# 3. Tailscale debe arrancar — verificar
tailscale status
# 4. Verificar que SSH server está corriendo (mt03 necesita conectarse vía SSH para PULL)
sudo systemctl status ssh
# Si no está corriendo:
sudo systemctl enable --now ssh
```

### mt03 (La Bóveda — prioridad #2)
```bash
# 1. Encender físicamente (N100)
# 2. Verificar Tailscale
tailscale status
# 3. Verificar discos — /mnt/multimedia debe estar montado
df -h /mnt/multimedia
# Si no está montado:
sudo mount /mnt/multimedia
```

### mt01 (La Forja — prioridad #3)
- Encender. Verificar Tailscale conectado.
- ComfyUI debería arrancar con el sistema si está configurado como servicio.

### mt04 (El Vagabundo)
- Encender. Conectar Tailscale manualmente.

## 🟡 Fase 2 — Restaurar desde Backup Borg

**Solo necesario si perdiste datos en mt02.** El backup está en mt03.

```bash
# Desde mt03: ver qué backups hay
borg list /mnt/multimedia/backups/borg/mt02-pull

# Extraer el último backup completo
LAST=$(borg list /mnt/multimedia/backups/borg/mt02-pull --last 1 --format '{name}')
mkdir -p /tmp/restore
cd /tmp/restore
borg extract /mnt/multimedia/backups/borg/mt02-pull::$LAST

# Copiar .hermes/ a mt02 (invertir PULL por única vez)
rsync -az /tmp/restore/home/gonzalo/mt03-stage/.hermes/ gonzalo@mt02:/home/gonzalo/.hermes/
rsync -az /tmp/restore/home/gonzalo/mt03-stage/.ssh/ gonzalo@mt02:/home/gonzalo/.ssh/
```

## 🟢 Fase 3 — Rearrancar los Gateways Hermes

### Gateway principal (alfred + sub-perfiles)
```bash
# En mt02
hermes --profile alfred gateway run --replace &
# Verificar
hermes --profile alfred gateway status
```

### Gateway menatech (token independiente)
```bash
hermes --profile menatech gateway run --replace &
```

### Gateway communitymanager (token independiente)
```bash
hermes --profile communitymanager gateway run --replace &
```

### Gateway menatech-test (token independiente)
```bash
# Verificar que no haya perfil duplicado con underscore
ls ~/.hermes/profiles/menatech*
hermes --profile menatech-test gateway run --replace &
```

## 🔵 Fase 4 — Montar Vaults Obsidian

```bash
# Los SOUL.md de los agentes incluyen instrucciones de dump al vault
# Si el SSHFS no está montado, los dumps fallan silenciosamente

# Montar vaults
sshfs mt03:/mnt/multimedia/vault/menatech /mnt/obsidian/menatech \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3

sshfs mt03:/mnt/multimedia/vault/personal /mnt/obsidian/personal \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3

# Verificar que responden
touch /mnt/obsidian/menatech/.write-test && rm /mnt/obsidian/menatech/.write-test && echo "✅ menatech OK"
touch /mnt/obsidian/personal/.write-test && rm /mnt/obsidian/personal/.write-test && echo "✅ personal OK"
```

## 🟣 Fase 5 — Verificar Cron Jobs

Los cron jobs críticos están registrados en el perfil `alfred`:
```bash
hermes --profile alfred cron list
```

Deben estar activos:
- **SSHFS Mount Watchdog** — cada 30 min
- **Monica Doc Sync** — 7am diario  
- **Borg PULL (mt03)** — 3am diario (corre en mt03, no en Hermes)
- **Borg local (mt03)** — 6am diario (corre en mt03)

## ⚡ Fase 6 — Si nada funciona y necesitás reconstruir desde GitHub

1. Clonar este repo: `git clone git@github.com:gmena83/menatech-docs.git`
2. Los SOUL.md están en `agentes/<nombre>/SOUL.md`
3. Copiarlos a `~/.hermes/profiles/<nombre>/SOUL.md`
4. Los scripts de backup están en `scripts/`
5. Crear perfiles nuevos si es necesario con `hermes profile init --profile <nombre>`

## Checklist Rápido

- [ ] mt02 encendido, SSH corriendo
- [ ] mt03 encendido, /mnt/multimedia montado
- [ ] mt01 encendido, Tailscale conectado
- [ ] Tailscale: los 4 nodos online
- [ ] Backups Borg verificados (`borg list`)
- [ ] Gateways Hermes corriendo (`hermes gateway status`)
- [ ] Vaults Obsidian montados y funcionales
- [ ] Cron jobs activos
