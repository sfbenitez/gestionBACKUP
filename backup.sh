#!/bin/sh
#
# -*- ENCODING: UTF-8 -*-
#
# Estratégia de copias de seguridad a seguir:
# Todos los días 1 de cada mes se realizará una copia completa del sistema.
# Los días 7-14-21-28 de cada mes se realizará una copia incremental partiendo de la copia completa realizada el 1 de ese mes.
# Los demás días se realizarán copias diferenciales partiendo de la última copia incremental o completa en el caso de los días del 1-6.

: ${DATE:=$(date +'%Y-%m-%d')}             # Variable para Fecha.
: ${DAY:=$(date +'%d')}			   # Variable para el día.
: ${MONTH:=$(date +'%b')}		   # Variable para el mes.
: ${TIME:=$(date +'%R')}                   # Variable para Hora.
: ${WORK_DIR:=/home/backup/$DATE}          # Directorio de trabajo actual.
: ${LOG_FILE:=$WORK_DIR/record.log}        # Archivo de log.
: ${ADMIN:=sergioferretebenitez@gmail.com} # Email de Administrador

# Comprobando si existe el directorio de trabajo.
if ! -d "$WORK_DIR" ;
then
	mkdir -p $WORK_DIR;
	# Falta check si se crea correctamente.
fi;

# Dia 1 de cada mes, copia completa del sistema.

if $DAY =="01" ;
then
	# Backup del MBR
	dd if=/dev/sda of=$WORK_DIR/sdabk.mbr count=1 bs=512
	# Borrar fichero .snap del mes anterior si existe.
	# TODO
	# Backup del sistema, excluyendo los directorios que el sistema modifica durante el arranque y el propio $WORK_DIR
	tar -cvpzf $WORK_DIR/backup-completa-$HOSTNAME-$DATE.tgz --exclude=$WORK_DIR --exclude=/lost+found --exclude=/dev --exclude=/proc --exclude=/sys -g $WORK_DIR/$MONTH.snap /’
elif $DAY == "07" || $DAY == "14" || $DAY == "21" || $DAY == "28" ;
then
	# Copia incremental de los directorios importantes en mi caso.
	tar -cvpzf $WORK_DIR/backup-inc-$HOSTNAME-$DATE.tgz -g $WORK_DIR/$MONTH.snap \
	/etc/ \
	/home/ferrete/ \
	/
