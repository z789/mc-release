#!/bin/bash

## 1. 安装新内核
sudo rpm -ivh kernel-5.15.5mc.el7.x86_64.rpm


## 2. 安装应用层软件
sudo tar -C / -zxvf mctool.el7.tgz


## 3. 更改bash.profile文件中的用户名为当前用户名
CUR_USER=`whoami`
sudo sed -i "s/\/home\/chenfc/\/home\/${CUR_USER}/" /etc/mc/profile/bash.profile

### 登陆shell是bash
function add_user_profile_bash() {
        USER=$1
        USHELL=$2
        FILE=$3
        SET_INTERP_RULE=/proc/sys/kernel/mc/set_interp_rule
        echo "" | sudo tee -a ${FILE} > /dev/null
        echo "## user \"${USER}\" bash config" | sudo tee -a ${FILE} > /dev/null
        echo "echo 'add ${USHELL}   epath /home/${USER}/.bashrc' > ${SET_INTERP_RULE}" | sudo tee -a ${FILE} > /dev/null
        echo "echo 'add ${USHELL}   epath /home/${USER}/.bash_history' > ${SET_INTERP_RULE}" | sudo tee -a ${FILE} > /dev/null
        echo "echo 'add ${USHELL}   epath /home/${USER}/.bash_logout' > ${SET_INTERP_RULE}" | sudo tee -a ${FILE} > /dev/null
        echo "echo 'add ${USHELL}   epath /home/${USER}/.bash_profile' > ${SET_INTERP_RULE}" | sudo tee -a ${FILE} > /dev/null
        echo "echo 'add ${USHELL}   epath /home/${USER}/.profile' > ${SET_INTERP_RULE}" | sudo tee -a ${FILE} > /dev/null
}

### 登陆shell是其他shell， 如ksh等. 单机版现在暂不支持
function add_user_profile_ksh() {
        USER=$1
        USHELL=$2
        FILE=$3
        SET_INTERP_RULE=/proc/sys/kernel/mc/set_interp_rule
        echo "" | sudo tee -a ${FILE} > /dev/null
        echo "## Now, desktop version not support ksh config" | sudo tee -a ${FILE} > /dev/null
        echo "## user \"${USER}\" ksh config" | sudo tee -a ${FILE} > /dev/null
}

function add_user_profile() {
        USER=$1
        REAL_USHELL=$2
        FILE=$3
        if [[ "${REAL_USHELL}" == "/bin/bash" || "${REAL_USHELL}" == "/usr/bin/bash" ]]; then
                add_user_profile_bash ${USER} ${REAL_USHELL} ${FILE}
#       elif [[ "${REAL_USHELL}" == "/bin/ksh" || "${REAL_USHELL}" == "/usr/bin/ksh" ]]; then
#               add_user_profile_ksh ${USER} ${REAL_USHELL} ${FILE}
        fi
}

while read line
do
        USER=`echo $line | awk -F : '{print $1}'`
        USHELL=`echo $line | awk -F : '{print $7}'`
        if [[ "${USHELL}" == "/bin/bash" || "${USHELL}" == "/usr/bin/bash" ||
                 "${USHELL}" == "/bin/sh" || "${USHELL}" == "/usr/bin/sh" ]]; then

                if [[ "${USER}" != "root" && "${USER}" != "${CUR_USER}" ]]; then
                        REAL_USHELL=`realpath ${USHELL}`
                        add_user_profile ${USER} ${REAL_USHELL} /etc/mc/profile/bash.profile
                fi
        fi
done < /etc/passwd


## 4. 配置日志精灵进程随系统启动 
if [ ! -e "/etc/rc.d/rc.local" ]; then
        sudo touch /etc/rc.d/rc.local
        sudo sh -c '/bin/echo "#!/bin/bash" >> /etc/rc.d/rc.local'
        sudo sh -c '/bin/echo "" >> /etc/rc.d/rc.local'
        sudo sh -c '/bin/echo "exit 0" >>  /etc/rc.d/rc.local'
fi 

sudo sed -i '$i /usr/local/bin/mc-logd -dc /var/log/mclog' /etc/rc.d/rc.local

if [ ! -x "/etc/rc.d/rc.local" ]; then
	sudo chmod +x /etc/rc.d/rc.local
fi

sudo systemctl enable rc-local
sudo systemctl start rc-local


## 5. 对系统进行基础签名、设置mime
sudo /usr/local/bin/mc-sign-mime-tool -sm sha512 /etc/mc/mc_key.pem /etc/mc/mc_key.x509 /


## 6. 重启系统，选择新安装的内核
echo ""
echo "Please reboot system, then select new kernel"
