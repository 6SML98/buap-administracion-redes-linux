#!/bin/bash
# PROYECTO FINAL - ADMINISTRACIÓN DE REDES
if [[ $EUID -ne 0 ]]; then
    echo "Acceso denegado: este script debe ejecutarse como root."
    exit 1
fi

pause() {
    echo
    read -rp "Presiona ENTER para continuar..." _
}

alta_usuario() {
    clear
    echo " Alta de usuario (personal / administrativo) "
    read -rp "Nombre de usuario: " user
    if id "$user" &>/dev/null; then
        echo "El usuario '$user' ya existe."
    else
        useradd -m "$user"
        echo "Asigna una contraseña para '$user' (médico, enfermería, admin, etc.):"
        passwd "$user"
        echo "Usuario '$user' creado para el sistema de salud."
    fi
    pause
}

baja_usuario() {
    clear
    echo " Baja de usuario (personal / administrativo) "
    read -rp "Nombre de usuario a eliminar: " user
    if id "$user" &>/dev/null; then
        read -rp "¿Eliminar también el directorio home? (s/n): " resp
        if [[ "$resp" == "s" || "$resp" == "S" ]]; then
            userdel -r "$user"
        else
            userdel "$user"
        fi
        echo "Usuario '$user' eliminado del sistema de salud."
    else
        echo "El usuario '$user' NO existe."
    fi
    pause
}

consulta_usuario() {
    clear
    echo " Consulta de usuarios (cuentas del sistema de salud) "
    echo "Usuarios registrados en el sistema (/etc/passwd):"
    echo
    cut -d: -f1 /etc/passwd
    pause
}

modificar_usuario() {
    clear
    echo " Modificaciones de usuario (cuentas del personal) "
    read -rp "Nombre de usuario: " user
    if ! id "$user" &>/dev/null; then
        echo "El usuario '$user' NO existe."
        pause
        return
    fi

    local op
    while true; do
        clear
        echo " Modificaciones de usuario: $user "
        echo "1) Cambiar fecha de caducidad de la cuenta (contrato / acceso)"
        echo "2) Bloquear cuenta (baja temporal)"
        echo "3) Desbloquear cuenta"
        echo "4) Cambiar directorio home"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1)
                read -rp "Nueva fecha (AAAA-MM-DD): " fecha
                chage -E "$fecha" "$user"
                echo "Fecha de caducidad actualizada."
                pause
                ;;
            2)
                usermod -L "$user"
                echo "Cuenta bloqueada (acceso denegado)."
                pause
                ;;
            3)
                usermod -U "$user"
                echo "Cuenta desbloqueada."
                pause
                ;;
            4)
                read -rp "Nuevo directorio home: " newhome
                usermod -d "$newhome" -m "$user"
                echo "Home cambiado."
                pause
                ;;
            0) break ;;
            *) echo "Opción no válida."; pause ;;
        esac
    done
}

menu_usuarios() {
    local op
    while true; do
        clear
        echo " 1. USUARIOS (PERSONAL DEL SECTOR SALUD) "
        echo "1) Alta de usuarios (médicos, enfermería, admin, etc.)"
        echo "2) Baja de usuarios"
        echo "3) Consulta de usuarios"
        echo "4) Modificaciones de usuario"
        echo "0) Regresar"
        read -rp "Elige una opción: " op

        case "$op" in
            1) alta_usuario ;;
            2) baja_usuario ;;
            3) consulta_usuario ;;
            4) modificar_usuario ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

alta_grupo() {
    clear
    echo " Alta de grupo (área: urgencias, laboratorio, farmacia, etc.) "
    read -rp "Nombre del grupo: " group
    if grep -q "^$group:" /etc/group; then
        echo "El grupo '$group' ya existe."
    else
        groupadd "$group"
        echo "Grupo '$group' creado para el área del sector salud."
    fi
    pause
}

baja_grupo() {
    clear
    echo " Baja de grupo (área de trabajo) "
    read -rp "Nombre del grupo a eliminar: " group
    if grep -q "^$group:" /etc/group; then
        groupdel "$group"
        echo "Grupo '$group' eliminado."
    else
        echo "El grupo '$group' NO existe."
    fi
    pause
}

consulta_grupo() {
    clear
    echo " Consulta de grupos (áreas del sistema) "
    echo "Grupos registrados (/etc/group):"
    echo
    cut -d: -f1 /etc/group
    pause
}

