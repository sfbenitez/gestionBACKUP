#!/bin/bash
#
# -*- ENCODING: UTF-8 -*-
#
# Estratégia de copias de seguridad a seguir:
# Todas las semanas se realizará una copia completa del sistema.
# Los demás días se realizarán copias diferenciales partiendo de la última copia completa.
# Directorios a respaldar por máquina.
#  Mickey               Minnie                  Donald
# Directorio de usuarios
# /root                 /root                   /root
# /home                 /home                   /home
# Ficheros de configuración
# /etc                  /etc                    /etc
# Logs
# /var/log              /var/log                /var/log
# Binarios de métricas
# /usr/local/sbin	/usr/local/sbin         /usr/local/sbin
# Específos de cada host
# Subdominio DNS        Práctica hosting SRV    Servidor Web
# /var/cache/bind	/srv                    /var/www
# /var/lib/ldap         /var/www
# -                     /var/cache/bind
# -                     /var/lib/ldap
# -                     /var/lib/grafana
# -                     /var/lib/prometheus


# STATIC PARAMS
: ${PGPASSFILE:=/root/.pgpass}		# passfile para postgresql 172.22.200.110:5432:db_backup:sergio.ferrete:passwd
: ${DATE:=$(date +'%Y-%m-%d')}		# Variable para Fecha.
: ${DAY:=$(date +'%a')}		# Variable para el día.
: ${YESTERDAY:=$(date --date="yesterday" +'%d')}		# Variable para el día anterior.
: ${MONTH:=$(date +'%b')}		# Variable para el mes.
: ${TIME:=$(date +'%R')}		# Variable para Hora.
: ${WORK_DIR:=/root/backup/$DATE}		# Directorio de trabajo actual.
: ${LOG_FILE:=/root/backup/$DATE/backup.log}		# Archivo de log.
: ${ADMIN:=sergioferretebenitez@gmail.com}		# Email de Administrador
: ${IPDONALD:=172.22.200.115}


# VARS
STATUS=200

# Comprobando si existe el directorio de trabajo.
if [ ! -d "$WORK_DIR" ] ;
then
	mkdir -p $WORK_DIR;
	if [ "$?" -ne "0" ]
	then
		echo "No se ha podido crear el directorio de trabajo."
		exit 1
	fi
fi;

# Cambiar al directorio
cd $WORK_DIR
if [ "$?" -ne "0" ]
then
  echo "No se puede acceder al directorio de trabajo, compruebe los permisos."
	exit 1
fi
# Todos los Lunes de cada semana, copia completa.
if [ "$DAY" == "lun" ]
then
	# lista de paquetes instalados y mbr
	dpkg --get-selections > paquetes_instalados.txt
	dd if=/dev/vda of=vdabk.mbr count=1 bs=512
	# Crear fichero cifrado del directorio /home/ferrete/privado
	tar -cpf /home/ferrete/privado | gpg --passphrase-file /home/ferrete/privado/.gpgpass \
	--batch --yes --no-use-agent --symmetric > /home/ferrete/privado.tar.gpg
		# Backup del sistema, excluyendo $WORK_DIR
	tar -cvpf backup-completa-$HOSTNAME-$DATE.tar --exclude=/root/backup  --exclude=/home/ferrete/privado/ \
	paquetes_instalados.txt vdabk.mbr \
	/root /home \
	/etc \
	/var/log \
	/var/www /usr/local/bin \
	/usr/local/sbin > $LOG_FILE
	if [ "$?" != "0" ]
	then
		echo "Error al crear la copia final."
		STATUS=100

	else
		echo "Copia COMPLETA creada correctamente."
		gzip -8f backup-completa-$HOSTNAME-$DATE.tar
		if [ "$?" == "0" ]
		then
			# Enviar el fichero al deposito de backups
			scp backup-completa-$HOSTNAME-$DATE.tar.gz backups@10.0.0.5:/home/backups
			if [ "$?" == "0" ]
			then
				rm backup-completa-$HOSTNAME-$DATE.tar.gz
				psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPDONALD','backup-completa-$HOSTNAME-$DATE.tar.gz','Copia completa de $HOSTNAME', '$STATUS', 'Automatica')"
			fi
		fi
	fi
	# Fichero indicando hora exacta de la copia para las copias diferenciales
	date > ../date-last-backup.txt # /root/backup

else
	# Crear fichero cifrado del directorio /home/ferrete/privado
	tar -cpf /home/ferrete/privado -N ../date-last-backup.txt | gpg --passphrase-file /home/ferrete/privado/.gpgpass \
	--batch --yes --no-use-agent --symmetric > /home/ferrete/privado.tar.gpg

	# Copia diferencial respecto al día anterior
	tar -cvpf backup-dif-$HOSTNAME-$DATE.tar -N ../date-last-backup.txt --exclude=/root/backup --exclude=/home/ferrete/privado/ \
	/root /home \
	/etc \
	/var/log \
	/var/www /usr/local/bin \
	/usr/local/sbin > $LOG_FILE

	if [ "$?" != "0" ]
	then
		echo "Error al crear la copia final."
		STATUS=100
		psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPDONALD','backup-dif-$HOSTNAME-$DATE.tar.gz','Copia diferencial de $HOSTNAME', '$STATUS', 'Automatica')"
	else
		echo "Copia DIFERENCIAL creada correctamente."
		gzip -8f backup-dif-$HOSTNAME-$DATE.tar
		if [ "$?" == "0" ]
		then
			# Enviar el fichero al deposito de backups
			scp backup-dif-$HOSTNAME-$DATE.tar.gz backups@10.0.0.5:/home/backups
			if [ "$?" == "0" ]
			then
				rm backup-dif-$HOSTNAME-$DATE.tar.gz
				psql -h 172.22.200.110 -U sergio.ferrete -d db_backup -c "INSERT INTO BACKUPS (backup_user, backup_host, backup_label, backup_description, backup_status, backup_mode) values ('sergio.ferrete', '$IPDONALD','backup-dif-$HOSTNAME-$DATE.tar.gz','Copia diferencial de $HOSTNAME', '$STATUS', 'Automatica')"
			fi
		fi
	fi
	# Fichero indicando hora exacta de la copia para las siguientes copias diferenciales
	date > ../date-last-backup.txt # /root/backup
fi

# Fin del script
exit 0
