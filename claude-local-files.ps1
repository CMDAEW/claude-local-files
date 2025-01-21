# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires administrator privileges. Please run PowerShell as Administrator."
    exit 1
}

$ErrorActionPreference = "Stop"

# Constants
$DOMAIN = "cdn.jsdelivr.net"
$HOSTS_MARKER = "# claude-local-files"
$HOSTS_PATH = "$env:SystemRoot\System32\drivers\etc\hosts"

# Check dependencies
function Check-Dependencies {
    $missing = @()
    
    if (!(Get-Command mkcert -ErrorAction SilentlyContinue)) {
        $missing += "mkcert"
    }
    
    if (!(Get-Command caddy -ErrorAction SilentlyContinue)) {
        $missing += "caddy"
    }
    
    if ($missing.Count -gt 0) {
        Write-Error "Missing required dependencies: $($missing -join ', '). Please install them and try again."
        exit 1
    }
}

# Manage hosts file entry
function Add-HostsEntry {
    try {
        # Modify hosts file
        $hostsContent = Get-Content $HOSTS_PATH
        if (!($hostsContent -match "$HOSTS_MARKER$")) {
            Write-Host "Adding $DOMAIN to hosts file..."
            $entry = "127.0.0.1 $DOMAIN $HOSTS_MARKER"
            Add-Content -Path $HOSTS_PATH -Value $entry -Force
        }
    }
    catch {
        Write-Error "Failed to modify hosts file: $_"
        exit 1
    }
}

function Remove-HostsEntry {
    try {
        Write-Host "Removing $DOMAIN from hosts file..."
        $content = Get-Content $HOSTS_PATH | Where-Object { $_ -notmatch "$HOSTS_MARKER$" }
        Set-Content -Path $HOSTS_PATH -Value $content -Force
    }
    catch {
        Write-Error "Failed to remove hosts entry: $_"
    }
}

# Setup certificates
function Setup-Certificates {
    if (!(Test-Path "$DOMAIN.pem") -or !(Test-Path "$DOMAIN-key.pem")) {
        Write-Host "Setting up certificates..."
        & mkcert -install
        & mkcert $DOMAIN
    }
}

# Main execution
try {
    Check-Dependencies
    Add-HostsEntry
    Setup-Certificates
    
    Write-Host "Starting Caddy server..."
    & caddy run

} finally {
    Remove-HostsEntry
} 