#!/bin/bash
# ============================================================
#  PROYECTO FINAL - ADMINISTRACIÓN DE REDES
#  Sector: Secretaría de Salud
#  Sistema integral de:
#   - Gestión de usuarios y grupos
#   - Automatización (cron, at)
#   - Respaldos (rsync, tar, gzip, bzip2, dump/restore)
#   - Seguridad y monitoreo (Nagios, iftop/vnstat, nmap, wireshark)
#  Entorno objetivo: AlmaLinux 9
# ============================================================

# ---------- Validación de root ----------
if [ "$EUID" -ne 0 ]; then
    echo "============================================"
    echo " ACCESO DENEGADO: este script requiere root "
    echo "============================================"
    exit 1
fi

# ---------- Funciones auxiliares ----------
pausa() {
    echo
    read -rp "Presiona ENTER para continuar..." _
}

cabecera() {
    clear
    echo "====================================================="
    echo " SECRETARÍA DE SALUD - SISTEMA DE ADMINISTRACIÓN TI "
    echo "====================================================="
    echo
}

# ============================================================
#                 GESTIÓN DE USUARIOS
# ============================================================

crear_usuario() {
    cabecera
    echo "=== Alta de usuario (Secretaría de Salud) ==="
    read -rp "Nombre de usuario: " user
    read -rp "Nombre completo (comentario): " nombre
    read -rp "Grupo principal (directivos, medicos, enfermeria, administrativos, epidemiologia, ti): " grupo
    read -rp "Fecha de caducidad (YYYY-MM-DD, vacío para sin caducidad): " cad

    # Verificar si el grupo existe
    if ! getent group "$grupo" >/dev/null 2>&1; then
        echo "El grupo '$grupo' no existe. ¿Deseas crearlo? (s/n)"
        read -r opg
        if [ "$opg" = "s" ] || [ "$opg" = "S" ]; then
            groupadd "$grupo"
            echo "Grupo '$grupo' creado."
        else
            echo "Operación cancelada."
            pausa
            return
        fi
    fi

    if id "$user" >/dev/null 2>&1; then
        echo "El usuario '$user' ya existe."
        pausa
        return
    fi

    if [ -z "$cad" ]; then
        useradd -m -c "$nombre" -g "$grupo" "$user"
    else
        useradd -m -c "$nombre" -g "$grupo" -e "$cad" "$user"
    fi

    if [ $? -eq 0 ]; then
        echo "Usuario '$user' creado correctamente."
        passwd "$user"
    else
        echo "Error al crear el usuario."
    fi
    pausa
}

baja_usuario() {
    cabecera
    echo "=== Baja de usuario ==="
    read -rp "Usuario a eliminar: " user

    if ! id "$user" >/dev/null 2>&1; then
        echo "El usuario '$user' no existe."
        pausa
        return
    fi

    echo "¿Deseas eliminar también su directorio home? (s/n)"
    read -r op
    if [ "$op" = "s" ] || [ "$op" = "S" ]; then
        userdel -r "$user"
    else
        userdel "$user"
    fi

    if [ $? -eq 0 ]; then
        echo "Usuario '$user' eliminado correctamente."
    else
        echo "Error al eliminar el usuario."
    fi
    pausa
}

consulta_usuario() {
    cabecera
    echo "=== Consulta de usuario ==="
    read -rp "Usuario a consultar: " user

    if id "$user" >/dev/null 2>&1; then
        echo "Información de '$user':"
        id "$user"
        echo
        echo "Entrada en /etc/passwd:"
        getent passwd "$user"
        echo
        echo "Información de caducidad (chage):"
        chage -l "$user"
    else
        echo "El usuario '$user' NO existe."
    fi
    pausa
}

modificar_usuario() {
    while true; do
        cabecera
        echo "=== Modificación de usuario ==="
        read -rp "Usuario a modificar: " user

        if ! id "$user" >/dev/null 2>&1; then
            echo "El usuario '$user' no existe."
            pausa
            return
        fi

        echo "Usuario: $user"
        echo "1) Cambiar fecha de caducidad"
        echo "2) Bloquear cuenta"
        echo "3) Desbloquear cuenta"
        echo "4) Cambiar directorio home"
        echo "5) Cambiar grupo principal"
        echo "6) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1)
                read -rp "Nueva fecha de caducidad (YYYY-MM-DD, vacío para sin caducidad): " cad
                if [ -z "$cad" ]; then
                    chage -E -1 "$user"
                else
                    chage -E "$cad" "$user"
                fi
                echo "Caducidad actualizada."
                pausa
                ;;
            2)
                usermod -L "$user"
                echo "Cuenta bloqueada."
                pausa
                ;;
            3)
                usermod -U "$user"
                echo "Cuenta desbloqueada."
                pausa
                ;;
            4)
                read -rp "Nuevo directorio home (ruta completa): " nhome
                usermod -d "$nhome" -m "$user"
                echo "Directorio home actualizado."
                pausa
                ;;
            5)
                read -rp "Nuevo grupo principal: " ngrupo
                if ! getent group "$ngrupo" >/dev/null 2>&1; then
                    echo "El grupo '$ngrupo' no existe."
                else
                    usermod -g "$ngrupo" "$user"
                    echo "Grupo principal actualizado."
                fi
                pausa
                ;;
            6)
                return
                ;;
            *)
                echo "Opción no válida."
                pausa
                ;;
        esac
    done
}

