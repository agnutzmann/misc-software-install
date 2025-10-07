#!/bin/bash

STACKS_DIR="$HOME/stacks"
LOG_FILE="$HOME/docker-upgrade-$(date +%Y%m%d-%H%M).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Checks for malformed variables in .env files
check_env_file_for_interpolation() {
  echo "🔍 Checking for malformed variables in .env files..."

  local errors=0

  for env_file in $(find "$STACKS_DIR" -name ".env"); do
    if grep -E '\$\{[^}]+\}' "$env_file" > /dev/null; then
      echo "⚠️  Invalid interpolation detected in file: $env_file"
      grep -nE '\$\{[^}]+\}' "$env_file" | sed 's/^/   🔸 Line /'
      echo "   💡 Replace with static values (Docker Compose does not expand variables within values)"
      errors=$((errors + 1))
    fi
  done

  if [ "$errors" -gt 0 ]; then
    echo ""
    echo "❌ Correct the .env files before continuing the update."
    exit 1
  fi
}

# Run check before continuing
check_env_file_for_interpolation

# Start of execution
echo "📦 Starting update of all stacks in: $STACKS_DIR"
echo "============================================================"

cd "$STACKS_DIR" || exit 1

for stack in */ ; do
  echo ""
  echo "🔄 Updating stack: $stack"
  echo "------------------------------"

  cd "$STACKS_DIR/$stack" || continue

  if [ ! -f "docker-compose.yml" ] && [ ! -f "compose.yml" ]; then
    echo "⚠️  No docker-compose file found. Skipping..."
    cd "$STACKS_DIR"
    continue
  fi

  if grep -q "env_file" docker-compose.yml && [ ! -f ".env" ]; then
    echo "⚠️  .env file missing in $(pwd). Skipping stack..."
    cd "$STACKS_DIR"
    continue
  fi

  echo "🧯 Stopping containers..."
  docker compose down

  echo "⬇️  Pulling updated images..."
  docker compose pull

  echo "🚀 Starting up services..."
  docker compose up -d

  cd "$STACKS_DIR"
done

echo ""
echo "🧹 Pruning old unused images..."
docker image prune -af --force

echo ""
echo "✅ Update of all stacks completed!"
docker ps