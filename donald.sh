#!/bin/bash
#
# -*- ENCODING: UTF-8 -*-
#
# Estratégia de copias de seguridad a seguir:
# Todas las semanas se realizará una copia completa del sistema.
# Los demás días se realizarán copias diferenciales partiendo de la última copia completa.
# Directorios a respaldar por máquina.
#  Mickey							Minnie								Donald
# Directorio de usuarios
# /root								/root									/root
#	/home								/home									/home
# Ficheros de configuración
# /etc								/etc									/etc
# Logs
# /var/log						/var/log							/var/log
# Específos de cada host
# Subdominio DNS			Práctica hosting SRV  Servidor Web
# /var/cache/bind			/srv									/var/www
#	/var/lib/ldap				/var/www
#											/var/cache/bind
#											/var/lib/ldap
#											/var/lib/grafana
#											/var/lib/prometheus

# STATIC PARAMS
: ${PGPASSFILE:=/root/.pgpass}										# passfile para postgresql
: ${DATE:=$(date +'%Y-%m-%d')}             				# Variable para Fecha.
: ${DAY:=$(date +'%a')}														# Variable para el día.
: ${YESTERDAY:=$(date --date="yesterday" +'%d')}	# Variable para el día anterior.
: ${MONTH:=$(date +'%b')}													# Variable para el mes.
: ${TIME:=$(date +'%R')}                   				# Variable para Hora.
: ${WORK_DIR:=/root/backup/$DATE}          				# Directorio de trabajo actual.
: ${LOG_FILE:=/root/backup/$DATE/backup.log}			# Archivo de log.
: ${ADMIN:=sergioferretebenitez@gmail.com} 				# Email de Administrador
: ${IPMICKEY:=172.22.200.108}
: ${IPMINNIE:=172.22.200.127}
: ${IPDONALD:=172.22.200.115}

# VARS
STATUS:=200

# Comprobando si existe el directorio de trabajo.
if [ ! -d "$WORK_DIR" ] ;
then
	mkdir -p $WORK_DIR;
	if [ "$?" -ne "0" ]
	then
		echo "No se ha podido crear el directorio de trabajo."
		exit 1
fi;

# Cambiar al directorio
cd $WORK_DIR
if [ "$?" -ne "0" ]
then
  echo "No se puede acceder al directorio de trabajo, compruebe los permisos."
	exit 1
fi
# Todos los Lunes de cada semana, copia completa.
if [ "$DAY" == "Mon" ]
then
	# Borrar fichero .snap de la semana anterior anterior si existe.
	rm -f ../*.snap
	# Backup del sistema, excluyendo $WORK_DIR
	tar -cvpf backup-completa-$HOSTNAME-$DATE.tar --exclude=/root/backup -g ../Monday-$DATE.snap \
		/root /home \
		/etc \
		/var/log \
		/var/www
	fi
	# Añadir lista de paquetes instalados
	dpkg --get-selections > paquetes_instalados.txt
	tar -rvf backup-completa-$HOSTNAME-$DATE.tar paquetes_instalados.txt
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

else
	# Copia diferencial respecto al día anterior
	tar -cvpf backup-dif-$HOSTNAME-$DATE.tar -N ../date-last-backup.txt --exclude=/root/backup \
	/etc /root /var/log /var/lib > $LOG_FILE
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
