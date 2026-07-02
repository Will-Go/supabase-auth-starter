#!/usr/bin/env bash
set -euo pipefail

# Supabase Auth PKCE Jump Starter — scaffold script
# Usage:
#   ./scripts/scaffold.sh my-app              # new Next.js 16 project
#   ./scripts/scaffold.sh --into ./existing   # overlay into existing project
#
# Phases:
#   1. Create or validate project
#   2. Install all dependencies (pnpm, --ignore-scripts)
#   3. Apply scaffold files + i18n/next.config configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$STARTER_DIR/templates"
CORE_DIR="$TEMPLATES_DIR/core"
PLACEHOLDERS_DIR="$TEMPLATES_DIR/placeholders"
CONFIG_DIR="$TEMPLATES_DIR/config"
MANIFEST="$TEMPLATES_DIR/manifests/customize.json"

INTO=""
LOCALE="es"
DRY_RUN=false
FORCE=false
SKIP_INSTALL=false
PROJECT_NAME=""
TARGET_DIR=""

AUTH_DEPS=(
  "@supabase/ssr"
  "@supabase/supabase-js"
  "@tanstack/react-query"
  "axios"
  "clsx"
  "next-intl"
  "react-hook-form"
  "@hookform/resolvers"
  "sonner"
  "tailwind-merge"
  "zod"
)

log() { echo "[supabase-auth-starter] $*" >&2; }
warn() { echo "[supabase-auth-starter] WARNING: $*" >&2; }
die() { echo "[supabase-auth-starter] ERROR: $*" >&2; exit 1; }

run() {
  if $DRY_RUN; then
    echo "[dry-run] $*" >&2
  else
    "$@"
  fi
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options] <project-name>
  $(basename "$0") --into <path> [options]

Options:
  --into <path>     Scaffold into an existing Next.js project
  --locale <code>   Default locale (default: es)
  --force           Overwrite existing files
  --dry-run         Print actions without executing
  --skip-install    Skip dependency installation (file copy only)
  -h, --help        Show this help

Examples:
  $(basename "$0") my-app
  $(basename "$0") --into ./existing-app --locale en
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --into)
        INTO="$2"
        shift 2
        ;;
      --locale)
        LOCALE="$2"
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --skip-install)
        SKIP_INSTALL=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        die "Unknown option: $1"
        ;;
      *)
        if [[ -n "$PROJECT_NAME" ]]; then
          die "Unexpected argument: $1"
        fi
        PROJECT_NAME="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$INTO" && -z "$PROJECT_NAME" ]]; then
    usage
    die "Provide a project name or --into <path>"
  fi

  if [[ -n "$INTO" && -n "$PROJECT_NAME" ]]; then
    die "Use either project name or --into, not both"
  fi
}

require_pnpm() {
  if ! command -v pnpm &>/dev/null; then
    die "pnpm is required. Install: https://pnpm.io/installation"
  fi
}

apply_template_vars() {
  local file="$1"
  sed -i '' "s/{{LOCALE}}/$LOCALE/g" "$file" 2>/dev/null || sed -i "s/{{LOCALE}}/$LOCALE/g" "$file"
  sed -i '' "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file" 2>/dev/null || sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$file"
}

copy_file() {
  local src="$1"
  local dest="$2"
  local always_overwrite="${3:-false}"

  if [[ -f "$dest" && "$FORCE" != true && "$always_overwrite" != true ]]; then
    warn "Skipping (exists): $dest"
    return 0
  fi

  run mkdir -p "$(dirname "$dest")"
  if $DRY_RUN; then
    echo "[dry-run] cp $src -> $dest" >&2
    return 0
  fi

  cp "$src" "$dest"
  if [[ "$dest" == *.ts || "$dest" == *.tsx || "$dest" == *.json || "$dest" == *.html || "$dest" == *.css || "$dest" == *"/.env" ]]; then
    apply_template_vars "$dest"
  fi
}

copy_tree() {
  local src_dir="$1"
  local dest_dir="$2"
  local always_overwrite="${3:-false}"

  [[ -d "$src_dir" ]] || die "Template directory not found: $src_dir"

  while IFS= read -r -d '' file; do
    local rel="${file#$src_dir/}"
    rel="${rel//\{\{LOCALE\}\}/$LOCALE}"
    copy_file "$file" "$dest_dir/$rel" "$always_overwrite"
  done < <(find "$src_dir" -type f -print0)
}

