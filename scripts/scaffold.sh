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

# ── Terminal colors (respect NO_COLOR and non-TTY output) ─────────────────────
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  _R=$'\033[0m'
  _B=$'\033[1m'
  _D=$'\033[2m'
  _RED=$'\033[31m'
  _GRN=$'\033[32m'
  _YLW=$'\033[33m'
  _BLU=$'\033[34m'
  _MAG=$'\033[35m'
  _CYN=$'\033[36m'
  _BCYN=$'\033[96m'
  _BGRN=$'\033[92m'
  _BYLW=$'\033[93m'
  _BMAG=$'\033[95m'
else
  _R= _B= _D= _RED= _GRN= _YLW= _BLU= _MAG= _CYN= _BCYN= _BGRN= _BYLW= _BMAG=
fi

_PREFIX="${_BCYN}${_B}◆ supabase-auth-starter${_R}"

log() {
  printf '%b %b\n' "$_PREFIX" "$*" >&2
}

log_phase() {
  local msg="${*:2}"
  printf '%b %bPhase %s:%b %b%b%b\n' \
    "$_PREFIX" "$_BMAG" "$1" "$_R" "$_B" "$msg" "$_R" >&2
}

log_step() {
  printf '%b %b  →%b %b%b%b\n' \
    "$_PREFIX" "$_D" "$_R" "$_BLU" "$*" "$_R" >&2
}

log_success() {
  printf '%b %b✓%b %b%b%b\n' \
    "$_PREFIX" "$_GRN" "$_R" "$_GRN" "$*" "$_R" >&2
}

warn() {
  printf '%b %b⚠ WARNING:%b %b%s%b\n' \
    "$_PREFIX" "$_BYLW" "$_R" "$_YLW" "$*" "$_R" >&2
}

die() {
  printf '%b %b✗ ERROR:%b %b%s%b\n' \
    "$_PREFIX" "$_RED" "$_R" "$_RED" "$*" "$_R" >&2
  exit 1
}

dry_echo() {
  printf '%b %b[dry-run]%b %b%s%b\n' \
    "$_PREFIX" "$_D" "$_R" "$_D" "$*" "$_R" >&2
}