modificar_grupo() {
    clear
    echo " Modificar grupo (área / servicio) "
    read -rp "Nombre actual del grupo: " group
    if ! grep -q "^$group:" /etc/group; then
        echo "El grupo '$group' NO existe."
        pause
        return
    fi
    read -rp "Nuevo nombre del grupo: " newgroup
    groupmod -n "$newgroup" "$group"
    echo "Grupo renombrado."
    pause
}

menu_grupos() {
    local op
    while true; do
        clear
        echo " 2. GRUPOS (ÁREAS DEL SECTOR SALUD) "
        echo "1) Alta de grupos (urgencias, laboratorio, farmacia...)"
        echo "2) Baja de grupos"
        echo "3) Consulta de grupos"
        echo "4) Modificaciones de grupos"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) alta_grupo ;;
            2) baja_grupo ;;
            3) consulta_grupo ;;
            4) modificar_grupo ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

procesos_usuario() {
    clear
    echo " Procesos del usuario (sesiones del personal) "
    read -rp "Nombre de usuario: " user
    if id "$user" &>/dev/null; then
        ps -u "$user" -o pid,tty,time,cmd
    else
        echo "El usuario '$user' NO existe."
    fi
    pause
}

menu_gestion_usuarios() {
    local op
    while true; do
        clear
        echo " GESTIÓN DE USUARIOS Y ÁREAS (SECTOR SALUD) "
        echo "1) Usuarios"
        echo "2) Grupos"
        echo "3) Procesos de un usuario"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) menu_usuarios ;;
            2) menu_grupos ;;
            3) procesos_usuario ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

crear_tareas_cron_salud() {
    clear
    echo " CREAR TAREAS CRON (Sector Salud) "
    echo
    echo "Se configurarán tareas relacionadas con:"
    echo "- Sistema de citas médicas"
    echo "- Sistema de expedientes y reportes clínicos"
    echo

    local current
    current="$(crontab -l 2>/dev/null || echo "")"
    local linea1='*/5 * * * * echo "Chequeo automático del sistema de citas médicas de la Secretaría de Salud" >> /root/cron_citas_salud.log'
    local linea2='0 20 * * * echo "Respaldo automático (simulado) del sistema de información de salud (expedientes, reportes)" >> /root/cron_respaldo_salud.log'

    local nuevo="$current"

    if ! echo "$current" | grep -Fq "$linea1"; then
        [[ -n "$nuevo" ]] && nuevo+=$'\n'
        nuevo+="$linea1"
    fi

    if ! echo "$current" | grep -Fq "$linea2"; then
        [[ -n "$nuevo" ]] && nuevo+=$'\n'
        nuevo+="$linea2"
    fi

    printf '%s\n' "$nuevo" | crontab -
    echo "Se han configurado 2 tareas CRON relacionadas con el sector salud."
    echo
    echo "Crontab actual:"
    crontab -l
    pause
}

cron_menu() {
    local op
    while true; do
        clear
        echo " AUTOMATIZACIÓN - CRON (SECTOR SALUD) "
        echo "1) Ver crontab actual"
        echo "2) Editar crontab"
        echo "3) Crear tareas automáticas del sistema de salud"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) crontab -l 2>/dev/null || echo "No hay tareas programadas."; pause ;;
            2) echo "Abriendo crontab..."; sleep 1; crontab -e ;;
            3) crear_tareas_cron_salud ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

programar_at_salud() {
    clear
    echo " PROGRAMAR TAREAS AT (Sector Salud) "
    echo
    echo "Se programarán tareas únicas como si fueran procesos de:"
    echo "- Generación de reportes de pacientes"
    echo "- Verificación de infraestructura (servidores de laboratorio / sistemas clínicos)"
    echo

    echo "1) Programando generación de reporte de pacientes (simulado) en 2 minutos..."
    echo "echo '--- Reporte de pacientes generado (simulado, sistema de salud) ---' >> /root/at_reporte_salud.log; date >> /root/at_reporte_salud.log" | at now + 2 minutes

    echo
    echo "2) Programando verificación de temperatura del servidor de laboratorio (simulada) en 5 minutos..."
    echo "echo '*** Revisar temperatura del servidor de laboratorio del hospital (simulada) ***' >> /root/at_alerta_salud.log; date >> /root/at_alerta_salud.log" | at now + 5 minutes

    echo
    echo "Tareas AT programadas (cola actual):"
    atq || true
    pause
}

