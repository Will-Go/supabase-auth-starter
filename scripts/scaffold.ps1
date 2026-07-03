#Requires -Version 5.1
<#
.SYNOPSIS
  Supabase Auth PKCE Jump Starter — scaffold script (Windows / PowerShell)

.DESCRIPTION
  Usage:
    .\scripts\scaffold.ps1 my-app
    .\scripts\scaffold.ps1 -Into .\existing
    .\scripts\scaffold.cmd my-app

  Phases:
    1. Create or validate project
    2. Install all dependencies (pnpm, --ignore-scripts)
    3. Apply scaffold files + i18n/next.config configuration
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]] $RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:ProjectName = ''
$Script:Into = ''
$Script:Locale = 'es'
$Script:Force = $false
$Script:DryRun = $false
$Script:SkipInstall = $false
$Script:TargetDir = ''

$ScriptDir = $PSScriptRoot
$StarterDir = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$TemplatesDir = Join-Path $StarterDir 'templates'
$CoreDir = Join-Path $TemplatesDir 'core'
$PlaceholdersDir = Join-Path $TemplatesDir 'placeholders'
$ConfigDir = Join-Path $TemplatesDir 'config'
$Manifest = Join-Path $TemplatesDir 'manifests\customize.json'

$AuthDeps = @(
  '@supabase/ssr',
  '@supabase/supabase-js',
  '@tanstack/react-query',
  'axios',
  'clsx',
  'next-intl',
  'react-hook-form',
  '@hookform/resolvers',
  'sonner',
  'tailwind-merge',
  'zod'
)

$ScriptDir = $PSScriptRoot
$useColor = [string]::IsNullOrEmpty($env:NO_COLOR)
if ($useColor) {
  try {
    $useColor = [Console]::IsOutputRedirected -eq $false
  } catch {
    $useColor = $true
  }
}

if ($useColor) {
  $R = "`e[0m"
  $B = "`e[1m"
  $D = "`e[2m"
  $RED = "`e[31m"
  $GRN = "`e[32m"
  $YLW = "`e[33m"
  $BLU = "`e[34m"
  $MAG = "`e[35m"
  $CYN = "`e[36m"
  $BCYN = "`e[96m"
  $BGRN = "`e[92m"
  $BYLW = "`e[93m"
  $BMAG = "`e[95m"
} else {
  $R = $B = $D = $RED = $GRN = $YLW = $BLU = $MAG = $CYN = $BCYN = $BGRN = $BYLW = $BMAG = ''
}

$Prefix = "${BCYN}${B}◆ supabase-auth-starter${R}"

function Write-Log {
  param([string] $Message)
  [Console]::Error.WriteLine("$Prefix $Message")
}

function Write-LogPhase {
  param(
    [int] $Number,
    [string] $Message
  )
  [Console]::Error.WriteLine("$Prefix ${BMAG}Phase ${Number}:${R} ${B}${Message}${R}")
}

function Write-LogStep {
  param([string] $Message)
  [Console]::Error.WriteLine("$Prefix ${D}  →${R} ${BLU}${Message}${R}")
}

function Write-LogSuccess {
  param([string] $Message)
  [Console]::Error.WriteLine("$Prefix ${GRN}✓${R} ${GRN}${Message}${R}")
}

function Write-Warn {
  param([string] $Message)
  [Console]::Error.WriteLine("$Prefix ${BYLW}⚠ WARNING:${R} ${YLW}${Message}${R}")
}

function Stop-Scaffold {
  param([string] $Message)
  [Console]::Error.WriteLine("$Prefix ${RED}✗ ERROR:${R} ${RED}${Message}${R}")
  exit 1
}

function Write-DryEcho {
  param([string] $Message)
  [Console]::Error.WriteLine("$Prefix ${D}[dry-run]${R} ${D}${Message}${R}")
}

