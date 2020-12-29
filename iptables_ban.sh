#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
#=================================================
#       System Required: CentOS/Debian/Ubuntu
#       Description: iptables ban BT、PT、SPAM and custom ports, keywords
#       Version: 1.0.1
#       Github: https://github.com/Deinococci/iptables_ban
#=================================================

sh_ver="1.0.1"
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[info]${Font_color_suffix}"
Error="${Red_font_prefix}[error]${Font_color_suffix}"

smtp_port="25,26,465,587"
pop3_port="109,110,995"
imap_port="143,218,220,993"
other_port="24,50,57,105,106,158,209,1109,24554,60177,60179"
bt_key_word="ed2k
torrent
.torrent
bt_key
peer_id=
announce
info_hash
get_peers
find_node
BitTorrent
announce_peer
BitTorrent protocol
announce.php?passkey=
magnet:
xunlei
sandai
Thunder
speedtest
speedcheck
fast.com
kpzip
XLLiveUD"

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		release="centos"
	elif cat /etc/issue | grep -q -E -i "debian"; then
		release="debian"
	elif cat /etc/issue | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
	elif cat /proc/version | grep -q -E -i "debian"; then
		release="debian"
	elif cat /proc/version | grep -q -E -i "ubuntu"; then
		release="ubuntu"
	elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
		release="centos"
    fi
	bit=`uname -m`
}
check_BT(){
	Cat_KEY_WORDS
	BT_KEY_WORDS=$(echo -e "$Ban_KEY_WORDS_list"|grep "torrent")
}
check_SPAM(){
	Cat_PORT
	SPAM_PORT=$(echo -e "$Ban_PORT_list"|grep "${smtp_port}")
}
Cat_PORT(){
	Ban_PORT_list=$(iptables -t filter -L OUTPUT -nvx --line-numbers|grep "REJECT"|awk '{print $13}')
}
Cat_KEY_WORDS(){
	Ban_KEY_WORDS_list=""
	Ban_KEY_WORDS_v6_list=""
	if [[ ! -z ${v6iptables} ]]; then
		Ban_KEY_WORDS_v6_text=$(${v6iptables} -t mangle -L OUTPUT -nvx --line-numbers|grep "DROP")
		Ban_KEY_WORDS_v6_list=$(echo -e "${Ban_KEY_WORDS_v6_text}"|sed -r 's/.*\"(.+)\".*/\1/')
	fi
	Ban_KEY_WORDS_text=$(${v4iptables} -t mangle -L OUTPUT -nvx --line-numbers|grep "DROP")
	Ban_KEY_WORDS_list=$(echo -e "${Ban_KEY_WORDS_text}"|sed -r 's/.*\"(.+)\".*/\1/')
}
View_PORT(){
	Cat_PORT
	echo -e "===============${Red_background_prefix} Currently banned Port ${Font_color_suffix}==============="
	echo -e "$Ban_PORT_list" && echo && echo -e "==============================================="
}
View_KEY_WORDS(){
	Cat_KEY_WORDS
	echo -e "==============${Red_background_prefix} Currently banned Keyword ${Font_color_suffix}=============="
	echo -e "$Ban_KEY_WORDS_list" && echo -e "==============================================="
}
View_ALL(){
	echo
	View_PORT
	View_KEY_WORDS
	echo
}
Save_iptables_v4_v6(){
	if [[ ${release} == "centos" ]]; then
		if [[ ! -z "$v6iptables" ]]; then
			service ip6tables save
			chkconfig --level 2345 ip6tables on
		fi
		service iptables save
		chkconfig --level 2345 iptables on
	else
		if [[ ! -z "$v6iptables" ]]; then
			ip6tables-save > /etc/ip6tables.up.rules
			echo -e "#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules\n/sbin/ip6tables-restore < /etc/ip6tables.up.rules" > /etc/network/if-pre-up.d/iptables
		else
			echo -e "#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules" > /etc/network/if-pre-up.d/iptables
		fi
		iptables-save > /etc/iptables.up.rules
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
Set_key_word() { $1 -t mangle -$3 OUTPUT -m string --string "$2" --algo bm --to 65535 -j DROP; }
Set_tcp_port() {
	[[ "$1" = "$v4iptables" ]] && $1 -t filter -$3 OUTPUT -p tcp -m multiport --dports "$2" -m state --state NEW,ESTABLISHED -j REJECT --reject-with icmp-port-unreachable
	[[ "$1" = "$v6iptables" ]] && $1 -t filter -$3 OUTPUT -p tcp -m multiport --dports "$2" -m state --state NEW,ESTABLISHED -j REJECT --reject-with tcp-reset
}
Set_udp_port() { $1 -t filter -$3 OUTPUT -p udp -m multiport --dports "$2" -j DROP; }
Set_SPAM_Code_v4(){
	for i in ${smtp_port} ${pop3_port} ${imap_port} ${other_port}
		do
		Set_tcp_port $v4iptables "$i" $s
		Set_udp_port $v4iptables "$i" $s
	done
}
Set_SPAM_Code_v4_v6(){
	for i in ${smtp_port} ${pop3_port} ${imap_port} ${other_port}
	do
		for j in $v4iptables $v6iptables
		do
			Set_tcp_port $j "$i" $s
			Set_udp_port $j "$i" $s
		done
	done
}
Set_PORT(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_tcp_port $v4iptables $PORT $s
		Set_udp_port $v4iptables $PORT $s
		Set_tcp_port $v6iptables $PORT $s
		Set_udp_port $v6iptables $PORT $s
	elif [[ -n "$v4iptables" ]]; then
		Set_tcp_port $v4iptables $PORT $s
		Set_udp_port $v4iptables $PORT $s
	fi
	Save_iptables_v4_v6
}
Set_KEY_WORDS(){
	key_word_num=$(echo -e "${key_word}"|wc -l)
	for((integer = 1; integer <= ${key_word_num}; integer++))
		do
			i=$(echo -e "${key_word}"|sed -n "${integer}p")
			Set_key_word $v4iptables "$i" $s
			[[ ! -z "$v6iptables" ]] && Set_key_word $v6iptables "$i" $s
	done
	Save_iptables_v4_v6
}
Set_BT(){
	key_word=${bt_key_word}
	Set_KEY_WORDS
	Save_iptables_v4_v6
}
Set_SPAM(){
	if [[ -n "$v4iptables" ]] && [[ -n "$v6iptables" ]]; then
		Set_SPAM_Code_v4_v6
	elif [[ -n "$v4iptables" ]]; then
		Set_SPAM_Code_v4
	fi
	Save_iptables_v4_v6
}
Set_ALL(){
	Set_BT
	Set_SPAM
}
Ban_BT(){
	check_BT
	[[ ! -z ${BT_KEY_WORDS} ]] && echo -e "${Error} It is detected that BT and PT keywords have been blocked, there is no need to block again!" && exit 0
	s="A"
	Set_BT
	View_ALL
	echo -e "${Info} BT and PT keywords have been blocked!"
}
Ban_SPAM(){
	check_SPAM
	[[ ! -z ${SPAM_PORT} ]] && echo -e "${Error} It is detected that SPAM ports has been blocked, there is no need to block again!" && exit 0
	s="A"
	Set_SPAM
	View_ALL
	echo -e "${Info} SPAM ports has been blocked!"
}
Ban_ALL(){
	check_BT
	check_SPAM
	s="A"
	if [[ -z ${BT_KEY_WORDS} ]]; then
		if [[ -z ${SPAM_PORT} ]]; then
			Set_ALL
			View_ALL
			echo -e "${Info} BT, PT keywords and SPAM ports have been blocked!"
		else
			Set_BT
			View_ALL
			echo -e "${Info} BT and PT keywords have been blocked!"
		fi
	else
		if [[ -z ${SPAM_PORT} ]]; then
			Set_SPAM
			View_ALL
			echo -e "${Info} SPAM ports has been blocked!"
		else
			echo -e "${Error} It is detected that BT, PT keywords and SPAM ports have been blocked, no need to block again!" && exit 0
		fi
	fi
}
UnBan_BT(){
	check_BT
	[[ -z ${BT_KEY_WORDS} ]] && echo -e "${Error} Banned BT and PT keywords are not detected, please check!" && exit 0
	s="D"
	Set_BT
	View_ALL
	echo -e "${Info} BT and PT keywords have been unblocked!"
}
UnBan_SPAM(){
	check_SPAM
	[[ -z ${SPAM_PORT} ]] && echo -e "${Error} Banned SPAM ports are not detected, please check!" && exit 0
	s="D"
	Set_SPAM
	View_ALL
	echo -e "${Info} SPAM ports has been unblocked!"
}
UnBan_ALL(){
	check_BT
	check_SPAM
	s="D"
	if [[ ! -z ${BT_KEY_WORDS} ]]; then
		if [[ ! -z ${SPAM_PORT} ]]; then
			Set_ALL
			View_ALL
			echo -e "${Info} BT, PT keywords and SPAM ports have been unblocked!"
		else
			Set_BT
			View_ALL
			echo -e "${Info} BT and PT keywords have been unblocked!"
		fi
	else
		if [[ ! -z ${SPAM_PORT} ]]; then
			Set_SPAM
			View_ALL
			echo -e "${Info} SPAM ports has been unblocked!"
		else
			echo -e "${Error} Banned BT, PT keywords and SPAM ports are not detected, please check!" && exit 0
		fi
	fi
}
ENTER_Ban_KEY_WORDS_type(){
	Type=$1
	Type_1=$2
	if [[ $Type_1 != "ban_1" ]]; then
		echo -e "Please choose:
 1. Manual input (only single keyword is supported)
 2. Local file (support batch keywords, one keyword per line)
 3. Remote file (support batch keywords, one keyword per line)" && echo
		read -e -p "(Default: 1. Manual input):" key_word_type
	fi
	[[ -z "${key_word_type}" ]] && key_word_type="1"
	if [[ ${key_word_type} == "1" ]]; then
		if [[ $Type == "ban" ]]; then
			ENTER_Ban_KEY_WORDS
		else
			ENTER_UnBan_KEY_WORDS
		fi
	elif [[ ${key_word_type} == "2" ]]; then
		ENTER_Ban_KEY_WORDS_file
	elif [[ ${key_word_type} == "3" ]]; then
		ENTER_Ban_KEY_WORDS_url
	else
		if [[ $Type == "ban" ]]; then
			ENTER_Ban_KEY_WORDS
		else
			ENTER_UnBan_KEY_WORDS
		fi
	fi
}
ENTER_Ban_PORT(){
	echo -e "Please enter the port to be banned (single-port / multi-port / serial port section)"
	if [[ ${Ban_PORT_Type_1} != "1" ]]; then
	echo -e "${Green_font_prefix}========Example========${Font_color_suffix}
 Single port: 25
 Multiple ports: 25,26,465,587 (multiple ports are separated by commas)
 Continuous port segment: 25:587 (all ports between 25-587)" && echo
	fi
	read -e -p "(Enter Default to cancel):" PORT
	[[ -z "${PORT}" ]] && echo "Cancelled..." && View_ALL && exit 0
}
ENTER_Ban_KEY_WORDS(){
	echo -e "Please enter the keyword you want to ban (domain names, etc., only support a single keyword)"
	if [[ ${Type_1} != "ban_1" ]]; then
	echo -e "${Green_font_prefix}========Example========${Font_color_suffix}
 Keyword: example (which prohibits access to any domain name that contains the keyword 'example')
 Keyword: example.com (which prohibits access to any domain name that contains the keyword 'example.com' (Pan-domain ban))
 Keyword: www.example.com (which prohibits access to any domain name that contains the keyword 'www.example.com' (subdomain ban))
 " && echo
	fi
	read -e -p "(Enter Default to cancel):" key_word
	[[ -z "${key_word}" ]] && echo "Cancelled..." && View_ALL && exit 0
}
ENTER_Ban_KEY_WORDS_file(){
	echo -e "Please enter the path of the local file to be banned/unbanned (please use an absolute path)" && echo
	read -e -p "(Default Read key_word.txt in the same directory of the script):" key_word
	[[ -z "${key_word}" ]] && key_word="key_word.txt"
	if [[ -e "${key_word}" ]]; then
		key_word=$(cat "${key_word}")
		[[ -z ${key_word} ]] && echo -e "${Error} File is empty!" && View_ALL && exit 0
	else
		echo -e "${Error} File not found ${key_word} !" && View_ALL && exit 0
	fi
}
ENTER_Ban_KEY_WORDS_url(){
	echo -e "Please enter the URL of the remote file to be banned/unbanned (e.g. http://xx.xx/key_word.txt)" && echo
	read -e -p "(Enter Default to cancel):" key_word
	[[ -z "${key_word}" ]] && echo "Cancelled..." && View_ALL && exit 0
	key_word=$(wget --no-check-certificate -t3 -T5 -qO- "${key_word}")
	[[ -z ${key_word} ]] && echo -e "${Error} File is empty or access timed out!" && View_ALL && exit 0
}
ENTER_UnBan_KEY_WORDS(){
	View_KEY_WORDS
	echo -e "Please enter the keyword you want to unbanned (enter complete and accurate keyword according to the list above)" && echo
	read -e -p "(Enter Default to cancel):" key_word
	[[ -z "${key_word}" ]] && echo "Cancelled..." && View_ALL && exit 0
}
ENTER_UnBan_PORT(){
	echo -e "Please enter the port you want to unbanned (enter the complete and accurate port according to the above list, including comma and colon)" && echo
	read -e -p "(Enter Default to cancel):" PORT
	[[ -z "${PORT}" ]] && echo "Cancelled..." && View_ALL && exit 0
}
Ban_PORT(){
	s="A"
	ENTER_Ban_PORT
	Set_PORT
	echo -e "${Info} Port banned [ ${PORT} ] !\n"
	Ban_PORT_Type_1="1"
	while true
	do
		ENTER_Ban_PORT
		Set_PORT
		echo -e "${Info} Port banned [ ${PORT} ] !\n"
	done
	View_ALL
}
Ban_KEY_WORDS(){
	s="A"
	ENTER_Ban_KEY_WORDS_type "ban"
	Set_KEY_WORDS
	echo -e "${Info} Keywords banned [ ${key_word} ] !\n"
	while true
	do
		ENTER_Ban_KEY_WORDS_type "ban" "ban_1"
		Set_KEY_WORDS
		echo -e "${Info} Keywords banned [ ${key_word} ] !\n"
	done
	View_ALL
}
UnBan_PORT(){
	s="D"
	View_PORT
	[[ -z ${Ban_PORT_list} ]] && echo -e "${Error} No banned port detected!" && exit 0
	ENTER_UnBan_PORT
	Set_PORT
	echo -e "${Info} Unbanned port [ ${PORT} ] !\n"
	while true
	do
		View_PORT
		[[ -z ${Ban_PORT_list} ]] && echo -e "${Error} No banned port detected!" && exit 0
		ENTER_UnBan_PORT
		Set_PORT
		echo -e "${Info} Unbanned port [ ${PORT} ] !\n"
	done
	View_ALL
}
UnBan_KEY_WORDS(){
	s="D"
	Cat_KEY_WORDS
	[[ -z ${Ban_KEY_WORDS_list} ]] && echo -e "${Error} No banned keyword detected!" && exit 0
	ENTER_Ban_KEY_WORDS_type "unban"
	Set_KEY_WORDS
	echo -e "${Info} Unbanned keyowrd [ ${key_word} ] !\n"
	while true
	do
		Cat_KEY_WORDS
		[[ -z ${Ban_KEY_WORDS_list} ]] && echo -e "${Error} No banned keyword detected!" && exit 0
		ENTER_Ban_KEY_WORDS_type "unban" "ban_1"
		Set_KEY_WORDS
		echo -e "${Info} Unbanned keyowrd [ ${key_word} ] !\n"
	done
	View_ALL
}
UnBan_KEY_WORDS_ALL(){
	Cat_KEY_WORDS
	[[ -z ${Ban_KEY_WORDS_text} ]] && echo -e "${Error} No banned keyword detected! Please check" && exit 0
	if [[ ! -z "${v6iptables}" ]]; then
		Ban_KEY_WORDS_v6_num=$(echo -e "${Ban_KEY_WORDS_v6_list}"|wc -l)
		for((integer = 1; integer <= ${Ban_KEY_WORDS_v6_num}; integer++))
			do
				${v6iptables} -t mangle -D OUTPUT 1
		done
	fi
	Ban_KEY_WORDS_num=$(echo -e "${Ban_KEY_WORDS_list}"|wc -l)
	for((integer = 1; integer <= ${Ban_KEY_WORDS_num}; integer++))
		do
			${v4iptables} -t mangle -D OUTPUT 1
	done
	Save_iptables_v4_v6
	View_ALL
	echo -e "${Info} Unbanned all keywords"
}
check_iptables(){
	v4iptables=`iptables -V`
	v6iptables=`ip6tables -V`
	if [[ ! -z ${v4iptables} ]]; then
		v4iptables="iptables"
		if [[ ! -z ${v6iptables} ]]; then
			v6iptables="ip6tables"
		fi
	else
		echo -e "${Error} Iptables is not installed!
Please install iptables:
CentOS: yum install iptables -y
Debian / Ubuntu: apt-get install iptables -y"
	fi
}
Update_Shell(){
	sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "https://raw.githubusercontent.com/Deinococci/iptables_ban/main/iptables_ban.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1)
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} Unable to connect to Github!" && exit 0
	wget -N --no-check-certificate "https://raw.githubusercontent.com/Deinococci/iptables_ban/main/iptables_ban.sh" && chmod +x iptables_ban.sh
	echo -e "The script has been updated to the latest version[ ${sh_new_ver} ]! (Note: Because the update method is to directly overwrite the currently running script, some errors may be prompted below, just ignore it)" && exit 0
}
check_sys
check_iptables
action=$1
if [[ ! -z $action ]]; then
	[[ $action = "banbt" ]] && Ban_BT && exit 0
	[[ $action = "banspam" ]] && Ban_SPAM && exit 0
	[[ $action = "banall" ]] && Ban_ALL && exit 0
	[[ $action = "unbanbt" ]] && UnBan_BT && exit 0
	[[ $action = "unbanspam" ]] && UnBan_SPAM && exit 0
	[[ $action = "unbanall" ]] && UnBan_ALL && exit 0
