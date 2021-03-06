#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/fix-data/bin/bin:/fix-data/bin/sbin:/usr/local/bin:/usr/local/sbin:~/bin

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script"
    exit 1
fi

cur_dir=$(pwd)
isSSL=$1

. lnmp.conf
. include/main.sh

Get_Dist_Name
Check_Stack
Check_DB

Upgrade_Dependent()
{
    if [ "$PM" = "yum" ]; then
        Echo_Blue "[+] Yum installing dependent packages..."
        Get_Dist_Version
        for packages in patch wget crontabs unzip tar ca-certificates net-tools libc-client-devel psmisc libXpm-devel git-core c-ares-devel libicu-devel libxslt libxslt-devel xz expat-devel bzip2 bzip2-devel libaio-devel rpcgen libtirpc-devel perl python-devel cyrus-sasl-devel sqlite-devel oniguruma-devel re2c;
        do yum -y install $packages; done
        yum -y update nss

        if [ "${DISTRO}" = "CentOS" ] && echo "${CentOS_Version}" | grep -Eqi "^8"; then
            if ! yum repolist all|grep PowerTools; then
                echo "PowerTools repository not found, add PowerTools repository ..."
                cat >/etc/yum.repos.d/CentOS-PowerTools.repo<<EOF
[PowerTools]
name=CentOS-\$releasever - PowerTools
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=PowerTools&infra=\$infra
#baseurl=http://mirror.centos.org/\$contentdir/\$releasever/PowerTools/\$basearch/os/
gpgcheck=1
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
            fi
            dnf --enablerepo=PowerTools install rpcgen re2c -y
            dnf --enablerepo=PowerTools install oniguruma-devel -y
        fi

        if echo "${CentOS_Version}" | grep -Eqi "^7" || echo "${RHEL_Version}" | grep -Eqi "^7"; then
            yum -y install epel-release
            if [ "${country}" = "CN" ]; then
                sed -i "s@^#baseurl=http://download.fedoraproject.org/pub@baseurl=http://mirrors.aliyun.com@g" /etc/yum.repos.d/epel*.repo
                sed -i "s@^metalink@#metalink@g" /etc/yum.repos.d/epel*.repo
            fi
            yum -y install oniguruma oniguruma-devel
            if [ "${CheckMirror}" = "n" ]; then
                cd ${cur_dir}/src/
                yum -y install ./oniguruma-6.8.2-1.el7.x86_64.rpm
                yum -y install ./oniguruma-devel-6.8.2-1.el7.x86_64.rpm
            fi
        fi
    elif [ "$PM" = "apt" ]; then
        Echo_Blue "[+] apt-get installing dependent packages..."
        apt-get update -y
        for packages in debian-keyring debian-archive-keyring build-essential bison libkrb5-dev libcurl3-gnutls libcurl4-gnutls-dev libcurl4-openssl-dev libcap-dev ca-certificates libc-client2007e-dev psmisc patch git libc-ares-dev libicu-dev e2fsprogs libxslt1.1 libxslt1-dev libc-client-dev xz-utils libexpat1-dev bzip2 libbz2-dev libaio-dev libtirpc-dev python-dev libsqlite3-dev libonig-dev;
        do apt-get --no-install-recommends install -y $packages; done
    fi
}