function Ensure-Directory {
  param([string] $Path)
  if ($Script:DryRun) {
    Write-DryEcho "mkdir $Path"
    return
  }
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Invoke-External {
  param(
    [string] $Command,
    [string[]] $Arguments = @(),
    [switch] $AllowFailure
  )
  if ($Script:DryRun) {
    $joined = if ($Arguments.Count -gt 0) { "$Command $($Arguments -join ' ')" } else { $Command }
    Write-DryEcho $joined
    return
  }
  & $Command @Arguments
  if (-not $AllowFailure -and $LASTEXITCODE -ne 0) {
    throw "Command failed ($LASTEXITCODE): $Command $($Arguments -join ' ')"
  }
}

function Invoke-ScaffoldCommand {
  param(
    [string] $Command,
    [string[]] $Arguments = @()
  )
  Invoke-External -Command $Command -Arguments $Arguments
}

function Show-Usage {
  $name = Split-Path -Leaf $PSCommandPath
  @"
Usage:
  $name [options] <project-name>
  $name -Into <path> [options]

Options:
  -Into <path>       Scaffold into an existing Next.js project
  -Locale <code>     Default locale (default: es)
  -Force             Overwrite existing files
  -DryRun            Print actions without executing
  -SkipInstall       Skip dependency installation (file copy only)
  -Help              Show this help

Examples:
  $name my-app
  $name -Into .\existing-app -Locale en
"@
}

function Test-Pnpm {
  if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
    Stop-Scaffold 'pnpm is required. Install: https://pnpm.io/installation'
  }
}

function Set-TemplateVars {
  param([string] $File)

  $content = [System.IO.File]::ReadAllText($File)
  $content = $content -replace '\{\{LOCALE\}\}', $Script:Locale
  $content = $content -replace '\{\{PROJECT_NAME\}\}', $Script:ProjectName
  [System.IO.File]::WriteAllText($File, $content)
}

function Test-TemplateFile {
  param([string] $Path)
  $leaf = Split-Path -Leaf $Path
  return (
    $Path -match '\.(ts|tsx|json|html|css)$' -or
    $leaf -eq '.env'
  )
}

function Copy-ScaffoldFile {
  param(
    [string] $Src,
    [string] $Dest,
    [bool] $AlwaysOverwrite = $false
  )

  if ((Test-Path -LiteralPath $Dest -PathType Leaf) -and -not $Script:Force -and -not $AlwaysOverwrite) {
    Write-Warn "Skipping (exists): $Dest"
    return
  }

  $destDir = Split-Path -Parent $Dest
  if ($destDir) {
    Ensure-Directory $destDir
  }

  if ($Script:DryRun) {
    Write-DryEcho "Copy-Item $Src -> $Dest"
    return
  }

  Copy-Item -LiteralPath $Src -Destination $Dest -Force
  if (Test-TemplateFile $Dest) {
    Set-TemplateVars $Dest
  }
}

function Copy-ScaffoldTree {
  param(
    [string] $SrcDir,
    [string] $DestDir,
    [bool] $AlwaysOverwrite = $false
  )

  if (-not (Test-Path -LiteralPath $SrcDir -PathType Container)) {
    Stop-Scaffold "Template directory not found: $SrcDir"
  }

  Get-ChildItem -LiteralPath $SrcDir -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($SrcDir.Length).TrimStart('\', '/')
    $rel = $rel -replace '\{\{LOCALE\}\}', $Script:Locale
    $dest = Join-Path $DestDir $rel
    Copy-ScaffoldFile -Src $_.FullName -Dest $dest -AlwaysOverwrite $AlwaysOverwrite
  }
}

function Test-TargetProject {
  param([string] $Target)

  if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
    Stop-Scaffold "Target directory not found: $Target"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $Target 'package.json') -PathType Leaf)) {
    Stop-Scaffold "No package.json in $Target"
  }
  if (-not (Test-Path -LiteralPath (Join-Path $Target 'app') -PathType Container)) {
    Stop-Scaffold "No app/ directory in $Target — App Router required"
  }

  if (-not $Script:DryRun) {
    $pkgPath = (Join-Path $Target 'package.json') -replace '\\', '/'
    $nextVersion = node -e "const p=require('$pkgPath'); console.log((p.dependencies&&p.dependencies.next)||(p.devDependencies&&p.devDependencies.next)||'')" 2>$null
    if ($nextVersion) {
      if ($nextVersion -match '^(\d+)') {
        $major = [int]$Matches[1]
        if ($major -lt 16) {
          Write-Warn "Next.js version may be < 16 ($nextVersion). Proxy middleware requires Next.js 16+."
        }
      }
    }
  }
}

function New-NextApp {
  param([string] $Name)

  $parent = Split-Path -Parent $Name
  if ($parent -and $parent -ne $Name) {
    Ensure-Directory $parent
  }

  Write-LogPhase 1 "Creating Next.js 16 app: ${BCYN}$Name${R}"

  if ($Script:DryRun) {
    Write-DryEcho "pnpm create next-app@16 $Name"
    return
  }

  $cnaArgs = @(
    'create', 'next-app@16', $Name,
    '--typescript', '--tailwind', '--eslint', '--app', '--no-src-dir',
    '--import-alias', '@/*', '--use-pnpm', '--yes'
  )

  Invoke-External -Command 'pnpm' -Arguments $cnaArgs -AllowFailure

  if (-not (Test-Path -LiteralPath $Name -PathType Container)) {
    Stop-Scaffold "create-next-app did not create directory: $Name"
  }
}

