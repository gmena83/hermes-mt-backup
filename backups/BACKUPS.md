# Arquitectura de Backups Menatech

## Principio PULL-ONLY

**mt03 "La Bóveda" nunca recibe pushes.** Todas las transferencias las inicia mt03 haciendo PULL desde las otras máquinas. Esto evita que un error en mt01/mt02 sobreescriba datos en mt03.

Excepción controlada: el SSHFS del Obsidian vault desde mt02 es lectura/escritura — necesario para los dumps de agentes. No son backups de sistema, es contenido generado.

## Capa 1: Borg PULL mt02 → mt03 (diario 3am)

```
mt02 (Hermes, datos)          mt03 (Backups)
     │                              │
     │  ◄── SSH read-only ────      │  1. mt03 inicia conexión SSH a mt02
     │                              │
     │  ──── rsync PULL ────►       │  2. mt03 jala ~/.hermes/ + ~/.ssh/ vía rsync
     │                              │
     │                               │  3. Borg crea archive local
     │                               │  4. Borg prune (7d + 4w + 2m)
```

**Qué cubre**:
- Todos los perfiles Hermes (`~/.hermes/profiles/*/`)
- Skills, plugins, cron jobs, memorias
- Claves SSH (`~/.ssh/`)
- BBDD consolidado (~/.hermes/bbdd_consolidado/)
- **C:\Menatech de mt01** (vía mt01-gather.sh en mt02 → incluido en rsync)

**Qué excluye** (intencionalmente):
- `sessions/` — demasiado volátil, ~GBs
- `audio_cache/` — regenerable
- `comfyui-outputs/` — archivos grandes generados
- `venv/`, `node_modules/`, `.cache/`, `__pycache__/`

**Script**: `/home/gonzalo/mt03-pull-backup.sh` en mt03  
**Cron**: `0 3 * * *` en crontab de mt03  
**Repo**: `/mnt/multimedia/backups/borg/mt02-pull`

## Capa 1b: Recolección Windows mt01 → mt02 (domingo 1am)

```
mt01 (Windows)                mt02 (Linux)                mt03 (Backups)
     │                              │                           │
     │  ◄── SFTP (scp -r) ───       │  1. mt02 jala C:\Menatech │
     │                              │     vía scp                │
     │  ──── C:\Menatech ────►     │                           │
     │                              │  2. Stagea en             │
     │                              │     /home/gonzalo/         │
     │                              │     mt01-stage/            │
     │                              │                           │
     │                              │  ──── rsync PULL ────►   │  3. mt03 jala mt01-stage
     │                              │                           │     junto con .hermes/
```

**Script**: `mt01-gather.sh` en perfil alfred de mt02  
**Cron**: domingo 1:00 AM AST (antes del PULL de mt03 a las 3am)  
**Stage**: `/home/gonzalo/mt01-stage/` en mt02  
**Método**: `scp -r` desde mt02 → mt01 (SSH Windows OpenSSH)

## Capa 2: Borg local mt03 (diario 6am)

Snapshot de los datos LOCALES en mt03 después de que llegaron los backups:
- `/mnt/multimedia/vault/menatech` (el vault Obsidian completo)
- `/mnt/multimedia/backups/mt01` (backups de mt01 vía robocopy)

**Script**: `/home/gonzalo/.hermes/scripts/borg-backup-mt03-local.sh` en mt03  
**Cron**: `0 6 * * *` en crontab de mt03  
**Repo**: `/mnt/multimedia/backups/borg/mt03-local`  
**Retención**: 7d + 4w + 6m

## Capa 3: GitHub — Documentos críticos (off-site)

Repo privado `hermes-mt-backup` con:
- SOUL.md de los 11 agentes
- Infraestructura, bots, backups documentados
- Script de recuperación
- Procedimiento de recuperación paso a paso

**Actualización**: diario 9am vía `sync-souls-to-github.sh`

## Cronograma completo

| Hora | Día | Job | Máquina |
|------|-----|-----|---------|
| 1:00 AM | Domingo | mt01-gather (scp C:\Menatech) | mt02 |
| 3:00 AM | Diario | Borg PULL mt02→mt03 | mt03 |
| 6:00 AM | Diario | Borg local mt03 | mt03 |
| 7:00 AM | Diario | Monica Doc Sync | mt02 (cron Hermes) |
| 9:00 AM | Diario | GitHub Sync SOUL.md | mt02 (cron Hermes) |
| 10:00 AM | Diario | Verificación expandida | mt02 (cron Hermes) |
| cada 30min | Siempre | SSHFS Mount Watchdog | mt02 (cron Hermes) |
| 3:00 AM | Domingo | Housekeeping logs | mt02 (cron Hermes) |

## Verificación

```bash
# Verificar último backup mt02 → mt03
ssh mt03 "borg list /mnt/multimedia/backups/borg/mt02-pull --last 1"

# Verificar que mt01-stage está en el backup
ssh mt03 "borg list /mnt/multimedia/backups/borg/mt02-pull --last 1 --format '{name}' | xargs -I{} borg list /mnt/multimedia/backups/borg/mt02-pull::{} --format '{path}{NL}' | grep mt01-menatech"

# Verificar integridad del repo
ssh mt03 "borg check /mnt/multimedia/backups/borg/mt02-pull"

# Verificar espacio
ssh mt03 "df -h /mnt/multimedia"
```