if [ "${isSSL}" == "ssl" ]; then
    echo "+--------------------------------------------------+"
    echo "|  A tool to upgrade lnmp 1.4 certbot to acme.sh   |"
    echo "+--------------------------------------------------+"
    echo "|For more information please visit https://lnmp.org|"
    echo "+--------------------------------------------------+"
    if [[ "${Get_Stack}" =~ "lnmp" ]]; then
        domain=""
        while :;do
            Echo_Yellow "Please enter domain(example: www.lnmp.org): "
            read domain
            if [ "${domain}" != "" ]; then
                if [ ! -f "/fix-data/bin/nginx/conf/vhost/${domain}.conf" ]; then
                    Echo_Red "${domain} is not exist,please check!"
                    exit 1
                else
                    echo " Your domain: ${domain}"
                    if ! grep -q "/etc/letsencrypt/live/${domain}/fullchain.pem" "/fix-data/bin/nginx/conf/vhost/${domain}.conf"; then
                        Echo_Red "SSL configuration NOT found in the ${domain} config file!"
                        exit 1
                    fi
                    break
                fi
            else
                Echo_Red "Domain name can't be empty!"
            fi
        done

        Echo_Yellow "Enter more domain name(example: lnmp.org *.lnmp.org): "
        read moredomain
        if [ "${moredomain}" != "" ]; then
            echo " domain list: ${moredomain}"
        fi

        vhostdir="/fix-data/app/${domain}"
        echo "Please enter the directory for the domain: $domain"
        Echo_Yellow "Default directory: /fix-data/app/${domain}: "
        read vhostdir
        if [ "${vhostdir}" == "" ]; then
            vhostdir="/fix-data/app/${domain}"
        fi
        echo "Virtual Host Directory: ${vhostdir}"

        if [ ! -d "${vhostdir}" ]; then
            Echo_Red "${vhostdir} does not exist or is not a directory!"
            exit 1
        fi

        letsdomain=""
        if [ "${moredomain}" != "" ]; then
            letsdomain="-d ${domain}"
            for i in ${moredomain};do
                letsdomain=${letsdomain}" -d ${i}"
            done
        else
            letsdomain="-d ${domain}"
        fi

        if [ -s /fix-data/bin/acme.sh/acme.sh ]; then
            echo "/fix-data/bin/acme.sh/acme.sh [found]"
        else
            cd /tmp
            [[ -f latest.tar.gz ]] && rm -f latest.tar.gz
            wget https://soft.vpser.net/lib/acme.sh/latest.tar.gz --prefer-family=IPv4 --no-check-certificate
            tar zxf latest.tar.gz
            cd acme.sh-*
            ./acme.sh --install --log --home /fix-data/bin/acme.sh --certhome /fix-data/bin/nginx/conf/ssl
            cd ..
            rm -f latest.tar.gz
            rm -rf acme.sh-*
            sed -i 's/cat "\$CERT_PATH"$/#cat "\$CERT_PATH"/g' /fix-data/bin/acme.sh/acme.sh
            if command -v yum >/dev/null 2>&1; then
                yum -y update nss
                service crond restart
                chkconfig crond on
            elif command -v apt-get >/dev/null 2>&1; then
                /etc/init.d/cron restart
                update-rc.d cron defaults
            fi
        fi

        . "/fix-data/bin/acme.sh/acme.sh.env"

        if [ -s /fix-data/bin/nginx/conf/ssl/${domain}/fullchain.cer ]; then
            echo "Removing exist domain certificate..."
            rm -rf /fix-data/bin/nginx/conf/ssl/${domain}
        fi

        echo "Starting create SSL Certificate use Let's Encrypt..."
        /fix-data/bin/acme.sh/acme.sh --issue ${letsdomain} -w ${vhostdir} --reloadcmd "/etc/init.d/nginx reload"
        lets_status=$?
        if [ "${lets_status}" = 0 ]; then
            Echo_Green "Let's Encrypt SSL Certificate create successfully."
            echo "Modify ${domain} configure..."
            sed -i "s@/etc/letsencrypt/live/${domain}/fullchain.pem@/fix-data/bin/nginx/conf/ssl/${domain}/fullchain.cer@g" "/fix-data/bin/nginx/conf/vhost/${domain}.conf"
            sed -i "s@/etc/letsencrypt/live/${domain}/privkey.pem@/fix-data/bin/nginx/conf/ssl/${domain}/${domain}.key@g" "/fix-data/bin/nginx/conf/vhost/${domain}.conf"
            echo "done."

            if crontab -l|grep -q "/bin/certbot renew"; then
                (crontab -l | grep -v "/bin/certbot renew") | crontab -
            fi

            /etc/init.d/nginx reload
            sleep 1
            Echo_Green "upgrade ${domain} successfully."
        else
            Echo_Red "Let's Encrypt SSL Certificate create failed!"
            Echo_Red "upgrade ${domain} fialed."
        fi
    elif [ "${Get_Stack}" == "lamp" ]; then
        domain=""
        while :;do
            Echo_Yellow "Please enter domain(example: www.lnmp.org): "
            read domain
            if [ "${domain}" != "" ]; then
                if [ ! -f "/fix-data/bin/apache/conf/vhost/${domain}.conf" ]; then
                    Echo_Red "${domain} is not exist,please check!"
                    exit 1
                else
                    echo " Your domain: ${domain}"
                    if ! grep -q "/etc/letsencrypt/live/${domain}/privkey.pem" "/fix-data/bin/apache/conf/vhost/${domain}.conf"; then
                        Echo_Red "SSL configuration NOT found in the ${domain} config file!"
                        exit 1
                    fi
                    break
                fi
            else
                Echo_Red "Domain name can't be empty!"
            fi
        done

        Echo_Yellow "Enter more domain name(example: lnmp.org *.lnmp.org): "
        read moredomain
        if [ "${moredomain}" != "" ]; then
            echo " domain list: ${moredomain}"
        fi

        vhostdir="/fix-data/app/${domain}"
        echo "Please enter the directory for the domain: $domain"
        Echo_Yellow "Default directory: /fix-data/app/${domain}: "
        read vhostdir
        if [ "${vhostdir}" == "" ]; then
            vhostdir="/fix-data/app/${domain}"
        fi
        echo "Virtual Host Directory: ${vhostdir}"

        if [ ! -d "${vhostdir}" ]; then
            Echo_Red "${vhostdir} does not exist or is not a directory!"
            exit 1
        fi

        letsdomain=""
        if [ "${moredomain}" != "" ]; then
            letsdomain="-d ${domain}"
            for i in ${moredomain};do
                letsdomain=${letsdomain}" -d ${i}"
            done
        else
            letsdomain="-d ${domain}"
        fi

        if [ -s /fix-data/bin/acme.sh/acme.sh ]; then
            echo "/fix-data/bin/acme.sh/acme.sh [found]"
        else
            cd /tmp
            [[ -s latest.tar.gz ]] && rm -f latest.tar.gz
            wget https://soft.vpser.net/lib/acme.sh/latest.tar.gz --prefer-family=IPv4 --no-check-certificate
            tar zxf latest.tar.gz
            cd acme.sh-*
            ./acme.sh --install --log --home /fix-data/bin/acme.sh --certhome /fix-data/bin/apache/conf/ssl
            cd ..
            rm -f latest.tar.gz
            rm -rf acme.sh-*
            sed -i 's/cat "\$CERT_PATH"$/#cat "\$CERT_PATH"/g' /fix-data/bin/acme.sh/acme.sh
            if command -v yum >/dev/null 2>&1; then
                yum -y update nss
                yum -y install ca-certificates
                service crond restart
                chkconfig crond on
            elif command -v apt-get >/dev/null 2>&1; then
                /etc/init.d/cron restart
                update-rc.d cron defaults
            fi
        fi

        . "/fix-data/bin/acme.sh/acme.sh.env"

        if [ -s /fix-data/bin/apache/conf/ssl/${domain}/fullchain.cer ]; then
            echo "Removing exist domain certificate..."
            rm -rf /fix-data/bin/apache/conf/ssl/${domain}
        fi

        echo "Starting create SSL Certificate use Let's Encrypt..."
        /fix-data/bin/acme.sh/acme.sh --issue ${letsdomain} -w ${vhostdir} --reloadcmd "/etc/init.d/httpd graceful"
        lets_status=$?
        if [ "${lets_status}" = 0 ]; then
            Echo_Green "Let's Encrypt SSL Certificate create successfully."
            echo "Modify ${domain} configure..."
            sed -i "s@/etc/letsencrypt/live/${domain}/fullchain.pem@/fix-data/bin/apache/conf/ssl/${domain}/${domain}.cer@g" "/fix-data/bin/apache/conf/vhost/${domain}.conf"
            sed -i "s@/etc/letsencrypt/live/${domain}/privkey.pem@/fix-data/bin/apache/conf/ssl/${domain}/${domain}.key@g" "/fix-data/bin/apache/conf/vhost/${domain}.conf"
            sed -i "/\/usr\/local\/apache\/conf\/ssl\/${domain}\/${domain}.key/a\SSLCertificateChainFile \/usr\/local\/apache\/conf\/ssl\/${domain}\/ca.cer" "/fix-data/bin/apache/conf/vhost/${domain}.conf"
            echo "done."

            if crontab -l|grep -q "/bin/certbot renew"; then
                (crontab -l | grep -v "/bin/certbot renew") | crontab -
            fi

            /etc/init.d/httpd graceful
            sleep 1
            Echo_Green "upgrade ${domain} successfully."
        else
            Echo_Red "Let's Encrypt SSL Certificate create failed!"
            Echo_Red "upgrade ${domain} fialed."
        fi

    else
        Echo_Red "Can't get stack info and will not be able to upgrade."
    fi
