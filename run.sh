#!/bin/bash
<<!
 **********************************************************
 * Author        : 马永龙
 * Email         : yonglong.ma@hpe.com
 * Last modified : 2015-05-16 14:00
 * Filename      : run.sh
 * Description   : 服务运行脚本，支持Mac,Linux
 * *******************************************************
!

#切换至根目录
cd "$(dirname "$0")" || exit 1

#根目录
WORKING_DIR="$(pwd)"

#应用启动配置
APP_ENV_CONF="${WORKING_DIR}"/app_env.conf

#日志目录
LOGS_DIR="${WORKING_DIR}"/logs

#进程ID
PID_FILE="${WORKING_DIR}"/app.pid

#应用名称
APP_NAME="$(ls *.jar 2>/dev/null | head -n 1)"
APP_NAME=${APP_NAME%.jar}

#操作
ACTION=$1

echoRed() { echo $'\e[0;31m'"$1"$'\e[0m'; }
echoGreen() { echo $'\e[0;32m'"$1"$'\e[0m'; }
echoYellow() { echo $'\e[0;33m'"$1"$'\e[0m'; }

usage() {
	echo $'\n\n\n'
	echoRed "Usage: ${0} support command {start|stop|restart|status}"
	echo $'\n\n\n'
	exit 1
}

psCheck() {
	echo "-----------------All instances in this machine--------------------"
	echo "$(ps -ef | grep ${APP_NAME} | grep -E -v "grep|start|stop|status|restart")"
}

await() {
	end=$(date +%s)
	let "end+=10"
	while
		[[ $now -le $end ]]
	do
		now=$(date +%s)
		sleep 1
	done
}

#1.检查操作参数
[ $# -gt 0 ] || usage

#2.引入启动变量
if [ -r ${APP_ENV_CONF} ]; then
	. "${APP_ENV_CONF}"
else
	echoRed "Missing or unreadable ${APP_ENV_CONF}"
	echo $'\n\n\n'
	exit 1
fi

#根据PID检查是否在运行
isRunningPid() {
	ps -p "$1" &>/dev/null
}

#根据PID_FILE检查是否在运行
isRunning() {
	[[ -f "$PID_FILE" ]] || return 1
	local pid=$(cat "$PID_FILE")
	ps -p "$pid" &>/dev/null
	return
}

#基础配置
if [ "$MSP_DISCOVERY_URI" = "" ]; then
	BASE_OPTIONS=("--spring.profiles.active=$PROFILES_ACTIVE" "--server.port=$SERVER_PORT")
else
	BASE_OPTIONS=("--spring.profiles.active=$PROFILES_ACTIVE" "--server.port=$SERVER_PORT" "--eureka.client.serviceUrl.defaultZone=$MSP_DISCOVERY_URI")
fi

if [ "$SPRING_BOOT_OPTIONS" = "" ]; then
	RUN_EXE="$JAVA_EXE ${JAVA_OPTIONS[*]} -jar ${APP_NAME}.jar ${BASE_OPTIONS[*]}"
else
	RUN_EXE="$JAVA_EXE ${JAVA_OPTIONS[*]} -jar ${APP_NAME}.jar ${BASE_OPTIONS[*]} ${SPRING_BOOT_OPTIONS[*]}"
fi

start() {
	echo "--------------Starting $APP_NAME:"
	echo $'\n\n\n'

    #检查jdk
	if [ -z "$JAVA_EXE" ]; then
		echoRed "Result: Start failed,Cannot find a Java JDK. Please check JAVA_EXE in app_env.conf"
		echo $'\n\n\n'
		exit 1
	fi

	#检查已经运行
	if isRunning "$PID_FILE"; then
		echoYellow "Result: Running, no need to start"
		echo $'\n\n\n'
		exit 0
	fi

	echo "Boot Command: nohup $RUN_EXE"
	echo $'\n\n\n'

	nohup $RUN_EXE >/dev/null 2>${LOGS_DIR}/nohup.out &

	disown $!
	echo $! >"$PID_FILE"

	#等5秒
	await

	TIMEOUT=100
	while (! isRunning "$APP_PID"); do
		if ((TIMEOUT-- == 0)); then
			echoRed "Result: Start timeout"
			echo $'\n\n\n'
			exit 1
		fi
		sleep 1
	done

	echoGreen "Result: Start success,Running (PID: $(<$PID_FILE))"
	echo $'\n\n\n'

	psCheck
}

stop() {
	echo "--------------Stopping $APP_NAME:"
	echo $'\n\n\n'
	if [ ! -f "$PID_FILE" ]; then
		echoYellow "Result: Not running"
		echo $'\n\n\n'
		psCheck
		return 0
	fi

	local pid=$(<${PID_FILE})

	if [ -z $pid ]; then
		#pid文件存在，但进程却不存在
		echoRed "Result: Not running (PID: $pid not found)"
		echo $'\n\n\n'
		psCheck
		rm -f "$PID_FILE"
		return 0
	fi

	kill "$pid" 2>/dev/null

	TIMEOUT=30
	while isRunning $PID_FILE; do
		if ((TIMEOUT-- == 0)); then
			kill -KILL "$PID" 2>/dev/null
		fi
		sleep 1
	done
	rm -f "$PID_FILE"
	echoGreen "Result: Stop success"
	echo $'\n\n\n'
}

status() {
	echo "--------------Status $APP_NAME:"
	echo $'\n\n\n'
	[[ -f "$PID_FILE" ]] || {
		echoYellow "Result: Not running"
		echo $'\n\n\n'
		psCheck
		return 1
	}
	local pid=$(<$PID_FILE)

	if isRunningPid $pid; then
		echoGreen "Result: Running （PID: $pid )"
		echo $'\n\n\n'
		psCheck
		return 0
	else
		echoRed "Result: Not running (PID: $pid not found)"
		echo $'\n\n\n'
		psCheck
		return 1
	fi
}

case "$ACTION" in
start)
	start
	;;

stop)
	stop
	;;

restart)
	stop
	start
	;;

status)
	status
	;;
*)
	usage
	;;
esac

#成功退出
exit 0
