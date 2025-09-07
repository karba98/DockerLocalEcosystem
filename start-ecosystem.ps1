param(
    [switch]$SkipBuild,
    [switch]$BuildOnly,
    [switch]$NoPull,
    [switch]$NoCache,
    [string[]]$Stacks,
    [switch]$Auto
)

# Validaciones de parámetros
if ($SkipBuild -and $BuildOnly) {
    Write-Host "Parámetros incompatibles: -SkipBuild y -BuildOnly no pueden usarse juntos." -ForegroundColor Red
    exit 1
}
if ($SkipBuild -and ($NoCache -or $NoPull)) {
    Write-Host "Aviso: -SkipBuild ignora -NoCache y -NoPull." -ForegroundColor Yellow
}

# Modo automático: selecciona todos los stacks si no se pasó -Stacks
if ($Auto) {
    if (-not $Stacks -or $Stacks.Count -eq 0) { $Stacks = @('All') }
    Write-Host "Modo automático activado (-Auto)." -ForegroundColor Cyan
}

# start-ecosystem.ps1
# Script para PowerShell: crea la red proxy-network, opcionalmente construye imágenes y levanta los stacks

# Actualizar el repositorio automáticamente desde GitHub
Write-Host "Actualizando el repositorio desde GitHub..."
try {
    git pull --rebase
} catch {
    Write-Host "No se pudo actualizar desde GitHub, se continúa con la ejecución."
}


# Crear la red solo si no existe
$networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern '^proxy-network$'
if (-not $networkExists) {
    Write-Host "Creando red proxy-network..."
    docker network create proxy-network
} else {
    Write-Host "La red proxy-network ya existe."
}


# Descubrir stacks disponibles (usar nombre distinto a parámetro -Stacks para evitar colisión case-insensitive)
$allStacks = @()
if (Test-Path './docker-compose.yml') { $allStacks += @{name='Principal'; path='.'} }
if (Test-Path './stack-ai/docker-compose.yml') { $allStacks += @{name='stack-ai'; path='./stack-ai'} }
if (Test-Path './stack- sonarqube/docker-compose.yml') { $allStacks += @{name='stack-sonarqube'; path='./stack- sonarqube'} }

if ($Stacks -and $Stacks.Count -gt 0) {
    # Selección no interactiva
    $map = @{}
    foreach ($s in $allStacks) {
        $n = $s['name']
        if ($n) { $map[$n.ToLower()] = $s }
    }
    $selected = @()
    if ($Stacks | Where-Object { $_.ToLower() -eq 'all' -or $_.ToLower() -eq 'todos' }) {
        $selected = $allStacks
    } else {
        $validList = ($allStacks | ForEach-Object { $_['name'] }) -join ', '
        foreach ($raw in $Stacks) {
            $k = $raw.ToLower()
            if ($map.ContainsKey($k)) { $selected += $map[$k] } else {
                Write-Host "Aviso: stack '$raw' no reconocido. Opciones válidas: $validList o 'All'" -ForegroundColor Yellow
            }
        }
    }
    if (-not $selected -or $selected.Count -eq 0) {
        Write-Host "No se seleccionó ningún stack válido. Saliendo." -ForegroundColor Red
        return
    }
    $selNames = $selected | ForEach-Object { $_['name'] }
    Write-Host "Stacks seleccionados (modo no interactivo): $($selNames -join ', ')" -ForegroundColor Cyan
} else {
    Write-Host "¿Qué stacks quieres levantar?"
    for ($i=0; $i -lt $allStacks.Count; $i++) {
        Write-Host "$($i+1)) $($allStacks[$i]['name'])"
    }
    Write-Host "A) Todos"
    $choice = Read-Host "Selecciona una opción (ej: 1 2 o A para todos)"
    if ($choice -eq 'A' -or $choice -eq 'a') {
        $selected = $allStacks
    } else {
        $selected = @()
        $nums = $choice -split ' '
        foreach ($n in $nums) {
            if ($n -match '^[0-9]+$' -and [int]$n -ge 1 -and [int]$n -le $allStacks.Count) {
                $selected += $allStacks[[int]$n-1]
            }
        }
    }
}


# Build helper
function Invoke-StackBuild {
    param(
        [string]$StackPath,
        [string]$StackName
    )
    if ($SkipBuild) { return }
    if (-not (Test-Path (Join-Path $StackPath 'docker-compose.yml'))) { return }
    $flags = @()
    if (-not $NoPull) { $flags += '--pull' }
    if ($NoCache) { $flags += '--no-cache' }
    $flagStr = if ($flags.Count -gt 0) { $flags -join ' ' } else { '(sin flags)' }
    Write-Host "Construyendo imágenes para $StackName (docker compose build $flagStr)..." -ForegroundColor Cyan
    Push-Location $StackPath
    try {
        if ($flags.Count -gt 0) { docker compose build @flags } else { docker compose build }
    } catch {
        Write-Host "Fallo al construir imágenes en $StackName, se continúa: $($_.Exception.Message)" -ForegroundColor Yellow
    } finally { Pop-Location }
}

# Construir primero (excepto principal) si procede
foreach ($stack in $selected) {
    if ($stack.path -ne '.') {
        Invoke-StackBuild -StackPath $stack.path -StackName $stack.name
    }
}

# Construir principal al final si fue seleccionado
if ($selected | Where-Object { $_.path -eq '.' }) {
    Invoke-StackBuild -StackPath '.' -StackName 'principal'
}

if ($BuildOnly) {
    Write-Host "Se solicitó solo build (-BuildOnly). Fin." -ForegroundColor Green
    return
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
    Write-Host "Levantando stack principal (proxy-nginx)..."
    docker compose up -d
}

Write-Host "Todos los stacks levantados."
Write-Host "Comprobando el estado de los contenedores..."
Start-Sleep -Seconds 10
Write-Host "Estado de los contenedores activos:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

