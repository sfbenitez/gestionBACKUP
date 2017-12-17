#!/bin/sh
#
# -*- ENCODING: UTF-8 -*-
#
# Estratégia de copias de seguridad a seguir:
# Todos los días 1 de cada mes se realizará una copia completa del sistema.
# Los días 7-14-21-28 de cada mes se realizará una copia incremental partiendo de la copia completa realizada el 1 de ese mes.
# Los demás días se realizarán copias diferenciales partiendo de la última copia incremental o completa en el caso de los días del 1-6.

${DATE:=$(date +'%Y-%m-%d')}    # Variable para Fecha.
${TIME:=$(date +'%R')}                # Variable para Hora.
${WORK_DIR:=/home/backups/$DATE}            # Directorio de trabajo actual.
${LOG_FILE:=/home/backups/$DATE/record.log}   # Archivo de log.
${ADMIN:=admin@midominio.net}              # Email de Administrador No.1
