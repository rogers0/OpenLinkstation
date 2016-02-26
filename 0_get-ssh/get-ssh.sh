#!/bin/sh

IP=$1
PW=$2

if [ -z "$IP" ]; then
	echo Usage: $0 \<Linkstation IP\> [Linkstation web login password]
else
	[ -z "$PW" ] && PW=password
	path=`dirname $0`
	echo target IP: $IP
	echo java -jar acp_commander.jar -t $IP -ip $IP -pw $PW -c \"echo -e ${PW}\\\\n${PW}\\\\n\|passwd\"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "echo -e ${PW}\\\\n${PW}\\\\n|passwd"

	# be noted there's 210-byte limit on command line for acp_commander.jar
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "\
		test ! -f /etc/sshd_config.orig && cp -a /etc/sshd_config /etc/sshd_config.orig; \
		test ! -f /etc/init.d/sshd.sh_orig && cp -a /etc/init.d/sshd.sh /etc/init.d/sshd.sh_orig"

#	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "\
#		sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' \
#			-i 's/#PermitRootLogin yes/PermitRootLogin yes/g' \
#			-i 's/UsePAM yes/UsePAM no/g' \
#			-i 's/#UsePAM no/UsePAM no/g' /etc/sshd_config"
#	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "\
#		sed -i 's/#Port 22/Port 22/g' \
#			-i 's/#Protocol 2/Protocol 2/g' \
#			-i 's/#StrictModes yes/StrictModes yes/g' \
#			-i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/sshd_config"

	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/UsePAM yes/UsePAM no/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/#UsePAM no/UsePAM no/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/#Port 22/Port 22/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/#Protocol 2/Protocol 2/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/#StrictModes yes/StrictModes yes/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i '/\"\${SUPPORT_SFTP}\" = \"0\"/i SUPPORT_SFTP=1' /etc/init.d/sshd.sh"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "/etc/init.d/sshd.sh restart"
	# for those without /etc/init.d/sshd.sh script, we call sshd command directly
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "ps|grep sshd|grep -v grep || sshd -D&"
fi
