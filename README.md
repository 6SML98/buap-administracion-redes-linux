# Administración de redes Linux

Menú Bash para usuarios, grupos, cron/at, respaldos y herramientas de monitoreo. Proyecto destinado a AlmaLinux 9.

## Requisitos

Una máquina virtual AlmaLinux 9 y las utilidades que selecciones en el menú. Las operaciones administrativas requieren root.

## Ejecutar

Comprueba primero la sintaxis:

```bash
bash -n proyecto_secretaria_salud.sh
bash -n PF_0.sh
```

En una VM de pruebas, revisa el script y ejecútalo con `sudo bash proyecto_secretaria_salud.sh`. PF_0.sh es una variante.

## Verificación del 8 de octubre de 2026

ShellCheck no encontró errores tras corregir los finales de línea de PF_0.sh; quedaron diez sugerencias de estilo. No se ejecutaron las operaciones de usuarios, servicios ni respaldos: requieren la VM Linux. No uses este proyecto como prueba de administración real sin completar esa validación.
