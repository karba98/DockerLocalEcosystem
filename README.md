## Instalación y arranque del ecosistema

1. Asegúrate de tener Docker y Docker Compose instalados.

2. Clona este repositorio y sitúate en la raíz del proyecto.

3. Crea la red necesaria y levanta todos los stacks ejecutando uno de estos scripts según tu sistema:

### En Linux/Mac/WSL:
```bash
bash start-ecosystem.sh
```

### En Windows (PowerShell):
```powershell
./start-ecosystem.ps1
```

Esto creará la red `proxy-network` si no existe y levantará todos los servicios definidos en los distintos docker-compose.

---

### Para actualizar la configuración de nginx sin reiniciar el contenedor:
```bash
docker exec proxy-nginx nginx -s reload
```