at_menu() {
    local op
    while true; do
        clear
        echo " AUTOMATIZACIÓN - AT (SECTOR SALUD) "
        echo "1) Programar tarea ejemplo sencilla"
        echo "2) Programar tareas automáticas del sector salud"
        echo "3) Ver tareas AT"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1)
                echo "echo 'Tarea ejecutada por at (ejemplo sencillo)' >> tarea_at.log" | at now + 2 minutes
                echo "Tarea de ejemplo programada para dentro de 2 minutos."
                pause
                ;;
            2)
                programar_at_salud
                ;;
            3)
                clear
                echo " TAREAS AT PROGRAMADAS "
                atq
                echo

                if [[ -z "$(atq)" ]]; then
                    echo "No hay tareas AT programadas."
                    pause
                else
                    echo "DETALLE DE CADA TAREA"
                    echo
                    atq | awk '{print $1}' | while read -r id; do
                        echo " Detalle de la tarea ID $id"
                        echo "Comando programado:"
                        at -c "$id" | tail -n 5
                        echo
                    done
                    pause
                fi
                ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

menu_automatizacion() {
    local op
    while true; do
        clear
        echo " AUTOMATIZACIÓN DE TAREAS (SECTOR SALUD) "
        echo "1) Cron"
        echo "2) At"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) cron_menu ;;
            2) at_menu ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

rsync_menu() {
    clear
    echo " RESPALDO - RSYNC (SISTEMAS DEL SECTOR SALUD)"
    echo "Directorio actual: $(pwd)"
    echo
    echo "Contenido disponible (por ejemplo: sistemas de citas, expedientes, reportes):"
    ls
    echo
    read -rp "Nombre del directorio origen (ej. sistema_citas, expedientes): " src
    read -rp "Nombre del directorio destino (ej. respaldo_citas, respaldo_expedientes): " dst

    origen="$(pwd)/$src"
    destino="$(pwd)/$dst"

    if [[ ! -d "$origen" ]]; then
        echo "El directorio '$src' no existe."
        pause
        return
    fi

    mkdir -p "$destino"
    rsync -avz "$origen/" "$destino/"
    echo "Respaldo completado en: $destino"
    pause
}

compresores_menu() {
    local op
    while true; do
        clear
        echo " RESPALDO - COMPRESORES (SECTOR SALUD)"
        echo "Directorio actual: $(pwd)"
        echo
        echo "Contenido disponible (aplicaciones, sistemas, datos):"
        ls
        echo
        echo "1) Crear archivo .tar"
        echo "2) Crear archivo .tar.gz"
        echo "3) Crear archivo .tar.bz2"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1)
                read -rp "Nombre del archivo tar (ej. respaldo_salud.tar): " tarname
                read -rp "Nombre del directorio a comprimir (ej. sistema_citas): " dir
                if [[ ! -d "$dir" ]]; then
                    echo "El directorio '$dir' no existe."
                else
                    tar -cvf "$tarname" "$dir"
                    echo "Archivo '$tarname' creado."
                fi
                pause
                ;;
            2)
                read -rp "Nombre del archivo tar.gz (ej. respaldo_salud.tar.gz): " tarname
                read -rp "Nombre del directorio a comprimir: " dir
                if [[ ! -d "$dir" ]]; then
                    echo "El directorio '$dir' no existe."
                else
                    tar -czvf "$tarname" "$dir"
                    echo "Archivo '$tarname' creado."
                fi
                pause
                ;;
            3)
                read -rp "Nombre del archivo tar.bz2 (ej. respaldo_salud.tar.bz2): " tarname
                read -rp "Nombre del directorio a comprimir: " dir
                if [[ ! -d "$dir" ]]; then
                    echo "El directorio '$dir' no existe."
                else
                    tar -cjvf "$tarname" "$dir"
                    echo "Archivo '$tarname' creado."
                fi
                pause
                ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

crear_directorio() {
    clear
    echo " Crear directorio en el directorio actual (por ejemplo: sistema_citas, expedientes, farmacia) "
    echo "Directorio actual: $(pwd)"
    read -rp "Nombre del directorio: " nombre
    if [[ -z "$nombre" ]]; then
        echo "No se ingresó nombre."
    else
        mkdir -p "$nombre"
        echo "Directorio '$(pwd)/$nombre' creado o ya existente."
    fi
    pause
}

ver_contenido() {
    clear
    echo " Ver contenido de un directorio (módulo del sistema de salud)"
    echo "Directorio actual: $(pwd)"
    read -rp "Nombre del directorio: " nombre

    if [[ -z "$nombre" ]]; then
        dir="."
    else
        dir="$nombre"
    fi

    if [[ -d "$dir" ]]; then
        echo "Contenido de: $(pwd)/$dir"
        ls -lh "$dir"
    else
        echo "El directorio '$dir' no existe."
    fi
    pause
}

