# Stack Portainer 🛠️

Portainer CE para gestionar tus contenedores Docker. Se ejecuta como stack independiente.

## 🧩 Servicio
| Servicio | Imagen | Puerto | Persistencia |
|----------|--------|--------|--------------|
| portainer | portainer/portainer-ce:latest | 9100->9000, 9443->9443 | `portainer-data` |

## Uso
```bash
cd stack-portainer
docker compose up -d
```
Acceso: http://localhost:9100 (o 9443 HTTPS)

## Red
Usa la red externa `proxy-network`.

## Notas
- Primer acceso: crea usuario admin.
- Backup: volumen `portainer-data`.