procesos_usuario() {
    cabecera
    echo "=== Procesos del usuario ==="
    read -rp "Usuario a consultar: " user

    if ! id "$user" >/dev/null 2>&1; then
        echo "El usuario '$user' no existe."
        pausa
        return
    fi

    echo "Procesos que pertenecen a '$user':"
    ps -u "$user" || echo "No se pudieron listar procesos."
    pausa
}

menu_usuarios() {
    while true; do
        cabecera
        echo "=== Gestión de usuarios ==="
        echo "1) Alta de usuario"
        echo "2) Baja de usuario"
        echo "3) Consulta de usuario"
        echo "4) Modificación de usuario"
        echo "5) Ver procesos de usuario"
        echo "6) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) crear_usuario ;;
            2) baja_usuario ;;
            3) consulta_usuario ;;
            4) modificar_usuario ;;
            5) procesos_usuario ;;
            6) return ;;
            *) echo "Opción no válida."; pausa ;;
        esac
    done
}

# ============================================================
#                 GESTIÓN DE GRUPOS
# ============================================================

alta_grupo() {
    cabecera
    echo "=== Alta de grupo ==="
    read -rp "Nombre de grupo: " grupo

    if getent group "$grupo" >/dev/null 2>&1; then
        echo "El grupo '$grupo' ya existe."
    else
        groupadd "$grupo"
        if [ $? -eq 0 ]; then
            echo "Grupo '$grupo' creado correctamente."
        else
            echo "Error al crear el grupo."
        fi
    fi
    pausa
}

baja_grupo() {
    cabecera
    echo "=== Baja de grupo ==="
    read -rp "Nombre de grupo a eliminar: " grupo

    if ! getent group "$grupo" >/dev/null 2>&1; then
        echo "El grupo '$grupo' no existe."
        pausa
        return
    fi

    groupdel "$grupo"
    if [ $? -eq 0 ]; then
        echo "Grupo '$grupo' eliminado correctamente."
    else
        echo "Error al eliminar el grupo."
    fi
    pausa
}

consulta_grupo() {
    cabecera
    echo "=== Consulta de grupo ==="
    read -rp "Nombre de grupo: " grupo

    if getent group "$grupo" >/dev/null 2>&1; then
        echo "Información de grupo:"
        getent group "$grupo"
    else
        echo "El grupo '$grupo' NO existe."
    fi
    pausa
}

modificar_grupo() {
    while true; do
        cabecera
        echo "=== Modificación de grupo ==="
        read -rp "Nombre de grupo a modificar: " grupo

        if ! getent group "$grupo" >/dev/null 2>&1; then
            echo "El grupo '$grupo' no existe."
            pausa
            return
        fi

        echo "Grupo actual: $grupo"
        echo "1) Cambiar nombre del grupo"
        echo "2) Cambiar GID"
        echo "3) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1)
                read -rp "Nuevo nombre del grupo: " ngrupo
                groupmod -n "$ngrupo" "$grupo"
                echo "Nombre de grupo actualizado."
                grupo="$ngrupo"
                pausa
                ;;
            2)
                read -rp "Nuevo GID: " ngid
                groupmod -g "$ngid" "$grupo"
                echo "GID actualizado."
                pausa
                ;;
            3)
                return
                ;;
            *)
                echo "Opción no válida."
                pausa
                ;;
        esac
    done
}

menu_grupos() {
    while true; do
        cabecera
        echo "=== Gestión de grupos ==="
        echo "1) Alta de grupo"
        echo "2) Baja de grupo"
        echo "3) Consulta de grupo"
        echo "4) Modificación de grupo"
        echo "5) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) alta_grupo ;;
            2) baja_grupo ;;
            3) consulta_grupo ;;
            4) modificar_grupo ;;
            5) return ;;
            *) echo "Opción no válida."; pausa ;;
        esac
    done
}

# ============================================================
#                 AUTOMATIZACIÓN (CRON / AT)
# ============================================================