listar_directorios() {
    clear
    base=$(pwd)
    echo " Directorios en el directorio actual (módulos del sistema de salud) "
    echo "Directorio actual: $base"
    echo
    find "$base" -maxdepth 1 -type d
    pause
}

menu_directorios() {
    local op
    while true; do
        clear
        echo " GESTIÓN DE DIRECTORIOS (SISTEMA DE INFORMACIÓN DE SALUD) "
        echo "1) Crear directorio"
        echo "2) Ver contenido de un directorio"
        echo "3) Listar directorios"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) crear_directorio ;;
            2) ver_contenido ;;
            3) listar_directorios ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

menu_respaldo() {
    local op
    while true; do
        clear
        echo " RESPALDO DE LA INFORMACIÓN (SISTEMA DE SALUD) "
        echo "1) Rsync"
        echo "2) Compresores"
        echo "3) Gestión de directorios"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) rsync_menu ;;
            2) compresores_menu ;;
            3) menu_directorios ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

nagios_monitoreo() {
    clear
    echo " MONITOREO CON NAGIOS (SERVIDORES DEL SECTOR SALUD) "
    echo
    echo "1) Verificando servicio nagios..."
    systemctl status nagios --no-pager 2>/dev/null || echo "Nagios no está instalado o no se encontró el servicio."
    echo
    echo "2) Verificando servicio httpd (Apache)..."
    systemctl status httpd --no-pager 2>/dev/null || echo "httpd no está instalado o no se encontró el servicio."
    echo
    echo "3) Intentando abrir la interfaz web de Nagios..."
    echo

    if command -v firefox &>/dev/null; then
        firefox "http://localhost/nagios" &>/dev/null &
        echo "Se lanzó Firefox con la URL: http://localhost/nagios"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "http://localhost/nagios" &>/dev/null &
        echo "Se lanzó el navegador predeterminado con xdg-open."
    else
        echo "No se encontró un navegador gráfico."
        echo "Abre manualmente en tu navegador:  http://localhost/nagios"
    fi

    pause
}

iptraf_monitoreo() {
    clear
    echo " MONITOREO DE RED CON IPTRAF-NG (TRÁFICO DE LA RED HOSPITALARIA) "
    echo
    if ! command -v iptraf-ng &>/dev/null; then
        echo "iptraf-ng no está instalado."
        echo "Instálalo con:  dnf install -y iptraf-ng"
        pause
        return
    fi

    echo "Se abrirá iptraf-ng. Usa las flechas para moverte y Q para salir."
    pause
    iptraf-ng
}

nmap_monitoreo() {
    clear
    echo " ESCANEO DE PUERTOS CON NMAP (EQUIPOS DE LA RED DE SALUD) "
    echo
    if ! command -v nmap &>/dev/null; then
        echo "nmap no está instalado."
        echo "Instálalo con:  dnf install -y nmap"
        pause
        return
    fi

    read -rp "IP o red a escanear (ENTER = localhost): " target
    [[ -z "$target" ]] && target="127.0.0.1"

    echo
    echo "Ejecutando: nmap -sS $target"
    echo
    nmap -sS "$target"
    pause
}

menu_seguridad() {
    local op
    while true; do
        clear
        echo " SEGURIDAD - MONITOREO (SECTOR SALUD) "
        echo "1) Nagios"
        echo "2) iptraf-ng"
        echo "3) Nmap"
        echo "0) Regresar"
        read -rp "Opción: " op

        case "$op" in
            1) nagios_monitoreo ;;
            2) iptraf_monitoreo ;;
            3) nmap_monitoreo ;;
            0) break ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

menu_principal() {
    local op
    while true; do
        clear
        echo " PROYECTO ADMINISTRACIÓN DE REDES - SECTOR SALUD "
        echo "1) Gestión de usuarios y áreas"
        echo "2) Automatización de tareas"
        echo "3) Respaldo de la información"
        echo "4) Seguridad"
        echo "0) Salir"
        read -rp "Opción: " op

        case "$op" in
            1) menu_gestion_usuarios ;;
            2) menu_automatizacion ;;
            3) menu_respaldo ;;
            4) menu_seguridad ;;
            0) echo "Saliendo..."; exit 0 ;;
            *) echo "Opción inválida."; pause ;;
        esac
    done
}

menu_principal
