#!/bin/bash
# start-ecosystem.sh
# Script para crear la red proxy-network, construir imágenes opcionalmente y levantar stacks seleccionados.
set -euo pipefail

# --- Parsing de argumentos ---
SKIP_BUILD=0
BUILD_ONLY=0
NO_PULL=0
NO_CACHE=0
AUTO=0
LIST=0
STACKS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -SkipBuild|--skip-build) SKIP_BUILD=1; shift ;;
    -BuildOnly|--build-only) BUILD_ONLY=1; shift ;;
    -NoPull|--no-pull) NO_PULL=1; shift ;;
    -NoCache|--no-cache) NO_CACHE=1; shift ;;
    -Auto|--auto) AUTO=1; shift ;;
    -Stacks|--stacks)
      shift
      while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^- ]]; do
        STACKS+=("$1"); shift
      done
      ;;
  -List|--list) LIST=1; shift ;;
    -h|--help)
      echo "Uso: $0 [opciones]\n"
      echo "Opciones:"; echo "  -Stacks <nombres>   Selecciona stacks (Principal stack-ai stack-sonarqube All)"; \
      echo "  -Auto                Selecciona todos"; \
      echo "  -SkipBuild           No construye"; \
      echo "  -BuildOnly           Solo construye y sale"; \
      echo "  -NoPull              No ejecuta --pull en build"; \
      echo "  -NoCache             Fuerza --no-cache"; \
  echo "  -List                Lista stacks disponibles y sale"; \
      echo "  -h/--help            Ayuda"; exit 0 ;;
    *) echo "Argumento no reconocido: $1"; exit 1 ;;
  esac
done

if [[ $SKIP_BUILD -eq 1 && $BUILD_ONLY -eq 1 ]]; then
  echo "Parámetros incompatibles: -SkipBuild y -BuildOnly" >&2
  exit 1
fi

# Listar stacks y salir si se pasó -List
if [[ $LIST -eq 1 ]]; then
  echo "Stacks disponibles:" 
  # Reconstruir arrays aquí porque la lógica de descubrimiento viene después si se cambia el orden
fi

# --- Actualizar repo ---
echo "Actualizando el repositorio desde GitHub..."
if ! git pull --rebase; then
  echo "No se pudo actualizar desde GitHub, se continúa."
fi

# --- Red docker ---
if ! docker network ls --format '{{.Name}}' | grep -q '^proxy-network$'; then
  echo "Creando red proxy-network..."
  docker network create proxy-network
else
  echo "La red proxy-network ya existe."
fi

# --- Descubrir stacks ---
stacks=()
stack_names=()
if [ -f docker-compose.yml ]; then stacks+=( "." ); stack_names+=("Principal"); fi
if [ -f stack-ai/docker-compose.yml ]; then stacks+=("stack-ai"); stack_names+=("stack-ai"); fi
if [ -f "stack- sonarqube/docker-compose.yml" ]; then stacks+=("stack- sonarqube"); stack_names+=("stack-sonarqube"); fi

if [[ $LIST -eq 1 ]]; then
  for i in "${!stack_names[@]}"; do
    idx=$((i+1)); echo "[$idx] ${stack_names[$i]} -> ${stacks[$i]}"
  done
  echo "Use -Stacks <nombres> o -Auto para selección no interactiva." 
  exit 0
fi

declare -A map
for i in "${!stacks[@]}"; do
  key=${stack_names[$i],,}
  map[$key]=${stacks[$i]}
done

# --- Selección ---
selected=()
if [[ $AUTO -eq 1 && ${#STACKS[@]} -eq 0 ]]; then
  STACKS=(All)
fi

if [[ ${#STACKS[@]} -gt 0 ]]; then
  lower() { echo "$1" | tr '[:upper:]' '[:lower:]'; }
  has_all=0
  for s in "${STACKS[@]}"; do
    ls=$(lower "$s")
    if [[ $ls == "all" || $ls == "todos" ]]; then has_all=1; fi
  done
  if [[ $has_all -eq 1 ]]; then
    selected=("${stacks[@]}")
  else
    for s in "${STACKS[@]}"; do
      ls=$(lower "$s")
      if [[ -n ${map[$ls]:-} ]]; then
        selected+=("${map[$ls]}")
      else
        echo "Aviso: stack '$s' no reconocido." >&2
      fi
    done
  fi
  if [[ ${#selected[@]} -eq 0 ]]; then
    echo "No se seleccionó ningún stack válido." >&2
    exit 1
  fi
  echo "Stacks seleccionados (no interactivo): ${STACKS[*]}"
else
  echo
  echo "¿Qué stacks quieres levantar?"
  for i in "${!stack_names[@]}"; do
    idx=$((i+1)); echo "$idx) ${stack_names[$i]}"
  done
  echo "A) Todos"
  read -p "Selecciona una opción (ej: 1 2 o A para todos): " choice
  if [[ $choice =~ [Aa] ]]; then
    selected=("${stacks[@]}")
  else
    for n in $choice; do
      if [[ $n =~ ^[0-9]+$ ]] && (( n >=1 && n <= ${#stacks[@]} )); then
        selected+=("${stacks[$((n-1))]}")
      fi
    done
  fi
fi

# --- Build helper ---
build_stack() {
  local path="$1"; local name="$2"
  [[ $SKIP_BUILD -eq 1 ]] && return 0
  if [[ ! -f "$path/docker-compose.yml" ]]; then return 0; fi
  local flags=()
  [[ $NO_PULL -eq 0 ]] && flags+=(--pull)
  [[ $NO_CACHE -eq 1 ]] && flags+=(--no-cache)
  echo "Construyendo imágenes para $name (docker compose build ${flags[*]:-(sin flags)})" | sed 's/  / /g'
  ( cd "$path" && docker compose build "${flags[@]}" ) || echo "Fallo build $name (continuando)"
}

# --- Build (secundarios primero) ---
for idx in "${!selected[@]}"; do
  p=${selected[$idx]}
  if [[ $p != "." ]]; then
    n="${p}"; [[ $p == "stack- sonarqube" ]] && n="stack-sonarqube"
    build_stack "$p" "$n"
  fi
done

# Principal después
for p in "${selected[@]}"; do
  if [[ $p == "." ]]; then build_stack "." "principal"; fi
done

if [[ $BUILD_ONLY -eq 1 ]]; then
  echo "Se solicitó solo build (-BuildOnly). Fin."; exit 0
fi

# --- Levantar stacks secundarios ---
for p in "${selected[@]}"; do
  if [[ $p != "." ]]; then
    echo "Levantando $p..."
    ( cd "$p" && docker compose up -d )
  fi
done

# --- Principal al final ---
for p in "${selected[@]}"; do
  if [[ $p == "." ]]; then
    echo "Levantando stack principal..."
    docker compose up -d
  fi
done

echo "Todos los stacks levantados."
echo "Esperando 10 segundos para comprobar el estado de los contenedores..."
sleep 10
echo "Estado de los contenedores activos:"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

