# TraderLogJournal — Supabase keepalive
# Zapobiega pauzie projektu Free (pauza po 7 dniach bez aktywnosci)
# Uruchamiaj co 5 dni przez Windows Task Scheduler

$SB_URL  = "https://ygrkcynyduuflzvbkkvo.supabase.co"
$SB_ANON = "sb_publishable_-aRakEBT-U17VQJHksmK1Q_TbL1cToK"

try {
    $headers = @{
        "apikey"        = $SB_ANON
        "Authorization" = "Bearer $SB_ANON"
    }
    $res = Invoke-WebRequest -Uri "$SB_URL/rest/v1/accounts?select=id&limit=1" `
        -Headers $headers -TimeoutSec 10 -UseBasicParsing
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    Add-Content -Path "$PSScriptRoot\keepalive.log" -Value "$ts — OK ($($res.StatusCode))"
    Write-Host "Keepalive OK: $($res.StatusCode)"
} catch {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    Add-Content -Path "$PSScriptRoot\keepalive.log" -Value "$ts — BLAD: $_"
    Write-Warning "Keepalive blad: $_"
}
