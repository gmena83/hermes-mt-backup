# Menatech — Documentación de Supervivencia

Repositorio off-site con todo lo necesario para reconstruir el ecosistema Menatech desde cero.

**Actualizado**: 2026-06-25  
**Mantenedor**: Alfred (alfred@menatech.io)

## 📁 Estructura

```
menatech-docs/
├── agentes/              # SOUL.md de cada bot
│   ├── alfred/
│   ├── consigliere/
│   ├── ghostwriter/
│   ├── matrix/
│   ├── vibecoder/
│   ├── comfyui-bot/
│   ├── communitymanager/
│   ├── menatech/
│   ├── menatech-test/
│   ├── monica-bot/
│   └── mira/
├── infraestructura/      # Hardware, red, IPs
├── backups/              # Arquitectura de backups
├── scripts/              # Scripts de recuperación
└── RECUPERACION.md       # Procedimiento paso a paso
```

## 🚨 Recuperación rápida

Si hubo apagón o desastre, empezar por [RECUPERACION.md](RECUPERACION.md).

Los SOUL.md en `agentes/` contienen las definiciones completas de personalidad de cada bot. Si un perfil Hermes se corrompe, reemplazá su `SOUL.md` con el de este repo y reiniciá el gateway.
