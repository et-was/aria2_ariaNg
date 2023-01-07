#!/usr/bin/env bash
#
# Copyright (c) 2017 Toyo
# Copyright (c) 2018-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/aria2.sh
# Description: Aria2 One-click installation management script
# System Required: CentOS/Debian/Ubuntu
# Version: 2.7.4
#

sh_ver="2.7.4"
export PATH=~/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/sbin:/bin
aria2_conf_dir="/root/.aria2c"
download_path="/content/drive/Shareddrives/DIREX/OUTPUT"
aria2_conf="${aria2_conf_dir}/aria2.conf"
aria2_log="${aria2_conf_dir}/aria2.log"
aria2c="/usr/local/bin/aria2c"
Crontab_file="/usr/bin/crontab"
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Green_background_prefix="\033[42;37m"
Red_background_prefix="\033[41;37m"
Font_color_suffix="\033[0m"
Info="[${Green_font_prefix}Info${Font_color_suffix}]"
Error="[${Red_font_prefix}Error${Font_color_suffix}]"
Tip="[${Green_font_prefix}Tip${Font_color_suffix}]"

check_root() {
    [[ $EUID != 0 ]] && echo -e "${Error} The current non-ROOT account (or does not have ROOT privileges) cannot continue, please replace or use the ROOT account ${Green_background_prefix}sudo su${Font_color_suffix} The command gets temporary ROOT permissions (you may be prompted to enter the password for your current account)." && exit 1
}
#CheckSystem
check_sys() {
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
    ARCH=$(uname -m)
    [ $(command -v dpkg) ] && dpkgARCH=$(dpkg --print-architecture | awk -F- '{ print $NF }')
}
check_installed_status() {
    [[ ! -e ${aria2c} ]] && echo -e "${Error} Aria2 is not installed, please check!" && exit 1
    [[ ! -e ${aria2_conf} ]] && echo -e "${Error} Aria2 configuration file does not exist, please check!" && [[ $1 != "un" ]] && exit 1
}
check_crontab_installed_status() {
    if [[ ! -e ${Crontab_file} ]]; then
        echo -e "${Error} Crontab is not installed, start installation..."
        if [[ ${release} == "centos" ]]; then
            yum install crond -y
        else
            apt-get install cron -y
        fi
        if [[ ! -e ${Crontab_file} ]]; then
            echo -e "${Error} Crontab installation failed, please check!" && exit 1
        else
            echo -e "${Info} Crontab installation successful!"
        fi
    fi
}
check_pid() {
    PID=$(ps -ef | grep "aria2c" | grep -v grep | grep -v "aria2.sh" | grep -v "init.d" | grep -v "service" | awk '{print $2}')
}
check_new_ver() {
    aria2_new_ver=$(
        {
            wget -t2 -T3 -qO- "https://api.github.com/repos/P3TERX/Aria2-Pro-Core/releases/latest" ||
                wget -t2 -T3 -qO- "https://gh-api.p3terx.com/repos/P3TERX/Aria2-Pro-Core/releases/latest"
        } | grep -o '"tag_name": ".*"' | head -n 1 | cut -d'"' -f4
    )
    if [[ -z ${aria2_new_ver} ]]; then
        echo -e "${Error} Aria2 Failed to get the latest version. Please get the latest version number manually[ https://github.com/P3TERX/Aria2-Pro-Core/releases ]"
        read -e -p "Please enter your version number:" aria2_new_ver
        [[ -z "${aria2_new_ver}" ]] && echo "Cancel..." && exit 1
    fi
}
check_ver_comparison() {
    read -e -p "whether to update (will interrupt the current download task) ? [Y/n] :" yn
    [[ -z "${yn}" ]] && yn="y"
    if [[ $yn == [Yy] ]]; then
        check_pid
        [[ ! -z $PID ]] && kill -9 ${PID}
        check_sys
        Download_aria2 "update"
        Start_aria2
    fi
}
Download_aria2() {
    update_dl=$1
    if [[ $ARCH == i*86 || $dpkgARCH == i*86 ]]; then
        ARCH="i386"
    elif [[ $ARCH == "x86_64" || $dpkgARCH == "amd64" ]]; then
        ARCH="amd64"
    elif [[ $ARCH == "aarch64" || $dpkgARCH == "arm64" ]]; then
        ARCH="arm64"
    elif [[ $ARCH == "armv7l" || $dpkgARCH == "armhf" ]]; then
        ARCH="armhf"
    else
        echo -e "${Error} This CPU architecture is not supported."
        exit 1
    fi
    while [[ $(which aria2c) ]]; do
        echo -e "${Info} Delete old Aria2 binaries..."
        rm -vf $(which aria2c)
    done
    DOWNLOAD_URL="https://github.com/P3TERX/Aria2-Pro-Core/releases/download/${aria2_new_ver}/aria2-${aria2_new_ver%_*}-static-linux-${ARCH}.tar.gz"
    {
        wget -t2 -T3 -O- "${DOWNLOAD_URL}" ||
            wget -t2 -T3 -O- "https://gh-acc.p3terx.com/${DOWNLOAD_URL}"
    } | tar -zx
    [[ ! -s "aria2c" ]] && echo -e "${Error} Aria 2 Download Failed!" && exit 1
    [[ ${update_dl} = "update" ]] && rm -f "${aria2c}"
    mv -f aria2c "${aria2c}"
    [[ ! -e ${aria2c} ]] && echo -e "${Error} Aria2 main program installation failed!" && exit 1
    chmod +x ${aria2c}
    echo -e "${Info} Aria2 Main Program Installation Complete!"
}
Download_aria2_conf() {
    PROFILE_URL1="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/aria2.conf"
    PROFILE_URL2="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/clean.sh"
    PROFILE_URL3="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/core"
    PROFILE_URL4="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/delete.sh"
    PROFILE_URL5="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/dht.dat"
    PROFILE_URL6="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/dht6.dat"
    PROFILE_URL7="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/move.sh"
    PROFILE_URL8="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/rclone.env"
    PROFILE_URL9="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/script.conf"
    PROFILE_URL10="https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/conf/upload.sh"
    PROFILE_LIST="
aria2.conf
clean.sh
core
script.conf
rclone.env
upload.sh
delete.sh
dht.dat
dht6.dat
move.sh
LICENSE
"
    mkdir -p "${aria2_conf_dir}" && cd "${aria2_conf_dir}"
    for PROFILE in ${PROFILE_LIST}; do
        [[ ! -f ${PROFILE} ]] && rm -rf ${PROFILE}
        wget -N -t2 -T3 ${PROFILE_URL1}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL2}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL3}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL4}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL5}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL6}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL7}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL8}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL9}/${PROFILE} ||
        wget -N -t2 -T3 ${PROFILE_URL10}/${PROFILE}
        [[ ! -s ${PROFILE} ]] && {
            echo -e "${Error} '${PROFILE}' Download failed! Clean up residual files..."
            rm -vrf "${aria2_conf_dir}"
            exit 1
        }
    done
    sed -i "s@^\(dir=\).*@\1${download_path}@" ${aria2_conf}
    sed -i "s@/root/.aria2/@${aria2_conf_dir}/@" ${aria2_conf_dir}/*.conf
    sed -i "s@^\(rpc-secret=\).*@\1$(date +%s%N | md5sum | head -c 20)@" ${aria2_conf}
    sed -i "s@^#\(retry-on-.*=\).*@\1true@" ${aria2_conf}
    sed -i "s@^\(max-connection-per-server=\).*@\132@" ${aria2_conf}
    touch aria2.session
    chmod +x *.sh
    echo -e "${Info} Aria2 Perfect Configuration Download Complete!"
}
Service_aria2() {
    if [[ ${release} = "centos" ]]; then
        wget -N -t2 -T3 "https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/service/aria2_centos" -O /etc/init.d/aria2
        [[ ! -s /etc/init.d/aria2 ]] && {
            echo -e "${Error} Aria 2 service management script download failed!"
            exit 1
        }
        chmod +x /etc/init.d/aria2
        chkconfig --add aria2
        chkconfig aria2 on
    else
        wget -N -t2 -T3 "https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/service/aria2_debian" -O /etc/init.d/aria2
        [[ ! -s /etc/init.d/aria2 ]] && {
            echo -e "${Error} Aria 2 service management script download failed!"
            exit 1
        }
        chmod +x /etc/init.d/aria2
        update-rc.d -f aria2 defaults
    fi
    echo -e "${Info} Aria 2 service management script download complete!"
}
Installation_dependency() {
    if [[ ${release} = "centos" ]]; then
        yum update
        yum install -y wget curl nano ca-certificates findutils jq tar gzip dpkg
    else
        apt-get update
        apt-get install -y wget curl nano ca-certificates findutils jq tar gzip dpkg
    fi
    if [[ ! -s /etc/ssl/certs/ca-certificates.crt ]]; then
        wget -qO- git.io/ca-certificates.sh | bash
    fi
}
Install_aria2() {
    check_root
    [[ -e ${aria2c} ]] && echo -e "${Error} Aria 2 is installed, please check!" && exit 1
    check_sys
    echo -e "${Info} Start installing/configuring dependencies..."
    Installation_dependency
    echo -e "${Info} Start downloading/installing the main program..."
    check_new_ver
    Download_aria2
    echo -e "${Info} Start downloading/installing Aria2 Perfect Configuration..."
    Download_aria2_conf
    echo -e "${Info} Start downloading/installing service scripts (init)..."
    Service_aria2
    Read_config
    aria2_RPC_port=${aria2_port}
    echo -e "${Info} Start setting up the iptables firewall..."
    Set_iptables
    echo -e "${Info} Start adding iptables firewall rules..."
    Add_iptables
    echo -e "${Info} Start saving iptables firewall rules..."
    Save_iptables
    echo -e "${Info} Start creating download directories..."
    mkdir -p ${download_path}
    echo -e "${Info} All steps, installation complete, start..."
    Start_aria2
}
Start_aria2() {
    check_installed_status
    check_pid
    [[ ! -z ${PID} ]] && echo -e "${Error} Aria 2 is running, check!" && exit 1
    /etc/init.d/aria2 start
}
Stop_aria2() {
    check_installed_status
    check_pid
    [[ -z ${PID} ]] && echo -e "${Error} Aria 2 is not running, please check!" && exit 1
    /etc/init.d/aria2 stop
}
Restart_aria2() {
    check_installed_status
    check_pid
    [[ ! -z ${PID} ]] && /etc/init.d/aria2 stop
    /etc/init.d/aria2 start
}
Set_aria2() {
    check_installed_status
    echo -e "
 ${Green_font_prefix}1.${Font_color_suffix} Modifying the Aria2 RPC key
 ${Green_font_prefix}2.${Font_color_suffix} Modifying the Aria2 RPC port
 ${Green_font_prefix}3.${Font_color_suffix} Modify the Aria2 download directory
 ${Green_font_prefix}4.${Font_color_suffix} Modify the Aria2 key + port + download directory
 ${Green_font_prefix}5.${Font_color_suffix} manually open configuration file changes
 ————————————
 ${Green_font_prefix}0.${Font_color_suffix} Reset/update Aria2 perfect configuration
"
    read -e -p " Please enter a number [0-5]:" aria2_modify
    if [[ ${aria2_modify} == "1" ]]; then
        Set_aria2_RPC_passwd
    elif [[ ${aria2_modify} == "2" ]]; then
        Set_aria2_RPC_port
    elif [[ ${aria2_modify} == "3" ]]; then
        Set_aria2_RPC_dir
    elif [[ ${aria2_modify} == "4" ]]; then
        Set_aria2_RPC_passwd_port_dir
    elif [[ ${aria2_modify} == "5" ]]; then
        Set_aria2_vim_conf
    elif [[ ${aria2_modify} == "0" ]]; then
        Reset_aria2_conf
    else
        echo
        echo -e " ${Error} Please enter the correct number"
        exit 1
    fi
}
Set_aria2_RPC_passwd() {
    read_123=$1
    if [[ ${read_123} != "1" ]]; then
        Read_config
    fi
    if [[ -z "${aria2_passwd}" ]]; then
        aria2_passwd_1="empty (no configuration detected, may have been manually deleted or commented)"
    else
        aria2_passwd_1=${aria2_passwd}
    fi
    echo -e "
 ${Tip} The Aria2 RPC key should not contain an equal sign (=) and a well sign (#), leaving blank for random generation.

 The current RPC key is: ${Green_font_prefix}${aria2_passwd_1}${Font_color_suffix}
"
    read -e -p " Enter a new RPC key: " aria2_RPC_passwd
    echo
    [[ -z "${aria2_RPC_passwd}" ]] && aria2_RPC_passwd=$(date +%s%N | md5sum | head -c 20)
    if [[ "${aria2_passwd}" != "${aria2_RPC_passwd}" ]]; then
        if [[ -z "${aria2_passwd}" ]]; then
            echo -e "\nrpc-secret=${aria2_RPC_passwd}" >>${aria2_conf}
            if [[ $? -eq 0 ]]; then
                echo -e "${Info} RPC key modification successfully! The new keys are:${Green_font_prefix}${aria2_RPC_passwd}${Font_color_suffix}(Missing optional parameters in configuration file automatically added to the bottom of configuration file)"
                if [[ ${read_123} != "1" ]]; then
                    Restart_aria2
                fi
            else
                echo -e "${Error} RPC key modification failed!The old key is:${Green_font_prefix}${aria2_passwd}${Font_color_suffix}"
            fi
        else
            sed -i 's/^rpc-secret='${aria2_passwd}'/rpc-secret='${aria2_RPC_passwd}'/g' ${aria2_conf}
            if [[ $? -eq 0 ]]; then
                echo -e "${Info} RPC key modification successfully!The new key is:${Green_font_prefix}${aria2_RPC_passwd}${Font_color_suffix}"
                if [[ ${read_123} != "1" ]]; then
                    Restart_aria2
                fi
            else
                echo -e "${Error} RPC key modification failed!The old key is：${Green_font_prefix}${aria2_passwd}${Font_color_suffix}"
            fi
        fi
    else
        echo -e "${Error} Consistent with the old configuration, no modification required..."
    fi
}
Set_aria2_RPC_port() {
    read_123=$1
    if [[ ${read_123} != "1" ]]; then
        Read_config
    fi
    if [[ -z "${aria2_port}" ]]; then
        aria2_port_1="empty (no configuration detected, may have been manually deleted or commented)"
    else
        aria2_port_1=${aria2_port}
    fi
    echo -e "
 The current RPC ports are: ${Green_font_prefix}${aria2_port_1}${Font_color_suffix}
"
    read -e -p " Enter a new RPC port (default: 6800): " aria2_RPC_port
    echo
    [[ -z "${aria2_RPC_port}" ]] && aria2_RPC_port="6800"
    if [[ "${aria2_port}" != "${aria2_RPC_port}" ]]; then
        if [[ -z "${aria2_port}" ]]; then
            echo -e "\nrpc-listen-port=${aria2_RPC_port}" >>${aria2_conf}
            if [[ $? -eq 0 ]]; then
                echo -e "${Info} RPC port modification successfully! The new port is：${Green_font_prefix}${aria2_RPC_port}${Font_color_suffix}(Missing optional parameters in configuration file automatically added to the bottom of configuration file)"
                Del_iptables
                Add_iptables
                Save_iptables
                if [[ ${read_123} != "1" ]]; then
                    Restart_aria2
                fi
            else
                echo -e "${Error} RPC port modification failed! The old port is：${Green_font_prefix}${aria2_port}${Font_color_suffix}"
            fi
        else
            sed -i 's/^rpc-listen-port='${aria2_port}'/rpc-listen-port='${aria2_RPC_port}'/g' ${aria2_conf}
            if [[ $? -eq 0 ]]; then
                echo -e "${Info} RPC port modification successfully! The new port is：${Green_font_prefix}${aria2_RPC_port}${Font_color_suffix}"
                Del_iptables
                Add_iptables
                Save_iptables
                if [[ ${read_123} != "1" ]]; then
                    Restart_aria2
                fi
            else
                echo -e "${Error} RPC port modification failed! The old port is：${Green_font_prefix}${aria2_port}${Font_color_suffix}"
            fi
        fi
    else
        echo -e "${Error} Consistent with the old configuration, no modification required..."
    fi
}
Set_aria2_RPC_dir() {
    read_123=$1
    if [[ ${read_123} != "1" ]]; then
        Read_config
    fi
    if [[ -z "${aria2_dir}" ]]; then
        aria2_dir_1="empty (no configuration detected, may have been manually deleted or commented)"
    else
        aria2_dir_1=${aria2_dir}
    fi
    echo -e "
 the current download directory is: ${Green_font_prefix}${aria2_dir_1}${Font_color_suffix}
"
    read -e -p " Please enter a new download directory (default): ${download_path}): " aria2_RPC_dir
    [[ -z "${aria2_RPC_dir}" ]] && aria2_RPC_dir="${download_path}"
    mkdir -p ${aria2_RPC_dir}
    echo
    if [[ "${aria2_dir}" != "${aria2_RPC_dir}" ]]; then
        if [[ -z "${aria2_dir}" ]]; then
            echo -e "\ndir=${aria2_RPC_dir}" >>${aria2_conf}
            if [[ $? -eq 0 ]]; then
                echo -e "${Info} Download directory modified successfully! The new location is：${Green_font_prefix}${aria2_RPC_dir}${Font_color_suffix}(Missing optional parameters in configuration file automatically added to the bottom of configuration file)"
                if [[ ${read_123} != "1" ]]; then
                    Restart_aria2
                fi
            else
                echo -e "${Error} Download directory modification failed! The old location is：${Green_font_prefix}${aria2_dir}${Font_color_suffix}"
            fi
        else
            aria2_dir_2=$(echo "${aria2_dir}" | sed 's/\//\\\//g')
            aria2_RPC_dir_2=$(echo "${aria2_RPC_dir}" | sed 's/\//\\\//g')
            sed -i "s@^\(dir=\).*@\1${aria2_RPC_dir_2}@" ${aria2_conf}
            sed -i "s@^\(DOWNLOAD_PATH='\).*@\1${aria2_RPC_dir_2}'@" ${aria2_conf_dir}/*.sh
            if [[ $? -eq 0 ]]; then
                echo -e "${Info} Download directory modified successfully! The new location is：${Green_font_prefix}${aria2_RPC_dir}${Font_color_suffix}"
                if [[ ${read_123} != "1" ]]; then
                    Restart_aria2
                fi
            else
                echo -e "${Error} Download directory modification failed! The old location is：${Green_font_prefix}${aria2_dir}${Font_color_suffix}"
            fi
        fi
    else
        echo -e "${Error} Consistent with the old configuration, no modification required..."
    fi
}
Set_aria2_RPC_passwd_port_dir() {
    Read_config
    Set_aria2_RPC_passwd "1"
    Set_aria2_RPC_port "1"
    Set_aria2_RPC_dir "1"
    Restart_aria2
}
Set_aria2_vim_conf() {
    Read_config
    aria2_port_old=${aria2_port}
    aria2_dir_old=${aria2_dir}
    echo -e "
 configuration file location：${Green_font_prefix}${aria2_conf}${Font_color_suffix}

 ${Tip} Notes on Manual Configuration File Modification：
 
 ${Green_font_prefix}1.${Font_color_suffix} Open by default using the nano text editor
 ${Green_font_prefix}2.${Font_color_suffix} exit and save file: press ${Green_font_prefix}Ctrl+X${Font_color_suffix} key combination ${Green_font_prefix}y${Font_color_suffix} ，press ${Green_font_prefix}Enter${Font_color_suffix} key
 ${Green_font_prefix}3.${Font_color_suffix} To exit from saving files: press ${Green_font_prefix}Ctrl+X${Font_color_suffix} key combination ${Green_font_prefix}n${Font_color_suffix}
 ${Green_font_prefix}4.${Font_color_suffix} nano detailed usage tutorial：${Green_font_prefix}https://p3terx.com/archives/linux-nano-tutorial.html${Font_color_suffix}
 ${Green_font_prefix}5.${Font_color_suffix} The configuration file has Chinese annotations. If there is a problem with the language setting, the Chinese code will be scrambled
 "
    read -e -p "Press any key to continue and Ctrl+C to cancel" var
    nano "${aria2_conf}"
    Read_config
    if [[ ${aria2_port_old} != ${aria2_port} ]]; then
        aria2_RPC_port=${aria2_port}
        aria2_port=${aria2_port_old}
        Del_iptables
        Add_iptables
        Save_iptables
    fi
    if [[ ${aria2_dir_old} != ${aria2_dir} ]]; then
        mkdir -p ${aria2_dir}
        aria2_dir_2=$(echo "${aria2_dir}" | sed 's/\//\\\//g')
        aria2_dir_old_2=$(echo "${aria2_dir_old}" | sed 's/\//\\\//g')
        sed -i "s@^\(DOWNLOAD_PATH='\).*@\1${aria2_dir_2}'@" ${aria2_conf_dir}/*.sh
    fi
    Restart_aria2
}
Reset_aria2_conf() {
    Read_config
    aria2_port_old=${aria2_port}
    echo
    echo -e "${Tip} This operation re-downloads the Aria2 perfect configuration scheme, and all configuration settings are lost."
    echo
    read -e -p "Press any key to continue and Ctrl+C to cancel" var
    Download_aria2_conf
    Read_config
    if [[ ${aria2_port_old} != ${aria2_port} ]]; then
        aria2_RPC_port=${aria2_port}
        aria2_port=${aria2_port_old}
        Del_iptables
        Add_iptables
        Save_iptables
    fi
    Restart_aria2
}
Read_config() {
    status_type=$1
    if [[ ! -e ${aria2_conf} ]]; then
        if [[ ${status_type} != "un" ]]; then
            echo -e "${Error} Aria 2 configuration file does not exist!" && exit 1
        fi
    else
        conf_text=$(cat ${aria2_conf} | grep -v '#')
        aria2_dir=$(echo -e "${conf_text}" | grep "^dir=" | awk -F "=" '{print $NF}')
        aria2_port=$(echo -e "${conf_text}" | grep "^rpc-listen-port=" | awk -F "=" '{print $NF}')
        aria2_passwd=$(echo -e "${conf_text}" | grep "^rpc-secret=" | awk -F "=" '{print $NF}')
        aria2_bt_port=$(echo -e "${conf_text}" | grep "^listen-port=" | awk -F "=" '{print $NF}')
        aria2_dht_port=$(echo -e "${conf_text}" | grep "^dht-listen-port=" | awk -F "=" '{print $NF}')
    fi
}
View_Aria2() {
    check_installed_status
    Read_config
    IPV4=$(
        wget -qO- -t1 -T2 -4 api.ip.sb/ip ||
            wget -qO- -t1 -T2 -4 ifconfig.io/ip ||
            wget -qO- -t1 -T2 -4 www.trackip.net/ip
    )
    IPV6=$(
        wget -qO- -t1 -T2 -6 api.ip.sb/ip ||
            wget -qO- -t1 -T2 -6 ifconfig.io/ip ||
            wget -qO- -t1 -T2 -6 www.trackip.net/ip
    )
    [[ -z "${IPV4}" ]] && IPV4="IPv4 address detection failure"
    [[ -z "${IPV6}" ]] && IPV6="IPv6 address detection failure"
    [[ -z "${aria2_dir}" ]] && aria2_dir="configuration parameter not found"
    [[ -z "${aria2_port}" ]] && aria2_port="configuration parameter not found"
    [[ -z "${aria2_passwd}" ]] && aria2_passwd="Configuration parameter not found (or no key)"
    if [[ -z "${IPV4}" || -z "${aria2_port}" ]]; then
        AriaNg_URL="null"
    else
        AriaNg_API="/#!/settings/rpc/set/ws/${IPV4}/${aria2_port}/jsonrpc/$(echo -n ${aria2_passwd} | base64)"
        AriaNg_URL="http://ariang.js.org${AriaNg_API}"
    fi
    clear
    echo -e "\nAria2 simple configuration information：\n
 IPv4 address\t: ${Green_font_prefix}${IPV4}${Font_color_suffix}
 IPv6 address\t: ${Green_font_prefix}${IPV6}${Font_color_suffix}
 RPC Port\t: ${Green_font_prefix}${aria2_port}${Font_color_suffix}
 RPC key\t: ${Green_font_prefix}${aria2_passwd}${Font_color_suffix}
 download directory\t: ${Green_font_prefix}${aria2_dir}${Font_color_suffix}
 AriaNg link\t: ${Green_font_prefix}${AriaNg_URL}${Font_color_suffix}\n"
}
View_Log() {
    [[ ! -e ${aria2_log} ]] && echo -e "${Error} Aria2 log file does not exist!" && exit 1
    echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} stop viewing logs" && echo -e "If you need to view the full log content, use ${Red_font_prefix}cat ${aria2_log}${Font_color_suffix} instructions." && echo
    tail -f ${aria2_log}
}
Clean_Log() {
    [[ ! -e ${aria2_log} ]] && echo -e "${Error} Aria2 log file does not exist!" && exit 1
    echo >${aria2_log}
    echo -e "${Info} Aria2 The log is empty!"
}
crontab_update_status() {
    crontab -l | grep "tracker.sh"
}
Update_bt_tracker_cron() {
    check_installed_status
    check_crontab_installed_status
    if [[ -z $(crontab_update_status) ]]; then
        echo
        echo -e " Is it on? ${Green_font_prefix}automatic update BT-Tracker${Font_color_suffix} Function?(May increase BT download speed)[Y/n] \c"
        read -e crontab_update_status_ny
        [[ -z "${crontab_update_status_ny}" ]] && crontab_update_status_ny="y"
        if [[ ${crontab_update_status_ny} == [Yy] ]]; then
            crontab_update_start
        else
            echo && echo " Cancelled..."
        fi
    else
        echo
        echo -e " Whether to close or not? ${Red_font_prefix}automatic update BT-Tracker${Font_color_suffix} Function?[y/N] \c"
        read -e crontab_update_status_ny
        [[ -z "${crontab_update_status_ny}" ]] && crontab_update_status_ny="n"
        if [[ ${crontab_update_status_ny} == [Yy] ]]; then
            crontab_update_stop
        else
            echo && echo " Cancelled..."
        fi
    fi
}
crontab_update_start() {
    crontab -l >"/tmp/crontab.bak"
    sed -i "/aria2.sh update-bt-tracker/d" "/tmp/crontab.bak"
    sed -i "/tracker.sh/d" "/tmp/crontab.bak"
    echo -e "\n0 7 * * * /bin/bash <(wget -qO- git.io/tracker.sh) ${aria2_conf} RPC 2>&1 | tee ${aria2_conf_dir}/tracker.log" >>"/tmp/crontab.bak"
    crontab "/tmp/crontab.bak"
    rm -f "/tmp/crontab.bak"
    if [[ -z $(crontab_update_status) ]]; then
        echo && echo -e "${Error} automatic update BT-Tracker failed to open failure!" && exit 1
    else
        Update_bt_tracker
        echo && echo -e "${Info} Auto Update BT - Tracker turned on successfully!"
    fi
}
crontab_update_stop() {
    crontab -l >"/tmp/crontab.bak"
    sed -i "/aria2.sh update-bt-tracker/d" "/tmp/crontab.bak"
    sed -i "/tracker.sh/d" "/tmp/crontab.bak"
    crontab "/tmp/crontab.bak"
    rm -f "/tmp/crontab.bak"
    if [[ -n $(crontab_update_status) ]]; then
        echo && echo -e "${Error} Automatic update BT - Tracker shutdown failed!" && exit 1
    else
        echo && echo -e "${Info} Automatic update BT - Tracker shutdown successfully!"
    fi
}
Update_bt_tracker() {
    check_installed_status
    check_pid
    [[ -z $PID ]] && {
        bash <(wget -qO- git.io/tracker.sh) ${aria2_conf}
    } || {
        bash <(wget -qO- git.io/tracker.sh) ${aria2_conf} RPC
    }
}
Update_aria2() {
    check_installed_status
    check_new_ver
    check_ver_comparison
}
Uninstall_aria2() {
    check_installed_status "un"
    echo "Are you sure you want to uninstall Aria 2? (y/N)"
    echo
    read -e -p "(Default: n):" unyn
    [[ -z ${unyn} ]] && unyn="n"
    if [[ ${unyn} == [Yy] ]]; then
        crontab -l >"/tmp/crontab.bak"
        sed -i "/aria2.sh/d" "/tmp/crontab.bak"
        sed -i "/tracker.sh/d" "/tmp/crontab.bak"
        crontab "/tmp/crontab.bak"
        rm -f "/tmp/crontab.bak"
        check_pid
        [[ ! -z $PID ]] && kill -9 ${PID}
        Read_config "un"
        Del_iptables
        Save_iptables
        rm -rf "${aria2c}"
        rm -rf "${aria2_conf_dir}"
        if [[ ${release} = "centos" ]]; then
            chkconfig --del aria2
        else
            update-rc.d -f aria2 remove
        fi
        rm -rf "/etc/init.d/aria2"
        echo && echo "Aria 2 uninstallation complete!" && echo
    else
        echo && echo "Uninstall Canceled..." && echo
    fi
}
Add_iptables() {
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${aria2_RPC_port} -j ACCEPT
    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${aria2_bt_port} -j ACCEPT
    iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${aria2_dht_port} -j ACCEPT
}
Del_iptables() {
    iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${aria2_port} -j ACCEPT
    iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${aria2_bt_port} -j ACCEPT
    iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${aria2_dht_port} -j ACCEPT
}
Save_iptables() {
    if [[ ${release} == "centos" ]]; then
        service iptables save
    else
        iptables-save >/etc/iptables.up.rules
    fi
}
Set_iptables() {
    if [[ ${release} == "centos" ]]; then
        service iptables save
        chkconfig --level 2345 iptables on
    else
        iptables-save >/etc/iptables.up.rules
        echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' >/etc/network/if-pre-up.d/iptables
        chmod +x /etc/network/if-pre-up.d/iptables
    fi
}
Update_Shell() {
    sh_new_ver=$(wget -qO- -t1 -T3 "https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/aria2.sh" | grep 'sh_ver="' | awk -F "=" '{print $NF}' | sed 's/\"//g' | head -1) && sh_new_type="github"
    [[ -z ${sh_new_ver} ]] && echo -e "${Error} Unable to link to Github!" && exit 0
    if [[ -e "/etc/init.d/aria2" ]]; then
        rm -rf /etc/init.d/aria2
        Service_aria2
        Restart_aria2
    fi
    if [[ -n $(crontab_update_status) ]]; then
        crontab_update_stop
    fi
    wget -N "https://raw.githubusercontent.com/et-was/aria2_ariaNg/main/aria2.sh" && chmod +x aria2.sh
    echo -e "The script has been updated to the latest version[ ${sh_new_ver} ] !(Note: Since the update is to overwrite the currently running script directly, you may be prompted for some errors that you can ignore)" && exit 0
}

echo && echo -e " Aria2 One-Key Installation Management Script Enhancement ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix} by \033[1;35mP3TERX.COM\033[0m
 
 ${Green_font_prefix} 0.${Font_color_suffix} upgrade script
 ———————————————————————
 ${Green_font_prefix} 1.${Font_color_suffix} Install Aria2
 ${Green_font_prefix} 2.${Font_color_suffix} Update Aria2
 ${Green_font_prefix} 3.${Font_color_suffix} Uninstall Aria2
 ———————————————————————
 ${Green_font_prefix} 4.${Font_color_suffix} Start Aria2
 ${Green_font_prefix} 5.${Font_color_suffix} Stop Aria2
 ${Green_font_prefix} 6.${Font_color_suffix} Restart Aria2
 ———————————————————————
 ${Green_font_prefix} 7.${Font_color_suffix} Modify Configuration
 ${Green_font_prefix} 8.${Font_color_suffix} View Configuration
 ${Green_font_prefix} 9.${Font_color_suffix} View Logs
 ${Green_font_prefix}10.${Font_color_suffix} Clear Logs
 ———————————————————————
 ${Green_font_prefix}11.${Font_color_suffix} Manual update BT-Tracker
 ${Green_font_prefix}12.${Font_color_suffix} Automatic updates BT-Tracker
 ———————————————————————" && echo
if [[ -e ${aria2c} ]]; then
    check_pid
    if [[ ! -z "${PID}" ]]; then
        echo -e " Aria2 Status: ${Green_font_prefix}Installed${Font_color_suffix} | ${Green_font_prefix}Activated${Font_color_suffix}"
    else
        echo -e " Aria2 Status: ${Green_font_prefix}Installed${Font_color_suffix} | ${Red_font_prefix}Not activated${Font_color_suffix}"
    fi
    if [[ -n $(crontab_update_status) ]]; then
        echo
        echo -e " Automatic updates BT-Tracker: ${Green_font_prefix}Opened${Font_color_suffix}"
    else
        echo
        echo -e " Automatic updates BT-Tracker: ${Red_font_prefix}Unopened${Font_color_suffix}"
    fi
else
    echo -e " Aria2 Status: ${Red_font_prefix}Not installed${Font_color_suffix}"
fi
echo
read -e -p " Please enter the number [0-12]:" num
case "$num" in
0)
    Update_Shell
    ;;
1)
    Install_aria2
    ;;
2)
    Update_aria2
    ;;
3)
    Uninstall_aria2
    ;;
4)
    Start_aria2
    ;;
5)
    Stop_aria2
    ;;
6)
    Restart_aria2
    ;;
7)
    Set_aria2
    ;;
8)
    View_Aria2
    ;;
9)
    View_Log
    ;;
10)
    Clean_Log
    ;;
11)
    Update_bt_tracker
    ;;
12)
    Update_bt_tracker_cron
    ;;
*)
    echo
    echo -e " ${Error} Please enter the correct number"
    ;;
esac
