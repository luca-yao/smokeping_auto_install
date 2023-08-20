#!/bin/bash
#相關資料確認，每次安裝前調整即可
Package_Type=".tar.gz"
Version="smokeping-2.6.11"
FpingVersion="fping-3.10"
Package=$Version$Package_Type
FpingPackage=$FpingVersion$Package_Type
Dir="/usr/local/smokeping"
Setup="setup/build-perl-modules.sh"
smokeping_ver="/usr/local/smokeping/ver"

#顯示的顏色
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[資訊]${Font_color_suffix}"
Error="${Red_font_prefix}[錯誤]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

#判斷是否是root用戶
[ $(id -u) != "0" ] && { echo "${CFAILURE} ${Error}: 請您切換至root在執行本程式${CEND}"; exit 1; }

#取得程序PID
Get_PID(){
     PID=(`ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs`)
}

#讀取進度條
Loading_data(){
   read -e -p "請輸入您的對外IP(必填):" Ip
   read -e -p "請輸入公司名稱(網頁使用):" COMPANY
   read -e -p "請輸入連繫信箱:" CONTANTMAIL
   read -e -p "請輸入您的信箱伺服器:" MAILSERVER
   empty="" 
   while [[ "${Ip}" = $empty ]]
   do
       read -e -p "請輸入您的對外IP(必填):" Ip
   done
       IP=${Ip}

   if [ $COMPANY ]; then
       Company=$COMPANY
   else
       Company="Peter Random"

   fi    

   if [ $CONTANTMAIL ]; then
       Contantmail=$CONTANTMAIL
   else
       Contantmail="some@address.nowhere"
   fi

   if [ $MAILSERVER ]; then
       Mailserver=$MAILSERVER
   else
       Mailserver="my.mail.host"
   fi

}

#安裝來源庫
Install_Epel(){
       yum -y -q install epel-release
}

#安裝依賴套件
Install_Dependency(){
yum -y -q install perl httpd httpd-devel mod_fcgid rrdtool perl-CGI-SpeedyCGI fping rrdtool-perl perl-Sys-Syslog gcc gcc-c++ libxml* pango*  freetype-devel zlib-devel libpng-devel libart_lgpl-devel apr-util-devel apr-devel wqy-zenhei-fonts.noarch perl-CPAN perl-local-lib perl-Time-HiRes 
}

#下載並安裝smokeping
Download_Source(){
     cd ~
     wget  http://oss.oetiker.ch/smokeping/pub/$Package
     tar -zxf $Package
     cd $Version
     ./setup/build-perl-modules.sh /usr/local/smokeping/thirdparty
     ./configure --prefix=$Dir
     make install
     rm -fr $Package
}

#安裝fping
Download_Source2(){
    wget  http://fping.org/dist/$FpingPackage
    tar -zxf $FpingPackage
    cd $FpingVersion
    ./configure ${configure_opts[@]}
    if [[ $? -eq 0 ]]; then 
       make && make install
       rm -fr $FpingPackage
    else
       echo "fping編譯失敗，請重新操作" && exit 1
    fi
}

#清除文件
Delete_Files(){
     rm -fr /root/$Package
}

#配置smokeping
Configure_Smokeping(){
        cd $Dir
                mkdir cache var data
                mv htdocs/smokeping.fcgi.dist htdocs/smokeping.cgi
                cd $Dir/etc
                mv basepage.html.dist basepage.html
                mv config.dist config
                mv smokemail.dist smokemail
                mv tmail.dist tmail
                mv smokeping_secrets.dist smokeping_secrets
                chmod 600 /usr/local/smokeping/etc/smokeping_secrets
}

#修改smokeping權限
Change_Access(){
  chown -R apache:apache $Dir/cache
  chown -R apache:apache $Dir/var
  chown -R apache:apache $Dir/data
}

#設定Apache
Edit_apache_config(){
  echo "Alias /smokeping/cache /usr/local/smokeping/cache/
Alias /smokeping/cropper /usr/local/smokeping/htdocs/cropper/
Alias /smokeping /usr/local/smokeping/htdocs

<Directory /usr/local/smokeping>
 AllowOverride None
 Options All
 AddHandler cgi-script .fcgi .cgi
 Order allow,deny
 Allow from all
</Directory>" >  /etc/httpd/conf.d/smokeping.conf
 }

#修改smokeping_config
Edit_smokeping_config(){
           sed -i "s/Peter Random/"$Company"/g" /usr/local/smokeping/etc/config
           sed -i "s/some@address.nowhere/"$Contantmail"/g" /usr/local/smokeping/etc/config
           sed -i "s/my.mail.host/"$Mailserver"/g" /usr/local/smokeping/etc/config
           sed -i "14c cgiurl = http://"$IP"/bin/smokeping_cgi" /usr/local/smokeping/etc/config
           sed -i "s/smokemail.dist/smokemail/g" /usr/local/smokeping/etc/config
           sed -i "s/tmail.dist/tmail/g" /usr/local/smokeping/etc/config
           sed -i "s/basepage.html.dist/basepage.html/g" /usr/local/smokeping/etc/config
           sed -i "s/smokeping_secrets.dist/smokeping_secrets/g" /usr/local/smokeping/etc/config
           sed -i "50a charset = utf-8" /usr/local/smokeping/etc/config
}