validate_target() {
  local target="$1"
  [[ -d "$target" ]] || die "Target directory not found: $target"
  [[ -f "$target/package.json" ]] || die "No package.json in $target"
  [[ -d "$target/app" ]] || die "No app/ directory in $target — App Router required"

  if ! $DRY_RUN; then
    local next_version
    next_version=$(node -e "const p=require('$target/package.json'); console.log((p.dependencies&&p.dependencies.next)||(p.devDependencies&&p.devDependencies.next)||'')" 2>/dev/null || echo "")
    if [[ -n "$next_version" ]]; then
      local major
      major=$(echo "$next_version" | sed 's/[^0-9].*//' | head -c 2)
      if [[ -n "$major" && "$major" -lt 16 ]]; then
        warn "Next.js version may be < 16 ($next_version). Proxy middleware requires Next.js 16+."
      fi
    fi
  fi
}

# ---------------------------------------------------------------------------
# Phase 1: Create or resolve project directory
# ---------------------------------------------------------------------------

create_next_app() {
  local name="$1"
  local parent
  parent="$(dirname "$name")"

  if [[ "$parent" != "." && "$parent" != "$name" ]]; then
    run mkdir -p "$parent"
  fi

  log "Phase 1: Creating Next.js 16 app: $name"

  if $DRY_RUN; then
    log "[dry-run] pnpm create next-app@16 $name"
    return
  fi

  # Stderr only — stdout would pollute TARGET_DIR if captured via command substitution
  pnpm create next-app@16 "$name" \
    --typescript --tailwind --eslint --app --no-src-dir \
    --import-alias "@/*" --use-pnpm --yes >&2 || true

  [[ -d "$name" ]] || die "create-next-app did not create directory: $name"
}

resolve_target() {
  TARGET_DIR=""

  if [[ -n "$INTO" ]]; then
    TARGET_DIR="$(cd "$INTO" && pwd)"
    PROJECT_NAME="$(basename "$TARGET_DIR")"
    log "Phase 1: Using existing project at $TARGET_DIR"
    validate_target "$TARGET_DIR"
    return
  fi

  if [[ -d "$PROJECT_NAME" && "$FORCE" != true ]]; then
    die "Directory exists: $PROJECT_NAME (use --force or choose another name)"
  fi

  create_next_app "$PROJECT_NAME"
  TARGET_DIR="$(cd "$PROJECT_NAME" && pwd)"
  validate_target "$TARGET_DIR"
}

# ---------------------------------------------------------------------------
# Phase 2: Install dependencies (before any scaffold file writes)
# ---------------------------------------------------------------------------

setup_pnpm_workspace() {
  local target="$1"
  if [[ -f "$CONFIG_DIR/pnpm-workspace.yaml" ]]; then
    copy_file "$CONFIG_DIR/pnpm-workspace.yaml" "$target/pnpm-workspace.yaml" true
  fi
}

pnpm_install_all() {
  local target="$1"
  run pnpm --dir "$target" install --ignore-scripts
}

install_auth_dependencies() {
  local target="$1"

  if $SKIP_INSTALL; then
    log "Phase 2: Skipping dependency installation (--skip-install)"
    return
  fi

  log "Phase 2: Installing dependencies..."

  setup_pnpm_workspace "$target"
  pnpm_install_all "$target"

  log "Adding auth stack packages..."
  run pnpm --dir "$target" add --ignore-scripts "${AUTH_DEPS[@]}"
  pnpm_install_all "$target"

  log "Dependencies installed."
}

# ---------------------------------------------------------------------------
# Phase 3: Apply scaffold files (after installation — avoids create-next-app collisions)
# ---------------------------------------------------------------------------

configure_next_intl() {
  local target="$1"

  log "Configuring next-intl..."

  # next.config.ts — required plugin wiring (always apply after install)
  copy_file "$CONFIG_DIR/next.config.ts" "$target/next.config.ts" true

  # i18n/request.ts + i18n/routing.ts are copied via core tree;
  # verify they landed
  if [[ ! -f "$target/i18n/request.ts" && ! $DRY_RUN ]]; then
    die "Missing i18n/request.ts after scaffold — check templates/core/i18n/"
  fi

  log "next-intl configured (next.config.ts + i18n/request.ts + i18n/routing.ts)"
}

patch_tsconfig() {
  local target="$1"
  local tsconfig="$target/tsconfig.json"

  if [[ ! -f "$tsconfig" ]]; then
    warn "No tsconfig.json found"
    return
  fi

  if grep -q '"@/\*"' "$tsconfig" 2>/dev/null; then
    log "tsconfig already has @/* path alias"
    return
  fi

  if $DRY_RUN; then
    echo "[dry-run] patch tsconfig paths in $tsconfig"
    return
  fi

  node -e "
    const fs = require('fs');
    const p = '$tsconfig';
    const j = JSON.parse(fs.readFileSync(p, 'utf8'));
    j.compilerOptions = j.compilerOptions || {};
    j.compilerOptions.paths = { ...(j.compilerOptions.paths || {}), '@/*': ['./*'] };
    fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
  "
  log "Added @/* path alias to tsconfig.json"
}