function Resolve-Target {
  $script:TargetDir = ''

  if ($Script:Into) {
    $resolved = Resolve-Path -LiteralPath $Script:Into
    $script:TargetDir = $resolved.Path
    $Script:ProjectName = Split-Path -Leaf $script:TargetDir
    Write-LogPhase 1 "Using existing project at ${BCYN}$($script:TargetDir)${R}"
    Test-TargetProject $script:TargetDir
    return
  }

  if ((Test-Path -LiteralPath $Script:ProjectName) -and -not $Script:Force) {
    Stop-Scaffold "Directory exists: $($Script:ProjectName) (use -Force or choose another name)"
  }

  New-NextApp $Script:ProjectName
  $script:TargetDir = (Resolve-Path -LiteralPath $Script:ProjectName).Path
  Test-TargetProject $script:TargetDir
}

function Set-PnpmWorkspace {
  param([string] $Target)

  $workspaceTemplate = Join-Path $ConfigDir 'pnpm-workspace.yaml'
  if (Test-Path -LiteralPath $workspaceTemplate -PathType Leaf) {
    Copy-ScaffoldFile -Src $workspaceTemplate -Dest (Join-Path $Target 'pnpm-workspace.yaml') -AlwaysOverwrite $true
  }
}

function Install-PnpmAll {
  param([string] $Target)
  Invoke-ScaffoldCommand 'pnpm' @('--dir', $Target, 'install', '--ignore-scripts')
}

function Install-AuthDependencies {
  param([string] $Target)

  if ($Script:SkipInstall) {
    Write-LogPhase 2 "Skipping dependency installation ${D}(-SkipInstall)${R}"
    return
  }

  Write-LogPhase 2 'Installing dependencies...'

  Set-PnpmWorkspace $Target
  Install-PnpmAll $Target

  Write-LogStep 'Adding auth stack packages...'
  $addArgs = @('--dir', $Target, 'add', '--ignore-scripts') + $AuthDeps
  Invoke-ScaffoldCommand 'pnpm' $addArgs
  Install-PnpmAll $Target

  Write-LogSuccess 'Dependencies installed.'
}

function Set-NextIntlConfig {
  param([string] $Target)

  Write-LogStep 'Configuring next-intl...'

  Copy-ScaffoldFile -Src (Join-Path $ConfigDir 'next.config.ts') -Dest (Join-Path $Target 'next.config.ts') -AlwaysOverwrite $true

  $requestTs = Join-Path $Target 'i18n\request.ts'
  if (-not (Test-Path -LiteralPath $requestTs) -and -not $Script:DryRun) {
    Stop-Scaffold 'Missing i18n/request.ts after scaffold — check templates/core/i18n/'
  }

  Write-LogSuccess "next-intl configured ${D}(next.config.ts + i18n/request.ts + i18n/routing.ts)${R}"
}

function Update-TsConfigPaths {
  param([string] $Target)

  $tsconfig = Join-Path $Target 'tsconfig.json'
  if (-not (Test-Path -LiteralPath $tsconfig -PathType Leaf)) {
    Write-Warn 'No tsconfig.json found'
    return
  }

  $raw = Get-Content -LiteralPath $tsconfig -Raw
  if ($raw -match '"@/\*"') {
    Write-LogStep "tsconfig already has ${BCYN}@/*${R} path alias"
    return
  }

  if ($Script:DryRun) {
    Write-DryEcho "patch tsconfig paths in $tsconfig"
    return
  }

  $tsconfigForNode = $tsconfig -replace '\\', '/'
  node -e @"
const fs = require('fs');
const p = '$tsconfigForNode';
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
j.compilerOptions = j.compilerOptions || {};
j.compilerOptions.paths = { ...(j.compilerOptions.paths || {}), '@/*': ['./*'] };
fs.writeFileSync(p, JSON.stringify(j, null, 2) + '\n');
"@

  Write-LogSuccess "Added ${BCYN}@/*${R} path alias to tsconfig.json"
}

function Write-EnvFile {
  param([string] $Target)

  $src = Join-Path $ConfigDir 'env'
  $dest = Join-Path $Target '.env'

  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
    Stop-Scaffold "Env template not found: $src"
  }

  if ((Test-Path -LiteralPath $dest -PathType Leaf) -and -not $Script:Force) {
    Write-Warn 'Skipping .env (exists — use -Force to overwrite)'
    return
  }

  if ($Script:DryRun) {
    Write-DryEcho "write $dest from $src"
    return
  }

  Copy-Item -LiteralPath $src -Destination $dest -Force
  Set-TemplateVars $dest
  Write-LogSuccess "Created ${BCYN}$dest${R}"
}

