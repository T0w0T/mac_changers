<#
.SYNOPSIS
    Change l'adresse MAC d'une carte réseau Windows.
.DESCRIPTION
    Modifie la valeur "NetworkAddress" dans le registre de l'adaptateur sélectionné,
    puis désactive/réactive l'interface pour appliquer le changement.
    Nécessite des droits administrateur.
.PARAMETER MacAddress
    Adresse MAC souhaitée (format accepté : XX-XX-XX-XX-XX-XX, XX:XX:XX:XX:XX:XX ou sans séparateur).
.PARAMETER Reset
    Supprime l'adresse personnalisée pour restaurer la MAC d'origine.
.PARAMETER AdapterName
    Nom ou description partielle de l'adaptateur cible (optionnel, sinon une liste sera affichée).
.EXAMPLE
    .\Change-MacAddress.ps1 -MacAddress "00-11-22-33-44-55"
    Définit la MAC 00-11-22-33-44-55 sur l'interface choisie.
.EXAMPLE
    .\Change-MacAddress.ps1 -AdapterName "Ethernet" -MacAddress "AABBCCDDEEFF"
    Définit la MAC AABBCCDDEEFF sur l'interface contenant "Ethernet".
.EXAMPLE
    .\Change-MacAddress.ps1 -Reset
    Réinitialise la MAC d'origine de l'interface sélectionnée.
#>
#Requires -RunAsAdministrator

param(
    [string]$MacAddress,
    [switch]$Reset,
    [string]$AdapterName
)

# Nettoyer et valider l'adresse MAC
function Test-MacAddress {
    param([string]$Mac)
    # Supprimer tous les séparateurs courants
    $clean = $Mac -replace '[^0-9A-Fa-f]', ''
    if ($clean.Length -ne 12) {
        return $false
    }
    return $true
}

function Format-MacAddress {
    param([string]$Mac)
    # Retourne une chaîne sans séparateur, en majuscules
    return ($Mac -replace '[^0-9A-Fa-f]', '').ToUpper()
}

# Vérifier que nous sommes bien administrateur (déjà fait par #Requires, sécurité supplémentaire)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERREUR : Ce script doit être exécuté en tant qu'administrateur." -ForegroundColor Red
    exit 1
}

# Obtenir la liste des adaptateurs réseau physiques disponibles
$adapters = Get-NetAdapter | Where-Object { $_.Status -ne 'Not Present' -and $_.Virtual -eq $false } | Sort-Object Name
if (-not $adapters) {
    Write-Host "Aucun adaptateur réseau physique trouvé." -ForegroundColor Yellow
    exit 1
}

# Sélection de l'adaptateur
$selectedAdapter = $null
if ($AdapterName) {
    # Recherche par nom ou description partielle
    $selectedAdapter = $adapters | Where-Object { $_.Name -like "*$AdapterName*" -or $_.InterfaceDescription -like "*$AdapterName*" } | Select-Object -First 1
    if (-not $selectedAdapter) {
        Write-Host "Aucun adaptateur trouvé avec le nom/description '$AdapterName'." -ForegroundColor Red
        exit 1
    }
} else {
    # Affichage interactif
    Write-Host "`nSélectionnez l'adaptateur réseau à modifier :" -ForegroundColor Cyan
    for ($i = 0; $i -lt $adapters.Count; $i++) {
        $mac = $adapters[$i].MacAddress
        Write-Host "[$($i+1)] $($adapters[$i].Name) ($($adapters[$i].InterfaceDescription)) - MAC actuelle : $mac"
    }
    do {
        $choice = Read-Host "`nEntrez le numéro de l'adaptateur"
        [int]$num = 0
        $valid = [int]::TryParse($choice, [ref]$num)
    } until ($valid -and $num -ge 1 -and $num -le $adapters.Count)
    $selectedAdapter = $adapters[$num - 1]
}

$adapterName = $selectedAdapter.Name
$adapterGuid = $selectedAdapter.InterfaceGuid
Write-Host "`nAdaptateur sélectionné : $adapterName (GUID: $adapterGuid)" -ForegroundColor Green

# Trouver la clé de registre correspondante
$classKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
$adapterRegKey = $null
Get-ChildItem $classKeyPath | ForEach-Object {
    $netCfg = (Get-ItemProperty -Path $_.PSPath -Name "NetCfgInstanceId" -ErrorAction SilentlyContinue).NetCfgInstanceId
    if ($netCfg -eq $adapterGuid) {
        $adapterRegKey = $_.PSPath
    }
}

if (-not $adapterRegKey) {
    Write-Host "ERREUR : Impossible de localiser la clé de registre de cet adaptateur." -ForegroundColor Red
    exit 1
}

# Appliquer la modification
if ($Reset) {
    Write-Host "Réinitialisation de l'adresse MAC vers la valeur d'origine..." -ForegroundColor Cyan
    Remove-ItemProperty -Path $adapterRegKey -Name "NetworkAddress" -ErrorAction SilentlyContinue
} else {
    # Demander la MAC si non fournie
    if (-not $MacAddress) {
        do {
            $MacAddress = Read-Host "Entrez la nouvelle adresse MAC (ex: 00-11-22-33-44-55)"
        } until (Test-MacAddress $MacAddress)
    } elseif (-not (Test-MacAddress $MacAddress)) {
        Write-Host "ERREUR : Adresse MAC invalide. Utilisez 12 caractères hexadécimaux (séparateurs optionnels)." -ForegroundColor Red
        exit 1
    }
    $cleanMac = Format-MacAddress $MacAddress
    Write-Host "Nouvelle adresse MAC : $cleanMac" -ForegroundColor Cyan
    Set-ItemProperty -Path $adapterRegKey -Name "NetworkAddress" -Value $cleanMac -Type String
}

# Désactiver puis réactiver l'interface pour appliquer le changement
Write-Host "Désactivation de l'interface '$adapterName'..." -ForegroundColor Yellow
Disable-NetAdapter -Name $adapterName -Confirm:$false
Start-Sleep -Seconds 2
Write-Host "Réactivation de l'interface '$adapterName'..." -ForegroundColor Yellow
Enable-NetAdapter -Name $adapterName -Confirm:$false
Start-Sleep -Seconds 2

# Vérification du résultat
$updatedAdapter = Get-NetAdapter -Name $adapterName
if ($Reset) {
    Write-Host "Adresse MAC restaurée : $($updatedAdapter.MacAddress)" -ForegroundColor Green
} else {
    if ($updatedAdapter.MacAddress -eq $cleanMac) {
        Write-Host "Succès : l'adresse MAC a été changée en $($updatedAdapter.MacAddress)." -ForegroundColor Green
    } else {
        Write-Host "Attention : l'adresse MAC actuelle est $($updatedAdapter.MacAddress) au lieu de $cleanMac. Vérifiez que la carte supporte le changement." -ForegroundColor Red
    }
}