programar_cron() {
    cabecera
    echo "=== Programar tarea con cron ==="
    echo "Formato: minuto hora dia_mes mes dia_semana"
    echo "Ejemplo diario a las 2:00am -> 0 2 * * *"
    read -rp "Expresión de tiempo (ej: 0 2 * * *): " tiempo
    read -rp "Comando a ejecutar (ruta completa recomendada): " comando

    (crontab -l 2>/dev/null; echo "$tiempo $comando") | crontab -
    if [ $? -eq 0 ]; then
        echo "Tarea programada correctamente en cron."
    else
        echo "Error al programar en cron."
    fi
    pausa
}

listar_cron() {
    cabecera
    echo "=== Tareas cron del usuario root ==="
    crontab -l 2>/dev/null || echo "No hay tareas cron."
    pausa
}

programar_at() {
    cabecera
    echo "=== Programar tarea con at ==="
    echo "Ejemplos:"
    echo "  now + 5 minutes"
    echo "  10:30"
    echo "  18:00 tomorrow"
    read -rp "Tiempo (ej: now + 5 minutes): " tiempo
    read -rp "Comando a ejecutar: " comando

    echo "$comando" | at "$tiempo"
    if [ $? -eq 0 ]; then
        echo "Tarea programada con at."
    else
        echo "Error al programar con at."
    fi
    pausa
}

listar_at() {
    cabecera
    echo "=== Tareas at pendientes ==="
    atq || echo "No hay tareas at pendientes."
    pausa
}

menu_automatizacion() {
    while true; do
        cabecera
        echo "=== Automatización de tareas ==="
        echo "1) Programar tarea con cron"
        echo "2) Ver tareas cron"
        echo "3) Programar tarea con at"
        echo "4) Ver tareas at"
        echo "5) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) programar_cron ;;
            2) listar_cron ;;
            3) programar_at ;;
            4) listar_at ;;
            5) return ;;
            *) echo "Opción no válida."; pausa ;;
        esac
    done
}

# ============================================================
#                 RESPALDOS
# ============================================================

backup_rsync() {
    cabecera
    echo "=== Respaldo con rsync (expedientes, configs, etc.) ==="
    read -rp "Directorio origen (ej: /etc): " origen
    read -rp "Directorio destino (ej: /respaldos/etc): " destino

    mkdir -p "$destino"
    rsync -avh --delete "$origen"/ "$destino"/
    if [ $? -eq 0 ]; then
        echo "Respaldo completado con rsync."
    else
        echo "Error en el respaldo con rsync."
    fi
    pausa
}

backup_tar_gzip() {
    cabecera
    echo "=== Respaldo comprimido (tar + gzip) ==="
    read -rp "Directorio origen (ej: /var/log): " origen
    read -rp "Ruta del archivo destino (ej: /respaldos/logs.tar.gz): " archivo

    mkdir -p "$(dirname "$archivo")"
    tar -czvf "$archivo" "$origen"
    if [ $? -eq 0 ]; then
        echo "Respaldo creado en $archivo"
    else
        echo "Error al crear respaldo."
    fi
    pausa
}

backup_tar_bzip2() {
    cabecera
    echo "=== Respaldo comprimido (tar + bzip2) ==="
    read -rp "Directorio origen (ej: /var/log): " origen
    read -rp "Ruta del archivo destino (ej: /respaldos/logs.tar.bz2): " archivo

    mkdir -p "$(dirname "$archivo")"
    tar -cjvf "$archivo" "$origen"
    if [ $? -eq 0 ]; then
        echo "Respaldo creado en $archivo"
    else
        echo "Error al crear respaldo."
    fi
    pausa
}

backup_dump() {
    cabecera
    echo "=== Respaldos con dump ==="
    echo "NOTA: Esta acción se usa para sistemas de archivos (ej: /dev/sda1)."
    read -rp "Dispositivo (ej: /dev/sda1): " dispositivo
    read -rp "Ruta del archivo de respaldo (ej: /respaldos/root.dump): " archivo

    mkdir -p "$(dirname "$archivo")"
    if ! command -v dump >/dev/null 2>&1; then
        echo "El comando 'dump' no está instalado. En AlmaLinux puedes instalarlo con:"
        echo "  dnf install dump"
        pausa
        return
    fi

    dump -0u -f "$archivo" "$dispositivo"
    if [ $? -eq 0 ]; then
        echo "Respaldo dump completado."
    else
        echo "Error al ejecutar dump."
    fi
    pausa
}

restore_dump() {
    cabecera
    echo "=== Restaurar con restore ==="
    echo "ATENCIÓN: Restaurar puede sobrescribir datos. Úsalo con cuidado."
    read -rp "Ruta del archivo dump (ej: /respaldos/root.dump): " archivo

    if ! command -v restore >/dev/null 2>&1; then
        echo "El comando 'restore' no está instalado. Instálalo con:"
        echo "  dnf install dump"
        pausa
        return
    fi

    echo "Se iniciará restore en modo interactivo:"
    echo "Algunos comandos de restore: ls, cd, add, extract, quit"
    echo "Puedes restaurar en el directorio actual (ejecuta con precaución)."
    cd / || exit 1
    restore -i -f "$archivo"
    pausa
}