function Ensure-GitignoreEnv {
  param([string] $Target)

  $gitignore = Join-Path $Target '.gitignore'

  if ($Script:DryRun) {
    Write-DryEcho 'ensure .env in .gitignore'
    return
  }

  if (-not (Test-Path -LiteralPath $gitignore -PathType Leaf)) {
    @('.env', '.env*.local') | Set-Content -LiteralPath $gitignore -Encoding UTF8
    Write-LogSuccess "Created .gitignore with ${BCYN}.env${R}"
    return
  }

  $content = Get-Content -LiteralPath $gitignore -Raw
  if ($content -match '(?m)^\.env$|(?m)^\.env\*') {
    return
  }

  @(
    '',
    '# local env (supabase-auth-starter)',
    '.env',
    '.env*.local'
  ) | Add-Content -LiteralPath $gitignore -Encoding UTF8

  Write-LogSuccess "Added ${BCYN}.env${R} to .gitignore"
}

function New-CustomizeManifest {
  param([string] $Target)

  $dest = Join-Path $Target 'CUSTOMIZE.md'
  $customizeSrc = Join-Path $StarterDir 'CUSTOMIZE.md'

  if (Test-Path -LiteralPath $customizeSrc -PathType Leaf) {
    Copy-ScaffoldFile -Src $customizeSrc -Dest $dest -AlwaysOverwrite $true
  }

  if ($Script:DryRun) {
    Write-DryEcho "generate CUSTOMIZE.md at $dest"
    return
  }

  $lines = @(
    '',
    '## Scaffolded placeholder files',
    ''
  )

  if (Test-Path -LiteralPath $Manifest -PathType Leaf) {
    $json = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
    foreach ($f in $json.placeholderFiles) {
      $resolved = $f -replace '\{\{LOCALE\}\}', $Script:Locale
      $lines += "- ``$resolved``"
    }
  }

  $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHHmmZ')
  $lines += ''
  $lines += "Generated by supabase-auth-starter on $timestamp"
  $lines | Add-Content -LiteralPath $dest -Encoding UTF8
}

function Install-ProjectScaffold {
  param([string] $Target)

  Write-LogPhase 3 'Applying scaffold files...'

  Write-LogStep 'core auth infrastructure'
  Copy-ScaffoldTree -SrcDir $CoreDir -DestDir $Target

  Write-LogStep "UI placeholders ${BYLW}(@customization-required)${R}"
  Copy-ScaffoldTree -SrcDir $PlaceholdersDir -DestDir $Target -AlwaysOverwrite $true

  $localeSrc = Join-Path $PlaceholdersDir "locales\{{LOCALE}}.json"
  $localeSrcResolved = $localeSrc -replace '\{\{LOCALE\}\}', $Script:Locale
  if (Test-Path -LiteralPath $localeSrcResolved -PathType Leaf) {
    Write-LogStep "locales/${BCYN}$($Script:Locale).json${R}"
    Copy-ScaffoldFile -Src $localeSrcResolved -Dest (Join-Path $Target "locales\$($Script:Locale).json") -AlwaysOverwrite $true
  }

  Write-LogStep 'next-intl configuration'
  Set-NextIntlConfig $Target

  Write-LogStep 'tsconfig paths'
  Update-TsConfigPaths $Target

  Write-LogStep 'environment file'
  Write-EnvFile $Target
  Ensure-GitignoreEnv $Target

  Write-LogStep 'CUSTOMIZE.md'
  New-CustomizeManifest $Target

  Write-LogSuccess 'Scaffold files applied.'
}