#新增啟動程序
Config_Process(){
  cat>/etc/init.d/smokeping << \EOF 
#!/bin/sh 
#
# smokeping    This starts and stops the smokeping daemon
# chkconfig: 345 98 11
# description: Start/Stop the smokeping daemon
# processname: smokeping
# Source function library.
. /etc/rc.d/init.d/functions

SMOKEPING=/usr/local/smokeping/bin/smokeping
LOCKF=/var/lock/subsys/smokeping
CONFIG=/usr/local/smokeping/etc/config

[ -f $SMOKEPING ] || exit 0
[ -f $CONFIG ] || exit 0

RETVAL=0

case "$1" in
  start)
        echo -n $"Starting SMOKEPING: "
        daemon $SMOKEPING
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && touch $LOCKF
        ;;
  stop)
        echo -n $"Stopping SMOKEPING: "
        killproc $SMOKEPING
        RETVAL=$?
        echo
        [ $RETVAL -eq 0 ] && rm -f $LOCKF
        ;;
  status)
        status smokeping
        RETVAL=$?
        ;;
  reload)
        echo -n $"Reloading SMOKEPING: "
        killproc $SMOKEPING -HUP
        RETVAL=$?
        echo
        ;;
  restart)
        $0 stop
        sleep 3
        $0 start
        RETVAL=$?
        ;;
  condrestart)
        if [ -f $LOCKF ]; then
                $0 stop
                sleep 3
                $0 start
                RETVAL=$?
        fi
        ;;
  *)
        echo $"Usage: $0 {start|stop|status|restart|reload|condrestart}"
        exit 1
esac

exit $RETVAL

EOF
       chmod 755 /etc/init.d/smokeping
}

#關閉SELinux
Disable_SELinux(){
         setenforce 0
         sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
         sed -i "s/SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
}

#啟動smokeping
Run_SmokePing(){
      /etc/init.d/smokeping start
}

Single_Install(){
        echo
        kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs` 2>/dev/null
        rm -fr $Dir
        Loading_data
        Install_Dependency
        Download_Source
        Download_Source2
        Configure_Smokeping
        Change_Access
        Edit_apache_config
        Edit_smokeping_config
        Config_Process
        Disable_SELinux
        Delete_Files
        echo "installed" > ${smokeping_ver}
        echo -e "${Info} 安装 SmokePing 完成，請至/usr/local/smokeping/etc/config設定相關設置"
        echo -e "${Info} 利用 service smokeping start/stop 來啟動/關閉服務"
}
echo && echo -e "  SmokePing 一件安裝
  ${Green_font_prefix} 1.${Font_color_suffix} 安裝 SmokePing
  ${Green_font_prefix} 2.${Font_color_suffix} 啟動 SmokePing
  ${Green_font_prefix} 3.${Font_color_suffix} 停止 SmokePing
  ${Green_font_prefix} 4.${Font_color_suffix} 重啟 SmokePing
  ${Green_font_prefix} 9.${Font_color_suffix} 離開
  -------------------" && echo
if [[ -e ${smokeping_ver} ]]; then
  Get_PID
  if [[ ! -z "${PID}" ]]; then
                echo -e "程式確認: ${Green_font_prefix}已安装 Smokeping ${Font_color_suffix}且 ${Green_font_prefix}已啟動${Font_color_suffix}"
        else
                echo -e "程式確認: ${Green_font_prefix}已安装 Smokeping ${Font_color_suffix}但 ${Red_font_prefix}未啟動${Font_color_suffix}"
  fi
fi


read -p "請輸入 [1-9]:" number

case "$number" in
 "1")
        if [[ -e ${smokeping_ver} ]]; then
                while :; do echo
                        echo -e "${Tip} 已安裝${Green_font_prefix} Smokeping ${Font_color_suffix}，要重新安裝? [y/n]: "
                        read um
                        if [[ ! $um =~ ^[y,n]$ ]]; then
                                echo "輸入錯誤! 請輸入y或者n!"
                        else
                                break
                        fi
                done
                if [[ $um == "y" ]]; then
                        kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs` 2>/dev/null
                        rm -rf $Dir
                        echo
                        echo -e "${Info} Smokeping 已卸載安裝! 開始重新安装!"
                        echo
                        sleep 5
                        Single_Install
                        exit
                else
                        exit
                fi
        fi
        Single_Install
;;
"2")
        [[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安裝，請確認!" && exit 1
        /etc/init.d/smokeping start
;;

"3")
    [[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安裝，請確認!" && exit 1
        kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs` 2>/dev/null
;;

"4")
    [[ ! -e ${smokeping_ver} ]] && echo -e "${Error} Smokeping 没有安裝，請確認!" && exit 1
        kill -9 `ps -ef |grep "smokeping"|grep -v "grep"|grep -v "smokeping.sh"|awk '{print $2}'|xargs` 2>/dev/null
        /etc/init.d/smokeping start
;;

"9")
        exit
;;

"*")
    echo "輸入錯誤! 請重新輸入數字!"
;;

esac