run() {
  if $DRY_RUN; then
    dry_echo "$*"
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

sed_inplace() {
  # BSD sed (macOS) requires '' after -i; GNU sed does not.
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

apply_template_vars() {
  local file="$1"
  # Use | delimiter — PROJECT_NAME may contain slashes (e.g. ./test breaks s/// syntax).
  sed_inplace "s|{{LOCALE}}|$LOCALE|g" "$file"
  sed_inplace "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$file"
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
    dry_echo "cp $src -> $dest"
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

  log_phase 1 "Creating Next.js 16 app: ${_BCYN}$name${_R}"

  if $DRY_RUN; then
    dry_echo "pnpm create next-app@16 $name"
    return
  fi

  # --skip-install: Phase 2 runs pnpm install --ignore-scripts (avoids pnpm v10+ build-script approval).
  # Stderr only — stdout would pollute TARGET_DIR if captured via command substitution
  pnpm create next-app@16 "$name" \
    --typescript --tailwind --eslint --app --no-src-dir \
    --import-alias "@/*" --use-pnpm --yes --skip-install >&2

  [[ -d "$name" ]] || die "create-next-app did not create directory: $name"
}

resolve_target() {
  TARGET_DIR=""

  if [[ -n "$INTO" ]]; then
    TARGET_DIR="$(cd "$INTO" && pwd)"
    PROJECT_NAME="$(basename "$TARGET_DIR")"
    log_phase 1 "Using existing project at ${_BCYN}$TARGET_DIR${_R}"
    validate_target "$TARGET_DIR"
    return
  fi

  if [[ -d "$PROJECT_NAME" && "$FORCE" != true ]]; then
    die "Directory exists: $PROJECT_NAME (use --force or choose another name)"
  fi

  create_next_app "$PROJECT_NAME"
  TARGET_DIR="$(cd "$PROJECT_NAME" && pwd)"
  PROJECT_NAME="$(basename "$TARGET_DIR")"
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
    log_phase 2 "Skipping dependency installation ${_D}(--skip-install)${_R}"
    return
  fi

  log_phase 2 "Installing dependencies..."

  setup_pnpm_workspace "$target"
  pnpm_install_all "$target"

  log_step "Adding auth stack packages..."
  run pnpm --dir "$target" add --ignore-scripts "${AUTH_DEPS[@]}"
  pnpm_install_all "$target"

  log_success "Dependencies installed."
}

# ---------------------------------------------------------------------------
# Phase 3: Apply scaffold files (after installation — avoids create-next-app collisions)
# ---------------------------------------------------------------------------

configure_next_intl() {
  local target="$1"

  log_step "Configuring next-intl..."

  # next.config.ts — required plugin wiring (always apply after install)
  copy_file "$CONFIG_DIR/next.config.ts" "$target/next.config.ts" true

  # i18n/request.ts + i18n/routing.ts are copied via core tree;
  # verify they landed
  if [[ ! -f "$target/i18n/request.ts" && ! $DRY_RUN ]]; then
    die "Missing i18n/request.ts after scaffold — check templates/core/i18n/"
  fi

  log_success "next-intl configured ${_D}(next.config.ts + i18n/request.ts + i18n/routing.ts)${_R}"
}

patch_tsconfig() {
  local target="$1"
  local tsconfig="$target/tsconfig.json"

  if [[ ! -f "$tsconfig" ]]; then
    warn "No tsconfig.json found"
    return
  fi

  if grep -q '"@/\*"' "$tsconfig" 2>/dev/null; then
    log_step "tsconfig already has ${_BCYN}@/*${_R} path alias"
    return
  fi

  if $DRY_RUN; then
    dry_echo "patch tsconfig paths in $tsconfig"
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
  log_success "Added ${_BCYN}@/*${_R} path alias to tsconfig.json"
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
    dry_echo "write $dest from $src"
    return 0
  fi

  cp "$src" "$dest"
  apply_template_vars "$dest"
  log_success "Created ${_BCYN}$dest${_R}"
}

ensure_gitignore_env() {
  local target="$1"
  local gitignore="$target/.gitignore"

  if $DRY_RUN; then
    dry_echo "ensure .env in .gitignore"
    return
  fi

  if [[ ! -f "$gitignore" ]]; then
    printf '%s\n' ".env" ".env*.local" > "$gitignore"
    log_success "Created .gitignore with ${_BCYN}.env${_R}"
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
  log_success "Added ${_BCYN}.env${_R} to .gitignore"
}

generate_customize_manifest() {
  local target="$1"
  local dest="$target/CUSTOMIZE.md"

  if [[ -f "$STARTER_DIR/CUSTOMIZE.md" ]]; then
    copy_file "$STARTER_DIR/CUSTOMIZE.md" "$dest" true
  fi

  if $DRY_RUN; then
    dry_echo "generate CUSTOMIZE.md at $dest"
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

  log_phase 3 "Applying scaffold files..."

  log_step "core auth infrastructure"
  copy_tree "$CORE_DIR" "$target"

  log_step "UI placeholders ${_BYLW}(@customization-required)${_R}"
  copy_tree "$PLACEHOLDERS_DIR" "$target" true

  local locale_src="$PLACEHOLDERS_DIR/locales/{{LOCALE}}.json"
  local locale_src_resolved="${locale_src/\{\{LOCALE\}\}/$LOCALE}"
  if [[ -f "$locale_src_resolved" ]]; then
    log_step "locales/${_BCYN}$LOCALE.json${_R}"
    copy_file "$locale_src_resolved" "$target/locales/$LOCALE.json" true
  fi

  log_step "next-intl configuration"
  configure_next_intl "$target"

  log_step "tsconfig paths"
  patch_tsconfig "$target"

  log_step "environment file"
  write_env_file "$target"
  ensure_gitignore_env "$target"

  log_step "CUSTOMIZE.md"
  generate_customize_manifest "$target"

  log_success "Scaffold files applied."
}

print_post_setup() {
  local target="$1"
  printf '\n' >&2
  printf '%b\n' "${_BGRN}══════════════════════════════════════════════════════════════════════════════${_R}" >&2
  printf ' %b✓ Supabase Auth PKCE scaffold complete%b\n' "$_B$_BGRN" "$_R" >&2
  printf ' %b→%b %b%s%b\n' "$_D" "$_R" "$_BCYN" "$target" "$_R" >&2
  printf '%b\n' "${_BGRN}══════════════════════════════════════════════════════════════════════════════${_R}" >&2
  printf '\n' >&2
  printf '%bNext steps:%b\n\n' "$_B$_MAG" "$_R" >&2
  printf '  %b1.%b cd %b%s%b\n' "$_BMAG" "$_R" "$_BCYN" "$target" "$_R" >&2
  printf '  %b2.%b Fill in %b.env%b with your Supabase keys\n' "$_BMAG" "$_R" "$_BCYN" "$_R" >&2
  printf '  %b3.%b Supabase Dashboard → Authentication → URL Configuration:\n' "$_BMAG" "$_R" >&2
  printf '       Site URL: %bhttp://localhost:3000%b\n' "$_BLU" "$_R" >&2
  printf '       Redirect URLs: %bhttp://localhost:3000/auth/callback%b\n' "$_BLU" "$_R" >&2
  printf '  %b4.%b Upload %btemplates/email/*.html%b to Supabase Auth email templates\n' "$_BMAG" "$_R" "$_BCYN" "$_R" >&2
  printf '  %b5.%b Customize UI placeholders — see %bCUSTOMIZE.md%b\n' "$_BMAG" "$_R" "$_BCYN" "$_R" >&2
  printf '     %bgrep -r "@customization-required" .%b\n' "$_D" "$_R" >&2
  printf '  %b6.%b Review %bshared/constants/systemRoutes.ts%b for protected routes\n' "$_BMAG" "$_R" "$_BCYN" "$_R" >&2
  printf '  %b7.%b %bpnpm dev%b\n\n' "$_BMAG" "$_R" "$_BGRN" "$_R" >&2
  printf '%bConfigured:%b\n' "$_B$_CYN" "$_R" >&2
  printf '  %b•%b next.config.ts  %b→%b createNextIntlPlugin() (next-intl)\n' "$_CYN" "$_R" "$_D" "$_R" >&2
  printf '  %b•%b i18n/request.ts %b→%b cookie-based locale + messages loader\n' "$_CYN" "$_R" "$_D" "$_R" >&2
  printf '  %b•%b i18n/routing.ts %b→%b locale routing config\n' "$_CYN" "$_R" "$_D" "$_R" >&2
  printf '  %b•%b proxy.ts        %b→%b session refresh + route guards\n\n' "$_CYN" "$_R" "$_D" "$_R" >&2
  printf '%bAuth routes:%b\n' "$_B$_CYN" "$_R" >&2
  printf '  %bGET%b /auth/callback  %b—%b PKCE OAuth code exchange\n' "$_BGRN" "$_R" "$_D" "$_R" >&2
  printf '  %bGET%b /auth/confirm   %b—%b Email OTP verify (email, recovery)\n\n' "$_BGRN" "$_R" "$_D" "$_R" >&2
  printf '%bPages:%b\n' "$_B$_CYN" "$_R" >&2
  printf '  %b/login%b %b/register%b %b/forgot-password%b %b/reset-password%b %b/welcome%b\n\n' \
    "$_BLU" "$_R" "$_BLU" "$_R" "$_BLU" "$_R" "$_BLU" "$_R" "$_BLU" "$_R" >&2
  printf '%b\n' "${_BGRN}══════════════════════════════════════════════════════════════════════════════${_R}" >&2
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