function Show-PostSetup {
  param([string] $Target)

  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("${BGRN}══════════════════════════════════════════════════════════════════════════════${R}")
  [Console]::Error.WriteLine(" ${B}${BGRN}✓ Supabase Auth PKCE scaffold complete${R}")
  [Console]::Error.WriteLine(" ${D}→${R} ${BCYN}$Target${R}")
  [Console]::Error.WriteLine("${BGRN}══════════════════════════════════════════════════════════════════════════════${R}")
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("${B}${MAG}Next steps:${R}")
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("  ${BMAG}1.${R} cd ${BCYN}$Target${R}")
  [Console]::Error.WriteLine("  ${BMAG}2.${R} Fill in ${BCYN}.env${R} with your Supabase keys")
  [Console]::Error.WriteLine("  ${BMAG}3.${R} Supabase Dashboard → Authentication → URL Configuration:")
  [Console]::Error.WriteLine("       Site URL: ${BLU}http://localhost:3000${R}")
  [Console]::Error.WriteLine("       Redirect URLs: ${BLU}http://localhost:3000/auth/callback${R}")
  [Console]::Error.WriteLine("  ${BMAG}4.${R} Upload ${BCYN}templates/email/*.html${R} to Supabase Auth email templates")
  [Console]::Error.WriteLine("  ${BMAG}5.${R} Customize UI placeholders — see ${BCYN}CUSTOMIZE.md${R}")
  [Console]::Error.WriteLine("     ${D}Select-String -Path . -Pattern '@customization-required' -Recurse${R}")
  [Console]::Error.WriteLine("  ${BMAG}6.${R} Review ${BCYN}shared/constants/systemRoutes.ts${R} for protected routes")
  [Console]::Error.WriteLine("  ${BMAG}7.${R} ${BGRN}pnpm dev${R}")
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("${B}${CYN}Configured:${R}")
  [Console]::Error.WriteLine("  ${CYN}•${R} next.config.ts  ${D}→${R} createNextIntlPlugin() (next-intl)")
  [Console]::Error.WriteLine("  ${CYN}•${R} i18n/request.ts ${D}→${R} cookie-based locale + messages loader")
  [Console]::Error.WriteLine("  ${CYN}•${R} i18n/routing.ts ${D}→${R} locale routing config")
  [Console]::Error.WriteLine("  ${CYN}•${R} proxy.ts        ${D}→${R} session refresh + route guards")
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("${B}${CYN}Auth routes:${R}")
  [Console]::Error.WriteLine("  ${BGRN}GET${R} /auth/callback  ${D}—${R} PKCE OAuth code exchange")
  [Console]::Error.WriteLine("  ${BGRN}GET${R} /auth/confirm   ${D}—${R} Email OTP verify (email, recovery)")
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("${B}${CYN}Pages:${R}")
  [Console]::Error.WriteLine("  ${BLU}/login${R} ${BLU}/register${R} ${BLU}/forgot-password${R} ${BLU}/reset-password${R} ${BLU}/welcome${R}")
  [Console]::Error.WriteLine('')
  [Console]::Error.WriteLine("${BGRN}══════════════════════════════════════════════════════════════════════════════${R}")
}

function Parse-CliArgs {
  param([string[]] $InputArgs)

  $i = 0
  while ($i -lt $InputArgs.Count) {
    $arg = $InputArgs[$i]
    switch -Regex ($arg) {
      '^(-Into|--into)$' {
        $i++
        if ($i -ge $InputArgs.Count) { Stop-Scaffold "$arg requires a path" }
        $Script:Into = $InputArgs[$i]
      }
      '^(-Locale|--locale)$' {
        $i++
        if ($i -ge $InputArgs.Count) { Stop-Scaffold "$arg requires a code" }
        $Script:Locale = $InputArgs[$i]
      }
      '^(-Force|--force)$' { $Script:Force = $true }
      '^(-DryRun|--dry-run)$' { $Script:DryRun = $true }
      '^(-SkipInstall|--skip-install)$' { $Script:SkipInstall = $true }
      '^(-h|-Help|--help)$' {
        Show-Usage
        exit 0
      }
      '^--' { Stop-Scaffold "Unknown option: $arg" }
      default {
        if ($Script:ProjectName) { Stop-Scaffold "Unexpected argument: $arg" }
        $Script:ProjectName = $arg
      }
    }
    $i++
  }
}

# ── Main ─────────────────────────────────────────────────────────────────────
$cliArgs = @($RemainingArgs)
if ($cliArgs.Count -eq 0 -and $args.Count -gt 0) {
  $cliArgs = @($args)
}

if ($cliArgs.Count -gt 0) {
  Parse-CliArgs $cliArgs
}

if (-not $Script:Into -and -not $Script:ProjectName) {
  Show-Usage
  Stop-Scaffold 'Provide a project name or -Into <path>'
}

if ($Script:Into -and $Script:ProjectName) {
  Stop-Scaffold 'Use either project name or -Into, not both'
}

Test-Pnpm
Resolve-Target

if (-not $script:TargetDir) {
  Stop-Scaffold 'Failed to resolve target directory'
}

$target = $script:TargetDir

Install-AuthDependencies $target
Install-ProjectScaffold $target
Show-PostSetup $target
