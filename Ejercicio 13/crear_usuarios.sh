#!/bin/bash

# Archivo de entrada
ARCHIVO="Usuarios.txt"

# Verificar si el archivo existe
if [[ ! -f "$ARCHIVO" ]]; then
    echo "Error: No se encuentra el archivo $ARCHIVO"
    exit 1
fi

# Leer cada línea del archivo
while read -r linea; do
    # Separar por espacio cada usuario:contraseña
    for par in $linea; do
        usuario=$(echo "$par" | cut -d: -f1)
        contrasena=$(echo "$par" | cut -d: -f2)

        # Crear usuario
        sudo useradd -m "$usuario" 2>/dev/null

        # Asignar contraseña
        echo "$usuario:$contrasena" | sudo chpasswd

        # Mensaje de confirmación
        echo "Usuario creado: $usuario"
    done
done < "$ARCHIVO"
