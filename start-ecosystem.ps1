# start-ecosystem.ps1
# Script para PowerShell: crea la red proxy-network y levanta los stacks

# Actualizar el repositorio automáticamente desde GitHub
Write-Host "🔄 Actualizando el repositorio desde GitHub..."
try {
    git pull --rebase
} catch {
    Write-Host "⚠️  No se pudo actualizar desde GitHub, se continúa con la ejecución."
}


# Crear la red solo si no existe
$networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern '^proxy-network$'
if (-not $networkExists) {
    Write-Host "🌐 Creando red proxy-network..."
    docker network create proxy-network
} else {
    Write-Host "✅ La red proxy-network ya existe."
}


# Menú interactivo para seleccionar stacks
$stacks = @()
if (Test-Path './docker-compose.yml') { $stacks += @{name='Principal'; path='.'} }
if (Test-Path './stack-ai/docker-compose.yml') { $stacks += @{name='stack-ai'; path='./stack-ai'} }
if (Test-Path './stack- sonarqube/docker-compose.yml') { $stacks += @{name='stack-sonarqube'; path='./stack- sonarqube'} }

Write-Host "¿Qué stacks quieres levantar?"
for ($i=0; $i -lt $stacks.Count; $i++) {
    Write-Host "$($i+1)) $($stacks[$i].name)"
}
Write-Host "A) Todos"
$choice = Read-Host "Selecciona una opción (ej: 1 2 o A para todos)"

if ($choice -eq 'A' -or $choice -eq 'a') {
    $selected = $stacks
} else {
    $selected = @()
    $nums = $choice -split ' '
    foreach ($n in $nums) {
        if ($n -match '^[0-9]+$' -and [int]$n -ge 1 -and [int]$n -le $stacks.Count) {
            $selected += $stacks[[int]$n-1]
        }
    }
}


# Levantar todos los stacks seleccionados excepto el principal (proxy-nginx)
foreach ($stack in $selected) {
    if ($stack.path -ne '.') {
        Write-Host "Levantando $($stack.name)..."
        Push-Location $stack.path
        docker compose up -d
        Pop-Location
    }
}
# Levantar el principal (proxy-nginx) al final si fue seleccionado
if ($selected | Where-Object { $_.path -eq '.' }) {
    Write-Host "🚀 Levantando stack principal (proxy-nginx)..."
    docker compose up -d
}

Write-Host "🎉 Todos los stacks levantados."
Write-Host "⏳ Comprobando el estado de los contenedores..."
Start-Sleep -Seconds 10
Write-Host "📦 Estado de los contenedores activos:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Comprobar contenedores definidos en los compose
$expectedContainers = @()
if (Test-Path './docker-compose.yml') {
    $expectedContainers += (docker compose ps --services)
}
if (Test-Path './stack-ai/docker-compose.yml') {
    $expectedContainers += (docker compose -f ./stack-ai/docker-compose.yml ps --services)
}
if (Test-Path './stack- sonarqube/docker-compose.yml') {
    $expectedContainers += (docker compose -f './stack- sonarqube/docker-compose.yml' ps --services)
}
$expectedContainers = $expectedContainers | Sort-Object -Unique

foreach ($svc in $expectedContainers) {
    $container = docker ps -a --filter "name=$svc" --format "{{.Names}}:{{.Status}}"
    if ($container -and ($container -notmatch 'Up')) {
        Write-Host "⚠️  El contenedor $svc no está levantado. Intentando iniciarlo..."
        docker start $svc | Out-Null
        Start-Sleep -Seconds 5
        $container2 = docker ps -a --filter "name=$svc" --format "{{.Names}}:{{.Status}}"
        if ($container2 -and ($container2 -notmatch 'Up')) {
            Write-Host "❌ El contenedor $svc sigue sin estar activo. Revise las trazas con: docker logs $svc"
        } else {
            Write-Host "✅ El contenedor $svc se ha iniciado correctamente."
        }
    }
}