fi
echo && echo -e "iptables ban management script ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  --  iptables ban script  | https://github.com/Deinococci/iptables_ban --

  ${Green_font_prefix}0.${Font_color_suffix} View current banned list
————————————
  ${Green_font_prefix}1.${Font_color_suffix} Ban BT、PT
  ${Green_font_prefix}2.${Font_color_suffix} Ban SPAM
  ${Green_font_prefix}3.${Font_color_suffix} Ban BT、PT and SPAM
  ${Green_font_prefix}4.${Font_color_suffix} Ban Custom port
  ${Green_font_prefix}5.${Font_color_suffix} Ban Custom keyword
————————————
  ${Green_font_prefix}6.${Font_color_suffix} Unban BT、PT
  ${Green_font_prefix}7.${Font_color_suffix} Unban SPAM
  ${Green_font_prefix}8.${Font_color_suffix} Unban BT、PT and SPAM
  ${Green_font_prefix}9.${Font_color_suffix} Unban Custom port
 ${Green_font_prefix}10.${Font_color_suffix} Unban Custom keyword
 ${Green_font_prefix}11.${Font_color_suffix} Unban All keywords
————————————
 ${Green_font_prefix}12.${Font_color_suffix} Upgrade script
" && echo
read -e -p " Please enter the number [0-12]:" num
case "$num" in
	0)
	View_ALL
	;;
	1)
	Ban_BT
	;;
	2)
	Ban_SPAM
	;;
	3)
	Ban_ALL
	;;
	4)
	Ban_PORT
	;;
	5)
	Ban_KEY_WORDS
	;;
	6)
	UnBan_BT
	;;
	7)
	UnBan_SPAM
	;;
	8)
	UnBan_ALL
	;;
	9)
	UnBan_PORT
	;;
	10)
	UnBan_KEY_WORDS
	;;
	11)
	UnBan_KEY_WORDS_ALL
	;;
	12)
	Update_Shell
	;;
	*)
	echo "Please enter the correct number [0-12]"
	;;
esac