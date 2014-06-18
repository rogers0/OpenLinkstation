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
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "cp /etc/sshd_config /etc/sshd_config.orig"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "sed -i 's/UsePAM yes/UsePAM no/g' /etc/sshd_config"
	java -jar $path/acp_commander.jar -t $IP -ip $IP -pw $PW -c "/etc/init.d/sshd.sh restart"
fi
