# agents-skills installer for Windows (PowerShell 5.1 or later).
# Usage: irm https://raw.githubusercontent.com/daidaiiro-519/agents-skills/main/install.ps1 | iex
#        (to pass options, save the file and run: .\install.ps1 -Product semantic-agent-schema -Version 1.0.0)
param(
  [string]$Product = "semantic-agent-schema",
  [string]$Version = "",
  [switch]$NoSetup
)
$ErrorActionPreference = "Stop"

$repo = if ($env:AGENTS_SKILLS_REPO) { $env:AGENTS_SKILLS_REPO } else { "daidaiiro-519/agents-skills" }
$baseUrl = if ($env:AGENTS_SKILLS_BASE_URL) { $env:AGENTS_SKILLS_BASE_URL } else { "https://github.com/$repo/releases/download" }
$apiUrl = if ($env:AGENTS_SKILLS_API_URL) { $env:AGENTS_SKILLS_API_URL } else { "https://api.github.com/repos/$repo/releases?per_page=50" }
$installDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "agents-skills\bin" }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Fail($m) { Write-Error "error: $m"; exit 1 }

if ($Product -ne "semantic-agent-schema") { Fail "unknown product: $Product (available: semantic-agent-schema)" }
if (-not [Environment]::Is64BitOperatingSystem) { Fail "a 64-bit Windows is required" }
$target = "x86_64-pc-windows-msvc"

if (-not $Version) {
  $releases = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
  $prefix = "$Product-v"
  $hit = $releases | Where-Object { $_.tag_name -like "$prefix*" } | Select-Object -First 1
  if (-not $hit) { Fail "no published release of $Product" }
  $Version = $hit.tag_name.Substring($prefix.Length)
}
$Version = $Version.TrimStart("v")
$tag = "$Product-v$Version"
$archive = "$Product-$Version-$target.zip"

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("agents-skills-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Write-Host "download: $tag ($target)"
  Invoke-WebRequest -Uri "$baseUrl/$tag/$archive" -OutFile (Join-Path $tmp $archive) -UseBasicParsing
  Invoke-WebRequest -Uri "$baseUrl/$tag/SHA256SUMS" -OutFile (Join-Path $tmp "SHA256SUMS") -UseBasicParsing

  $line = Get-Content (Join-Path $tmp "SHA256SUMS") | Where-Object { $_ -match [regex]::Escape($archive) + "$" } | Select-Object -First 1
  if (-not $line) { Fail "SHA256SUMS has no line for $archive" }
  $expected = ($line -split "\s+")[0].ToLower()
  $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $archive)).Hash.ToLower()
  if ($expected -ne $actual) { Fail "SHA256 mismatch (expected $expected, actual $actual). Aborted." }
  Write-Host "SHA256 matched"

  Expand-Archive -Path (Join-Path $tmp $archive) -DestinationPath $tmp -Force
  New-Item -ItemType Directory -Path $installDir -Force | Out-Null
  foreach ($bin in @("$Product.exe", "$Product-mcp.exe")) {
    $src = Join-Path $tmp $bin
    if (-not (Test-Path $src)) { Fail "the archive has no $bin" }
    Copy-Item $src (Join-Path $installDir $bin) -Force
  }
  Write-Host "installed: $installDir"
  & (Join-Path $installDir "$Product.exe") --version
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($userPath -split ";") -notcontains $installDir) {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
  Write-Host "added $installDir to the user PATH (open a new terminal to use it)"
}

if ($NoSetup) { Write-Host "setup skipped (-NoSetup)"; exit 0 }

$mcp = Join-Path $installDir "$Product-mcp.exe"
if (Get-Command claude -ErrorAction SilentlyContinue) {
  & claude mcp get $Product *> $null
  if ($LASTEXITCODE -eq 0) { Write-Host "Claude Code: $Product is already registered (unchanged)" }
  else { & claude mcp add --scope user $Product -- $mcp; Write-Host "Claude Code: registered $Product (user scope)" }
} else {
  Write-Host "Claude Code: no claude command. To register later: claude mcp add --scope user $Product -- $mcp"
}
if (Get-Command codex -ErrorAction SilentlyContinue) {
  & codex mcp get $Product *> $null
  if ($LASTEXITCODE -eq 0) { Write-Host "Codex: $Product is already registered (unchanged)" }
  else { & codex mcp add $Product -- $mcp; Write-Host "Codex: registered $Product" }
  Write-Host "Codex asks for approval on every MCP tool call. To skip it, add this line under [mcp_servers.$Product] in ~/.codex/config.toml (not edited automatically):"
  Write-Host '  default_tools_approval_mode = "approve"'
} else {
  Write-Host "Codex: no codex command. To register later: codex mcp add $Product -- $mcp"
}