else
    echo "+--------------------------------------------------+"
    echo "|  A tool to upgrade lnmp manager from 1.x to 1.7  |"
    echo "+--------------------------------------------------+"
    echo "|For more information please visit https://lnmp.org|"
    echo "+--------------------------------------------------+"
    Press_Start
    if [ "${Get_Stack}" == "unknow" ]; then
        Echo_Red "Can't get stack info."
        exit
    elif [ "${Get_Stack}" == "lnmp" ]; then
        Upgrade_Dependent
        echo "Copy lnmp manager..."
        sleep 1
        \cp ${cur_dir}/conf/lnmp /bin/lnmp
        chmod +x /bin/lnmp
        echo "Copy configure files..."
        sleep 1
        if [ ! -s /fix-data/bin/nginx/conf/enable-php.conf ]; then
            \cp ${cur_dir}/conf/enable-php.conf /fix-data/bin/nginx/conf/enable-php.conf
        fi
        if [ ! -s /fix-data/bin/nginx/conf/pathinfo.conf ]; then
            \cp ${cur_dir}/conf/pathinfo.conf /fix-data/bin/nginx/conf/pathinfo.conf
        fi
        if [ ! -s /fix-data/bin/nginx/conf/enable-php-pathinfo.conf ]; then
            \cp ${cur_dir}/conf/enable-php-pathinfo.conf /fix-data/bin/nginx/conf/enable-php-pathinfo.conf
        fi
        if [ ! -d /fix-data/bin/nginx/conf/rewrite ]; then
            \cp -ra ${cur_dir}/conf/rewrite /fix-data/bin/nginx/conf/
        fi
        if [ ! -d /fix-data/bin/nginx/conf/vhost ]; then
            mkdir /fix-data/bin/nginx/conf/vhost
        fi
    elif [ "${Get_Stack}" == "lnmpa" ]; then
        Upgrade_Dependent
        echo "Copy lnmp manager..."
        sleep 1
        \cp ${cur_dir}/conf/lnmpa /bin/lnmp
        chmod +x /bin/lnmp
        echo "Copy configure files..."
        sleep 1
        \cp ${cur_dir}/conf/proxy.conf /fix-data/bin/nginx/conf/proxy.conf
        if [ ! -s /fix-data/bin/nginx/conf/proxy-pass-php.conf ]; then
            \cp ${cur_dir}/conf/proxy-pass-php.conf /fix-data/bin/nginx/conf/proxy-pass-php.conf
        fi
        if ! grep -q "SetEnvIf X-Forwarded-Proto https HTTPS=on" /fix-data/bin/apache/conf/httpd.conf; then
            if /fix-data/bin/apache/bin/httpd -v|grep -Eqi "Apache/2.2."; then
                sed -i "/Include conf\/vhost\/\*.conf/i\SetEnvIf X-Forwarded-Proto https HTTPS=on\n" /fix-data/bin/apache/conf/httpd.conf
            elif /fix-data/bin/apache/bin/httpd -v|grep -Eqi "Apache/2.4."; then
                sed -i "/IncludeOptional conf\/vhost\/\*.conf/i\SetEnvIf X-Forwarded-Proto https HTTPS=on\n" /fix-data/bin/apache/conf/httpd.conf
            fi
        fi
        if [ ! -d /fix-data/bin/nginx/conf/vhost ]; then
            mkdir /fix-data/bin/nginx/conf/vhost
        fi
    elif [ "${Get_Stack}" == "lamp" ]; then
        Upgrade_Dependent
        echo "Copy configure files..."
        sleep 1
        \cp ${cur_dir}/conf/lamp /bin/lnmp
        chmod +x /bin/lnmp
        echo "Copy configure files..."
        sleep 1
        if /fix-data/bin/apache/bin/httpd -v|grep -Eqi "Apache/2.2."; then
            \cp ${cur_dir}/conf/httpd22-ssl.conf  /fix-data/bin/apache/conf/extra/httpd-ssl.conf
        elif /fix-data/bin/apache/bin/httpd -v|grep -Eqi "Apache/2.4."; then
            \cp ${cur_dir}/conf/httpd24-ssl.conf  /fix-data/bin/apache/conf/extra/httpd-ssl.conf
            sed -i 's/^#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/g' /fix-data/bin/apache/conf/httpd.conf
            sed -i 's/^LoadModule lbmethod_heartbeat_module/#LoadModule lbmethod_heartbeat_module/g' /fix-data/bin/apache/conf/httpd.conf
        fi
        if [ ! -d /fix-data/bin/apache/conf/vhost ]; then
            mkdir /fix-data/bin/apache/conf/vhost
        fi
    fi

    if [ "${DB_Name}" = "mariadb" ]; then
        sed -i 's#/etc/init.d/mysql#/etc/init.d/mariadb#' /bin/lnmp
    elif [ "${DB_Name}" = "None" ]; then
        sed -i 's#/etc/init.d/mysql.*##' /bin/lnmp
    fi

    if [ -s /fix-data/bin/acme.sh/acme.sh ]; then
        /fix-data/bin/acme.sh/acme.sh --upgrade
        sed -i 's/cat "\$CERT_PATH"$/#cat "\$CERT_PATH"/g' /fix-data/bin/acme.sh/acme.sh
    fi

    Echo_Green "upgrade lnmp manager complete."
fi