
#!/bin/bash
set -euo pipefail

# ---------- Configuración ----------
WORKDIR="$(mktemp -d /tmp/auditoria_john.XXXXXX)"
PASSWD_SRC="/etc/passwd"
SHADOW_SRC="/etc/shadow"
UNSHADOW_FILE="$WORKDIR/unshadow.txt"
ROCKYOU_CANDIDATES=(
  "/usr/share/wordlists/rockyou.txt"
  "/usr/share/wordlists/rockyou.txt.gz"
  "/usr/dict/rockyou.txt"
)
ROCKYOU=""
REPORT_FILE="reporte_contraseñas.txt"
# -----------------------------------

cleanup() {
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "Directorio temporal: $WORKDIR"

# Comprobaciones básicas
command -v john >/dev/null 2>&1 || { echo "ERROR: john no está instalado o no está en PATH."; exit 2; }
command -v unshadow >/dev/null 2>&1 || { echo "ERROR: la utilidad unshadow no está disponible."; exit 2; }

# Determinar rockyou.txt disponible (si hay rockyou.gz lo descomprimimos a temp)
for f in "${ROCKYOU_CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then
    if [[ "$f" == *.gz ]]; then
      echo "Encontrado rockyou.gz en: $f -> descomprimiendo a $WORKDIR/rockyou.txt ..."
      gunzip -c "$f" > "$WORKDIR/rockyou.txt"
      ROCKYOU="$WORKDIR/rockyou.txt"
    else
      ROCKYOU="$f"
    fi
    break
  fi
done

if [[ -z "$ROCKYOU" ]]; then
  echo "Advertencia: no se encontró rockyou.txt en ubicaciones comunes."
  echo "Por favor coloca rockyou.txt en /usr/share/wordlists/ o en la misma carpeta del script y vuelve a ejecutar."
  exit 3
fi

# Copiar /etc/passwd y /etc/shadow a trabajo (se requieren permisos)
echo "Copiando $PASSWD_SRC y $SHADOW_SRC a $WORKDIR..."
sudo cp "$PASSWD_SRC" "$WORKDIR/passwd.copy"
sudo cp "$SHADOW_SRC" "$WORKDIR/shadow.copy"
chmod 600 "$WORKDIR/shadow.copy" || true

# Crear archivo unshadow (combina passwd+shadow)
echo "Generando archivo unshadow..."
unshadow "$WORKDIR/passwd.copy" "$WORKDIR/shadow.copy" > "$UNSHADOW_FILE"

# Ejecutar john con rockyou (espera hasta que termine)
echo "Ejecutando john (diccionario: $ROCKYOU). Este proceso esperará hasta finalizar..."
john --wordlist="$ROCKYOU" --rules "$UNSHADOW_FILE"

# Obtener lista de usuarios cuyo hash fue descifrado
echo "Obteniendo lista de usuarios descifrados por john..."
# john --show produce líneas "usuario:contraseña" seguidas de un resumen; extraemos sólo los pares usuario:pass
CRACKED_RAW="$(john --show "$UNSHADOW_FILE" 2>/dev/null || true)"

# Extraer sólo las líneas con formato usuario:password (antes de la línea vacía final)
CRACKED_USERS=()
if [[ -n "$CRACKED_RAW" ]]; then
  # tomar sólo las líneas hasta la primera línea vacía (john coloca una línea vacía antes de las estadísticas)
  CRACKED_LINES="$(printf "%s\n" "$CRACKED_RAW" | sed '/^$/q')"
  while IFS= read -r line; do
    # ignorar líneas que no contengan ":" o que sean estadísticas
    if [[ "$line" == *:* ]]; then
      user="$(printf "%s" "$line" | cut -d: -f1)"
      # evitar líneas vacías
      if [[ -n "$user" ]]; then
        CRACKED_USERS+=("$user")
      fi
    fi
  done <<< "$CRACKED_LINES"
fi

# Crear set para búsqueda rápida
declare -A CRACKED_MAP
for u in "${CRACKED_USERS[@]}"; do
  CRACKED_MAP["$u"]=1
done

# Obtener la lista de usuarios presentes en el unshadow (primera columna)
ALL_USERS=()
while IFS= read -r u; do
  # saltar líneas vacías
  [[ -z "$u" ]] && continue
  ALL_USERS+=("$u")
done < <(cut -d: -f1 "$UNSHADOW_FILE" | sort -u)

# Generar reporte (formato Markdown/tabla simple con pipes)
REPORT_PATH="$PWD/$REPORT_FILE"
{
  printf "Usuario | Estado de contraseña\n"
  printf "--------|----------------------\n"
  for u in "${ALL_USERS[@]}"; do
    if [[ -n "${CRACKED_MAP[$u]:-}" ]]; then
      estado="Débil"
    else
      estado="Fuerte"
    fi
    printf "%s | %s\n" "$u" "$estado"
  done
} > "$REPORT_PATH"

echo
echo "Reporte generado en: $REPORT_PATH"
echo "Contenido del reporte:"
cat "$REPORT_PATH"
echo
echo "Fin de la auditoría."
