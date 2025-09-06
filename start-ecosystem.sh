#!/bin/bash
# Script para crear la red proxy-network y levantar todos los stacks

set -e

# Crear la red solo si no existe
if ! docker network ls --format '{{.Name}}' | grep -q '^proxy-network$'; then
  echo "🌐 Creando red proxy-network..."
  docker network create proxy-network
else
  echo "✅ La red proxy-network ya existe."
fi

# Levantar el stack principal
if [ -f docker-compose.yml ]; then
  echo "🚀 Levantando stack principal..."
  docker compose up -d
fi

# Levantar stack-ai si existe
if [ -f stack-ai/docker-compose.yml ]; then
  echo "🤖 Levantando stack-ai..."
  (cd stack-ai && docker compose up -d)
fi

# Levantar stack-sonarqube si existe
if [ -f "stack- sonarqube/docker-compose.yml" ]; then
  echo "🛡️ Levantando stack-sonarqube..."
  (cd "stack- sonarqube" && docker compose up -d)
fi

echo "🎉 Todos los stacks levantados."