menu_respaldos() {
    while true; do
        cabecera
        echo "=== Respaldos de la información ==="
        echo "1) Respaldo con rsync"
        echo "2) Respaldo comprimido tar + gzip"
        echo "3) Respaldo comprimido tar + bzip2"
        echo "4) Respaldar filesystem con dump"
        echo "5) Restaurar desde dump"
        echo "6) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) backup_rsync ;;
            2) backup_tar_gzip ;;
            3) backup_tar_bzip2 ;;
            4) backup_dump ;;
            5) restore_dump ;;
            6) return ;;
            *) echo "Opción no válida."; pausa ;;
        esac
    done
}

# ============================================================
#                 SEGURIDAD Y MONITOREO
# ============================================================

nagios_status() {
    cabecera
    echo "=== Estado de Nagios ==="
    echo "Si no lo tienes instalado, se sugiere:"
    echo "  dnf install nagios nagios-plugins-all httpd php"
    echo "y seguir la guía de configuración para monitorear servicios de la Secretaría de Salud."
    echo
    if systemctl list-unit-files | grep -q nagios; then
        systemctl status nagios --no-pager
    else
        echo "El servicio nagios no está instalado/registrado."
    fi
    pausa
}

herramienta_trafico() {
    cabecera
    echo "=== Monitoreo de tráfico (iftop / vnstat) ==="
    echo "1) iftop (monitoreo en tiempo real)"
    echo "2) vnstat (estadísticas guardadas)"
    echo "3) Regresar"
    read -rp "Opción: " op

    case "$op" in
        1)
            if command -v iftop >/dev/null 2>&1; then
                iftop
            else
                echo "iftop no está instalado. Puedes instalarlo con:"
                echo "  dnf install iftop"
                pausa
            fi
            ;;
        2)
            if command -v vnstat >/dev/null 2>&1; then
                vnstat
            else
                echo "vnstat no está instalado. Puedes instalarlo con:"
                echo "  dnf install vnstat"
                pausa
            fi
            ;;
        3) ;;
        *)
            echo "Opción no válida."
            pausa
            ;;
    esac
}

herramientas_red() {
    cabecera
    echo "=== Herramientas de seguridad de red (nmap / wireshark) ==="
    echo "1) Escanear puertos con nmap"
    echo "2) Ejecutar wireshark (modo GUI, si está disponible)"
    echo "3) Regresar"
    read -rp "Opción: " op

    case "$op" in
        1)
            if command -v nmap >/dev/null 2>&1; then
                read -rp "IP o rango a escanear (ej: 192.168.1.0/24): " iprango
                nmap -sV "$iprango"
            else
                echo "nmap no está instalado. Instálalo con:"
                echo "  dnf install nmap"
                pausa
            fi
            ;;
        2)
            if command -v wireshark >/dev/null 2>&1; then
                echo "Se intentará abrir wireshark (requiere entorno gráfico)."
                wireshark &
            else
                echo "wireshark no está instalado. Instálalo con:"
                echo "  dnf install wireshark wireshark-qt"
                pausa
            fi
            ;;
        3) ;;
        *)
            echo "Opción no válida."
            pausa
            ;;
    esac
}

menu_seguridad() {
    while true; do
        cabecera
        echo "=== Seguridad y monitoreo ==="
        echo "1) Ver estado de Nagios"
        echo "2) Monitoreo de tráfico (iftop / vnstat)"
        echo "3) Escaneo y captura (nmap / wireshark)"
        echo "4) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) nagios_status ;;
            2) herramienta_trafico ;;
            3) herramientas_red ;;
            4) return ;;
            *) echo "Opción no válida."; pausa ;;
        esac
    done
}

# ============================================================
#                 MENÚ PRINCIPAL
# ============================================================

while true; do
    cabecera
    echo "MENÚ PRINCIPAL - SERVIDOR INSTITUCIONAL DE LA SECRETARÍA DE SALUD"
    echo "1) Gestión de usuarios"
    echo "2) Gestión de grupos"
    echo "3) Automatización de tareas (cron / at)"
    echo "4) Respaldos de la información"
    echo "5) Seguridad y monitoreo"
    echo "6) Salir"
    echo
    read -rp "Elige una opción: " op

    case "$op" in
        1) menu_usuarios ;;
        2) menu_grupos ;;
        3) menu_automatizacion ;;
        4) menu_respaldos ;;
        5) menu_seguridad ;;
        6)
            echo "Saliendo del sistema. Hasta luego."
            exit 0
            ;;
        *)
            echo "Opción no válida."
            pausa
            ;;
    esac
done
