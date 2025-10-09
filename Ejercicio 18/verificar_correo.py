import sys, requests, time
if len(sys.argv) != 2:
    print("Uso: python verificar_correo.py correo@example.com")
    sys.exit(1)

correo = sys.argv[1]

try:
    with open("apikey.txt", "r") as archivo:
        api_key = archivo.read().strip()
except FileNotFoundError:
    print("Error: No se encontró el archivo apikey.txt")
    sys.exit(1)

url = f"https://haveibeenpwned.com/api/v3/breachedaccount/{correo}"

headers = {
    "hibp-api-key": api_key,
    "user-agent": "PythonScript"
}

response = requests.get(url, headers=headers)

if response.status_code == 200:
    brechas = response.json()
    print(f"\nLa cuenta {correo} ha sido comprometida en {len(brechas)} brechas.")
    print("Mostrando detalles de las primeras 3 brechas:\n")
   
    for i, brecha in enumerate(brechas[:3]):
        nombre = brecha['Name']
        detalle_url = f"https://haveibeenpwned.com/api/v3/breach/{nombre}"
        detalle_resp = requests.get(detalle_url, headers=headers)
       
        if detalle_resp.status_code == 200:
            detalle = detalle_resp.json()
            print(f"Brecha {i+1}: {detalle.get('Title')}")
            print(f"Dominio: {detalle.get('Domain')}")
            print(f"Fecha de brecha: {detalle.get('BreachDate')}")
            print(f"Fecha registrada: {detalle.get('AddedDate')}")
            print(f"Datos comprometidos: {', '.join(detalle.get('DataClasses', []))}")
            print(f"Descripción: {detalle.get('Description')[:300]}...\n")
            print("-" * 60)
        else:
            print(f"No se pudo obtener detalles de la brecha: {nombre}")
        if i < 2:
            print("Esperando 10 segundos antes de la siguiente consulta...\n")
            time.sleep(10)
elif response.status_code == 404:
    print(f"La cuenta {correo} no aparece en ninguna brecha conocida.")
elif response.status_code == 401:
    print("Error de autenticación: revisa tu API key.")
else:

    print(f"Error inesperado. Código de estado: {response.status_code}")
