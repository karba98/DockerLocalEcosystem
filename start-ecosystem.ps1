# start-ecosystem.ps1
# Script para PowerShell: crea la red proxy-network y levanta los stacks

# Crear la red solo si no existe
$networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern '^proxy-network$'
if (-not $networkExists) {
    Write-Host "🌐 Creando red proxy-network..."
    docker network create proxy-network
} else {
    Write-Host "✅ La red proxy-network ya existe."
}

# Levantar el stack principal
if (Test-Path './docker-compose.yml') {
    Write-Host "🚀 Levantando stack principal..."
    docker compose up -d
}

# Levantar stack-ai si existe
if (Test-Path './stack-ai/docker-compose.yml') {
    Write-Host "🤖 Levantando stack-ai..."
    Push-Location ./stack-ai
    docker compose up -d
    Pop-Location
}

# Levantar stack-sonarqube si existe
if (Test-Path './stack- sonarqube/docker-compose.yml') {
    Write-Host "🛡️ Levantando stack-sonarqube..."
    Push-Location './stack- sonarqube'
    docker compose up -d
    Pop-Location
}

Write-Host "🎉 Todos los stacks levantados."
