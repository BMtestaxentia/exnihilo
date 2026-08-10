# Recuperation des sauvegardes SFO depuis la VM vers le poste (option C).
#
#   powershell -ExecutionPolicy Bypass -File deploy\recuperer-sauvegardes.ps1
#
# Copie les archives absentes en local et verifie leur empreinte sha256.
# Utilise l'alias SSH "sfo" deja configure dans ~/.ssh/config.
#
# Destination par defaut : un dossier OneDrive, donc lui-meme replique.
# ATTENTION : ces archives contiennent l'integralite des donnees d'exploitation.
# Ne pas les deposer dans un dossier partage.

param(
  [string]$Destination = "$env:OneDrive\SFO-sauvegardes",
  [int]$Garder = 30
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination -Force | Out-Null }
Write-Host "Destination : $Destination"

# 1. La VM repond-elle ?
$test = & ssh -o BatchMode=yes -o ConnectTimeout=15 sfo 'echo pret' 2>$null
if ($test -ne 'pret') { Write-Host "VM injoignable (eteinte ?). Rien a faire." -ForegroundColor Yellow; exit 1 }

# 2. Liste des archives disponibles cote VM.
$distantes = (& ssh -o BatchMode=yes sfo 'ls -1 /var/backups/exnihilo_*.sql.gz 2>/dev/null') |
             Where-Object { $_ -match 'exnihilo_\d{4}-\d{2}-\d{2}\.sql\.gz$' }
if (-not $distantes) { Write-Host "Aucune sauvegarde trouvee sur la VM." -ForegroundColor Yellow; exit 1 }

$copiees = 0
foreach ($chemin in $distantes) {
  $nom = Split-Path $chemin -Leaf
  $local = Join-Path $Destination $nom
  if (Test-Path $local) { continue }

  & scp -q "sfo:$chemin" $local
  if (-not (Test-Path $local)) { Write-Host "  ECHEC : $nom" -ForegroundColor Red; continue }

  # 3. Verification de l'empreinte : une copie tronquee ne sert a rien.
  $attendu = (& ssh -o BatchMode=yes sfo "cat '$chemin.sha256' 2>/dev/null") | Select-Object -First 1
  if ($attendu) {
    $obtenu = (Get-FileHash -Path $local -Algorithm SHA256).Hash.ToLower()
    if ($obtenu -ne $attendu.Trim().ToLower()) {
      Write-Host "  EMPREINTE INVALIDE : $nom (copie supprimee)" -ForegroundColor Red
      Remove-Item $local -Force; continue
    }
  }
  $taille = [math]::Round((Get-Item $local).Length / 1KB, 0)
  Write-Host "  copie : $nom ($taille Ko)" -ForegroundColor Green
  $copiees++
}

# 4. Retention locale.
Get-ChildItem -Path $Destination -Filter 'exnihilo_*.sql.gz' |
  Sort-Object Name -Descending | Select-Object -Skip $Garder |
  ForEach-Object { Remove-Item $_.FullName -Force }

$total = (Get-ChildItem -Path $Destination -Filter 'exnihilo_*.sql.gz').Count
Write-Host ""
Write-Host "$copiees nouvelle(s) archive(s) ; $total conservee(s) en local."
