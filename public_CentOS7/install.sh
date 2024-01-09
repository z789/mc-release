#!/bin/bash

## 1. 安装新内核
sudo rpm -ivh kernel-5.15.5mc.el7.x86_64.rpm


## 2. 安装应用层软件
sudo tar -C / -zxvf mctool.el7.tgz


## 3. 更改bash.profile bash-label.profile python.profile 文件中的用户名为当前用户名
USER=`whoami`
sudo sed -i "s/\/home\/chenfc/\/home\/${USER}/" /etc/mc/profile/bash.profile
sudo sed -i "s/\/home\/chenfc/\/home\/${USER}/" /etc/mc/profile/bash-label.profile
sudo sed -i "s/\/home\/chenfc/\/home\/${USER}/" /etc/mc/profile/python.profile


## 4. 配置日志精灵进程随系统启动 
if [ ! -e "/etc/rc.d/rc.local" ]; then
	sudo touch /etc/rc.local
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
