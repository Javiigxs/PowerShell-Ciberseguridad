function Verificar-Archivo {
    param (
        [string]$Ruta
    )

    try {
               if (Test-Path $Ruta) {
            Write-Output "El archivo existe: $Ruta"
        } else {
            Write-Output "El archivo NO existe: $Ruta"
        }
    }
    catch {
        Write-Output "Error: $_"
    }
    finally {
        Write-Host "Verificación finalizada para: $Ruta" -ForegroundColor Cyan
    }
}

<# Ejemplo de uso:
 Verificar-Archivo -Ruta "C:\Users\PersonalUser\Desktop\archivo.txt"
 #>
