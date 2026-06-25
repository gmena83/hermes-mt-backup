# Infraestructura Menatech

## Máquinas

| ID | Nombre | OS | CPU | RAM | GPU | Almacenamiento | IP Tailscale | Rol |
|----|--------|-----|-----|-----|-----|----------------|-------------|-----|
| mt01 | La Forja | Windows | — | — | RTX 5070 Ti | — | 100.74.120.100 | ComfyUI, Obsidian host |
| mt02 | El Núcleo | Linux 6.17 | — | — | — | — | local | Hermes agentes, Ollama, Open WebUI |
| mt03 | La Bóveda | Linux (N100) | N100 | — | — | 1.8TB /mnt/multimedia | 100.101.141.63 | Samba, Borg backups, vault Obsidian |
| mt04 | El Vagabundo | Windows | — | — | — | — | variable | Portátil, cliente Obsidian |

## Red Tailscale

```
mt02 (El Núcleo) ←→ mt01 (La Forja)
      ↕                   
mt03 (La Bóveda) ←→ mt04 (El Vagabundo)
```

**Regla PULL-ONLY**: mt03 nunca recibe pushes. Solo inicia conexiones salientes (rsync PULL desde mt02, Borg local).

## Puertos y Servicios

| Servicio | Máquina | Puerto | Acceso |
|----------|---------|--------|--------|
| SSH | mt02 | 22 | local + Tailscale |
| SSH | mt03 | 22 | Tailscale |
| Ollama | mt02 | 11434 | localhost |
| Open WebUI | mt02 | 8080 | localhost |
| ComfyUI | mt01 | 8000 | Tailscale |
| Samba | mt03 | 445 | local |

## Montajes

| Origen | Destino | Tipo | Propósito |
|--------|---------|------|-----------|
| mt03:/mnt/multimedia/vault/menatech | /mnt/obsidian/menatech | SSHFS | Vault Obsidian agentes |
| mt03:/mnt/multimedia/vault/personal | /mnt/obsidian/personal | SSHFS | Vault Obsidian personal (Mónica, Mira) |
| mt03:/mnt/multimedia | /mnt/multimedia | Disco local | 1.8TB en mt03 |

## Backup Paths en mt03

| Path | Contenido | Tamaño |
|------|-----------|--------|
| /mnt/multimedia/backups/borg/mt02-pull | Backup diario de ~/.hermes/ + ~/.ssh/ desde mt02 | ~14 GB/archive |
| /mnt/multimedia/backups/borg/mt03-local | Snapshot vault menatech + backups/mt01 | ~ |
| /mnt/multimedia/backups/mt01/ | Backups de mt01 (robocopy) | — |