write_env_file() {
  local target="$1"
  local src="$CONFIG_DIR/env"
  local dest="$target/.env"

  [[ -f "$src" ]] || die "Env template not found: $src"

  if [[ -f "$dest" && "$FORCE" != true ]]; then
    warn "Skipping .env (exists — use --force to overwrite)"
    return 0
  fi

  if $DRY_RUN; then
    echo "[dry-run] write $dest from $src"
    return 0
  fi

  cp "$src" "$dest"
  apply_template_vars "$dest"
  log "Created $dest"
}

ensure_gitignore_env() {
  local target="$1"
  local gitignore="$target/.gitignore"

  if $DRY_RUN; then
    echo "[dry-run] ensure .env in .gitignore"
    return
  fi

  if [[ ! -f "$gitignore" ]]; then
    printf '%s\n' ".env" ".env*.local" > "$gitignore"
    log "Created .gitignore with .env"
    return
  fi

  if grep -qE '^\.env$|^\.env\*' "$gitignore" 2>/dev/null; then
    return
  fi

  {
    echo ""
    echo "# local env (supabase-auth-starter)"
    echo ".env"
    echo ".env*.local"
  } >> "$gitignore"
  log "Added .env to .gitignore"
}

generate_customize_manifest() {
  local target="$1"
  local dest="$target/CUSTOMIZE.md"

  if [[ -f "$STARTER_DIR/CUSTOMIZE.md" ]]; then
    copy_file "$STARTER_DIR/CUSTOMIZE.md" "$dest" true
  fi

  if $DRY_RUN; then
    echo "[dry-run] generate CUSTOMIZE.md at $dest"
    return
  fi

  {
    echo ""
    echo "## Scaffolded placeholder files"
    echo ""
    if command -v jq &>/dev/null && [[ -f "$MANIFEST" ]]; then
      jq -r '.placeholderFiles[]' "$MANIFEST" | while read -r f; do
        f="${f//\{\{LOCALE\}\}/$LOCALE}"
        echo "- \`$f\`"
      done
    fi
    echo ""
    echo "Generated by supabase-auth-starter on $(date -u +%Y-%m-%dT%H:%MZ)"
  } >> "$dest"
}

apply_project_scaffold() {
  local target="$1"

  log "Phase 3: Applying scaffold files..."

  log "  → core auth infrastructure"
  copy_tree "$CORE_DIR" "$target"

  log "  → UI placeholders (@customization-required)"
  copy_tree "$PLACEHOLDERS_DIR" "$target" true

  local locale_src="$PLACEHOLDERS_DIR/locales/{{LOCALE}}.json"
  local locale_src_resolved="${locale_src/\{\{LOCALE\}\}/$LOCALE}"
  if [[ -f "$locale_src_resolved" ]]; then
    log "  → locales/$LOCALE.json"
    copy_file "$locale_src_resolved" "$target/locales/$LOCALE.json" true
  fi

  log "  → next-intl configuration"
  configure_next_intl "$target"

  log "  → tsconfig paths"
  patch_tsconfig "$target"

  log "  → environment file"
  write_env_file "$target"
  ensure_gitignore_env "$target"

  log "  → CUSTOMIZE.md"
  generate_customize_manifest "$target"

  log "Scaffold files applied."
}

print_post_setup() {
  local target="$1"
  cat <<EOF

================================================================================
 Supabase Auth PKCE scaffold complete: $target
================================================================================

Next steps:

  1. cd $target
  2. Fill in .env with your Supabase keys
  3. Supabase Dashboard → Authentication → URL Configuration:
       Site URL: http://localhost:3000
       Redirect URLs: http://localhost:3000/auth/callback
  4. Upload templates/email/*.html to Supabase Auth email templates
  5. Customize UI placeholders — see CUSTOMIZE.md
     grep -r "@customization-required" .
  6. Review shared/constants/systemRoutes.ts for protected routes
  7. pnpm dev

Configured:
  - next.config.ts  → createNextIntlPlugin() (next-intl)
  - i18n/request.ts → cookie-based locale + messages loader
  - i18n/routing.ts → locale routing config
  - proxy.ts        → session refresh + route guards

Auth routes:
  GET /auth/callback  — PKCE OAuth code exchange
  GET /auth/confirm   — Email OTP verify (email, recovery)

Pages:
  /login /register /forgot-password /reset-password /welcome

================================================================================
EOF
}

main() {
  parse_args "$@"
  require_pnpm

  resolve_target
  [[ -n "$TARGET_DIR" ]] || die "Failed to resolve target directory"

  local target="$TARGET_DIR"

  install_auth_dependencies "$target"
  apply_project_scaffold "$target"
  print_post_setup "$target"
}

main "$@"
