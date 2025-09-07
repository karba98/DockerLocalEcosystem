#!/bin/bash
# Script para crear la red proxy-network y levantar todos los stacks

set -e

# Actualizar el repositorio automáticamente desde GitHub
echo "Actualizando el repositorio desde GitHub..."
if ! git pull --rebase; then
  echo "No se pudo actualizar desde GitHub, se continúa con la ejecución."
fi

# Crear la red solo si no existe
if ! docker network ls --format '{{.Name}}' | grep -q '^proxy-network$'; then
  echo "Creando red proxy-network..."
  docker network create proxy-network
else
  echo "La red proxy-network ya existe."
fi

# Menú interactivo para seleccionar stacks
stacks=()
stack_names=()
if [ -f docker-compose.yml ]; then stacks+=( "." ); stack_names+=("Principal"); fi
if [ -f stack-ai/docker-compose.yml ]; then stacks+=("stack-ai"); stack_names+=("stack-ai"); fi
if [ -f "stack- sonarqube/docker-compose.yml" ]; then stacks+=("stack- sonarqube"); stack_names+=("stack-sonarqube"); fi

echo
echo "¿Qué stacks quieres levantar?"
for i in "${!stack_names[@]}"; do
  idx=$((i+1))
  echo "$idx) ${stack_names[$i]}"
done
echo "A) Todos"
read -p "Selecciona una opción (ej: 1 2 o A para todos): " choice

selected=()
if [[ "$choice" =~ [Aa] ]]; then
  selected=("${stacks[@]}")
else
  for n in $choice; do
    if [[ $n =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#stacks[@]} )); then
      selected+=("${stacks[$((n-1))]}")
    fi
  done
fi

# Separar stacks seleccionados en principal y el resto
principal_in_seleccion=0
resto=()
for stack in "${selected[@]}"; do
  if [ "$stack" = "." ]; then
    principal_in_seleccion=1
  else
    resto+=("$stack")
  fi
done

# Levantar primero los stacks secundarios
for stack in "${resto[@]}"; do
  echo "Levantando $stack..."
  (cd "$stack" && docker compose up -d)
done

# Levantar el principal al final si fue seleccionado
if [ $principal_in_seleccion -eq 1 ]; then
  echo "Levantando stack principal..."
  docker compose up -d
fi

echo "Todos los stacks levantados."
echo "Esperando 10 segundos para comprobar el estado de los contenedores..."
sleep 10
echo "Estado de los contenedores activos:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

