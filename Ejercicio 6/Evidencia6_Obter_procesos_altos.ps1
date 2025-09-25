$fecha = $($(Get-Date -format yyyy_MM_dd))
Get-Process | Where-Object { $_.WorkingSet -gt 10MB } | Out-File -FilePath Procesos_Filtrados_$fecha.txt