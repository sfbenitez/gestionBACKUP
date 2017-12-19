#!/bin/bash
#
# -*- ENCODING: UTF-8 -*-
#
# Estratégia de copias de seguridad a seguir:
# Todos los días 1 de cada mes se realizará una copia completa del sistema.
# Los días 7-14-21-28 de cada mes se realizará una copia incremental partiendo de la copia completa realizada el 1 de ese mes.
# Los demás días se realizarán copias diferenciales partiendo de la última copia incremental o completa en el caso de los días del 1-6.

# STATIC PARAMS
: ${PGPASSFILE:=/root/.pgpass}										# passfile para postgresql
: ${DATE:=$(date +'%Y-%m-%d')}             				# Variable para Fecha.
: ${DAY:=$(date +'%d')}														# Variable para el día.
: ${YESTERDAY:=$(date --date="yesterday" +'%d')}	# Variable para el día anterior.
: ${MONTH:=$(date +'%b')}													# Variable para el mes.
: ${TIME:=$(date +'%R')}                   				# Variable para Hora.
: ${WORK_DIR:=/root/backup/$DATE}          				# Directorio de trabajo actual.
: ${LOG_FILE:=/root/backup/$DATE/backup.log}			# Archivo de log.
: ${ADMIN:=sergioferretebenitez@gmail.com} 				# Email de Administrador
: ${IPMICKEY:=172.22.200.108}
: ${IPMINNIE:=172.22.200.116}
: ${IPDONALD:=172.22.200.115}

# VARS
STATUS:=200

# Comprobando si existe el directorio de trabajo.
if [ ! -d "$WORK_DIR" ] ;
then
	mkdir -p $WORK_DIR;
	# TODO check si se crea correctamente.
fi;

# Cambiar al directorio
cd $WORK_DIR
if [ "$?" -ne "0" ]
then
  echo "No se puede acceder al directorio de trabajo, compruebe los permisos."
	exit 1
fi
# Dia 1 de cada mes, copia completa del sistema.
if [ "$DAY" =="01" ]
then
	# Backup del MBR
	dd if=/dev/sda of=sdabk.mbr count=1 bs=512
	# Borrar fichero .snap del mes anterior si existe.
	rm -f ../*.snap
	# Backup del sistema, excluyendo los directorios que el sistema modifica durante el arranque y el propio $WORK_DIR
	tar -cvpzf backup-completa-$HOSTNAME-$DATE.tar --exclude=$WORK_DIR --exclude=/lost+found --exclude=/dev --exclude=/proc --exclude=/sys -g ../$MONTH.snap /
	# Añadir lista de paquetes instalados y MBR
	dpkg --get-selections > paquetes_instalados.txt
	tar -rvf backup-completa-$HOSTNAME-$DATE.tar paquetes_instalados.txt sdabk.mbr
	gzip -8f backup-completa-$HOSTNAME-$DATE.tar
	if [ "$?" -ne "0" ]
	then
		echo "Error al comprimir la copia final."
		STATUS=400
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPMICKEY','backup-completa-$HOSTNAME-$DATE.tar.gz','Copia completa de $HOSTNAME', '$STATUS', 'Automatica')"
	else
		echo "Copia COMPLETA creada correctamente."
		STATUS=200
		rm -f backup-completa-$HOSTNAME-$DATE.tar
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPMICKEY','backup-completa-$HOSTNAME-$DATE.tar.gz','Copia completa de $HOSTNAME', '$STATUS', 'Automatica')"
	fi
	# Fichero indicando hora exacta de la copia para las copias diferenciales
	date > ../date-last-backup.txt # /root/backup

elif [ "$DAY" == "07" ] || [ "$DAY" == "14" ] || [ "$DAY" == "21" ] || [ "$DAY" == "28" ]
then
	# Copia incremental de los directorios importantes en mi caso.
	tar -cvpf backup-inc-$HOSTNAME-$DATE.tar -g ../$MONTH.snap \
		/etc/ \
		/root/ \
		/var/log/ \
		/var/lib/ > $LOG_FILE
	# Añadir lista de paquetes instalados
	dpkg --get-selections > paquetes_instalados.txt
	tar -rvf backup-inc-$HOSTNAME-$DATE.tar paquetes_instalados.txt $LOG_FILE
	gzip -8f backup-inc-$HOSTNAME-$DATE.tar
	if [ "$?" -ne "0" ]
	then
		echo "Error al comprimir la copia final."
		STATUS=100
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPMICKEY','backup-inc-$HOSTNAME-$DATE.tar.gz','Copia incremental de $HOSTNAME', '$STATUS', 'Automatica')"
	else
		echo "Copia INCREMENTAL creada correctamente."
		STATUS=200
		rm -f backup-inc-$HOSTNAME-$DATE.tar
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPMICKEY','backup-inc-$HOSTNAME-$DATE.tar.gz','Copia incremental de $HOSTNAME', '$STATUS', 'Automatica')"
	fi
	# Fichero indicando hora exacta de la copia para las copias diferenciales
	date > ../date-last-backup.txt # /root/backup
else
	# Copia diferencial respecto al día anterior
	tar -cvpf backup-dif-$HOSTNAME-$DATE.tar -N ../date-last-backup.txt \
	/etc/ \
	/root/ \
	/var/log/ \
	/var/lib/ > $LOG_FILE
	if [ "$?" -ne "0" ]
	then
		echo "Error al crear la copia final."
		STATUS=100
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPMICKEY','backup-dif-$HOSTNAME-$DATE.tar.gz','Copia diferencial de $HOSTNAME', '$STATUS', 'Automatica')"
	else
		echo "Copia DIFERENCIAL creada correctamente."
		STATUS=200
		rm -f backup-dif-$HOSTNAME-$DATE.tar
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPMICKEY','backup-dif-$HOSTNAME-$DATE.tar.gz','Copia diferencial de $HOSTNAME', '$STATUS', 'Automatica')"
	fi
	# Fichero indicando hora exacta de la copia para las siguientes copias diferenciales
	date > ../date-last-backup.txt # /root/backup
fi

# Fin del script
exit 0
