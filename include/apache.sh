#!/usr/bin/env bash

Install_Apache_22()
{
    Echo_Blue "[+] Installing ${Apache_Ver}..."
    if [ "${Stack}" = "lamp" ]; then
        groupadd app
        useradd -s /sbin/nologin -g app app
        mkdir -p ${Default_Website_Dir}
        chmod +w ${Default_Website_Dir}
        mkdir -p /dynamic-data/log/apache
        chmod 777 /dynamic-data/log/apache
        chown -R app:app ${Default_Website_Dir}
    fi
    Tarj_Cd ${Apache_Ver}.tar.bz2 ${Apache_Ver}
    ./configure --prefix=/fix-data/bin/apache --enable-mods-shared=most --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --with-ssl --enable-ssl --enable-deflate --enable-suexec --with-included-apr --with-expat=builtin
    Make_Install
    cd ${cur_dir}/src
    rm -rf ${cur_dir}/src/${Apache_Ver}

    mv /fix-data/bin/apache/conf/httpd.conf /fix-data/bin/apache/conf/httpd.conf.bak
    if [ "${Stack}" = "lamp" ]; then
        \cp ${cur_dir}/conf/httpd22-lamp.conf /fix-data/bin/apache/conf/httpd.conf
        \cp ${cur_dir}/conf/httpd-vhosts-lamp.conf /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
        \cp ${cur_dir}/conf/httpd22-ssl.conf /fix-data/bin/apache/conf/extra/httpd-ssl.conf
        \cp ${cur_dir}/conf/example/enable-apache-ssl-vhost-example.conf /fix-data/bin/apache/conf/enable-apache-ssl-vhost-example.conf
    elif [ "${Stack}" = "lnmpa" ]; then
        \cp ${cur_dir}/conf/httpd22-lnmpa.conf /fix-data/bin/apache/conf/httpd.conf
        \cp ${cur_dir}/conf/httpd-vhosts-lnmpa.conf /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
    fi
    \cp ${cur_dir}/conf/httpd-default.conf /fix-data/bin/apache/conf/extra/httpd-default.conf
    \cp ${cur_dir}/conf/mod_remoteip.conf /fix-data/bin/apache/conf/extra/mod_remoteip.conf

    sed -i 's/ServerAdmin you@example.com/ServerAdmin '${ServerAdmin}'/g' /fix-data/bin/apache/conf/httpd.conf
    sed -i 's/webmaster@example.com/'${ServerAdmin}'/g' /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
    mkdir -p /fix-data/bin/apache/conf/vhost

    if [ "${Stack}" = "lnmpa" ]; then
        \cp ${cur_dir}/src/patch/mod_remoteip.c .
        /fix-data/bin/apache/bin/apxs -i -c -n mod_remoteip.so mod_remoteip.c
        sed -i 's/#LoadModule/LoadModule/g' /fix-data/bin/apache/conf/extra/mod_remoteip.conf
    fi

    ln -sf /fix-data/bin/lib/libltdl.so.3 /usr/lib/libltdl.so.3
    mkdir /fix-data/bin/apache/conf/vhost

    if [ "${Default_Website_Dir}" != "/fix-data/app/default" ]; then
        sed -i "s#/fix-data/app/default#${Default_Website_Dir}#g" /fix-data/bin/apache/conf/httpd.conf
        sed -i "s#/fix-data/app/default#${Default_Website_Dir}#g" /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
    fi

    if [[ "${PHPSelect}" =~ ^[6789]|10$ ]]; then
        sed -i '/^LoadModule php5_module/d' /fix-data/bin/apache/conf/httpd.conf
    fi

    \cp ${cur_dir}/init.d/init.d.httpd /etc/init.d/httpd
    \cp ${cur_dir}/init.d/httpd.service /etc/systemd/system/httpd.service
    chmod +x /etc/init.d/httpd
}

Install_Apache_24()
{
    Echo_Blue "[+] Installing ${Apache_Ver}..."
    if [ "${Stack}" = "lamp" ]; then
        groupadd app
        useradd -s /sbin/nologin -g app app
        mkdir -p ${Default_Website_Dir}
        chmod +w ${Default_Website_Dir}
        mkdir -p /dynamic-data/log/apache
        chmod 777 /dynamic-data/log/apache
        chown -R app:app ${Default_Website_Dir}
        Install_Openssl_New
        Install_Nghttp2
    fi
    Tarj_Cd ${Apache_Ver}.tar.bz2 ${Apache_Ver}
    cd srclib
    if [ -s "${cur_dir}/src/${APR_Ver}.tar.bz2" ]; then
        echo "${APR_Ver}.tar.bz2 [found]"
        cp ${cur_dir}/src/${APR_Ver}.tar.bz2 .
    else
        Download_Files ${Download_Mirror}/web/apache/${APR_Ver}.tar.bz2 ${APR_Ver}.tar.bz2
    fi
    if [ -s "${cur_dir}/src/${APR_Util_Ver}.tar.bz2" ]; then
        echo "${APR_Util_Ver}.tar.bz2 [found]"
        cp ${cur_dir}/src/${APR_Util_Ver}.tar.bz2 .
    else
        Download_Files ${Download_Mirror}/web/apache/${APR_Util_Ver}.tar.bz2 ${APR_Util_Ver}.tar.bz2
    fi
    tar jxf ${APR_Ver}.tar.bz2
    tar jxf ${APR_Util_Ver}.tar.bz2
    mv ${APR_Ver} apr
    mv ${APR_Util_Ver} apr-util
    cd ..
    if [ "${Stack}" = "lamp" ]; then
        ./configure --prefix=/fix-data/bin/apache --enable-mods-shared=most --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --enable-ssl ${apache_with_ssl} --enable-deflate --with-pcre --with-included-apr --with-apr-util --enable-mpms-shared=all --enable-remoteip --enable-http2 --with-nghttp2=/fix-data/bin/nghttp2
    else
        ./configure --prefix=/fix-data/bin/apache --enable-mods-shared=most --enable-headers --enable-mime-magic --enable-proxy --enable-so --enable-rewrite --enable-ssl --with-ssl --enable-deflate --with-pcre --with-included-apr --with-apr-util --enable-mpms-shared=all --enable-remoteip
    fi
    Make_Install
    cd ${cur_dir}/src
    rm -rf ${cur_dir}/src/${Apache_Ver}

    mv /fix-data/bin/apache/conf/httpd.conf /fix-data/bin/apache/conf/httpd.conf.bak
    if [ "${Stack}" = "lamp" ]; then
        \cp ${cur_dir}/conf/httpd24-lamp.conf /fix-data/bin/apache/conf/httpd.conf
        \cp ${cur_dir}/conf/httpd-vhosts-lamp.conf /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
        \cp ${cur_dir}/conf/httpd24-ssl.conf /fix-data/bin/apache/conf/extra/httpd-ssl.conf
        \cp ${cur_dir}/conf/example/enable-apache-ssl-vhost-example.conf /fix-data/bin/apache/conf/enable-apache-ssl-vhost-example.conf
    elif [ "${Stack}" = "lnmpa" ]; then
        \cp ${cur_dir}/conf/httpd24-lnmpa.conf /fix-data/bin/apache/conf/httpd.conf
        \cp ${cur_dir}/conf/httpd-vhosts-lnmpa.conf /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
    fi
    \cp ${cur_dir}/conf/httpd-default.conf /fix-data/bin/apache/conf/extra/httpd-default.conf
    \cp ${cur_dir}/conf/mod_remoteip.conf /fix-data/bin/apache/conf/extra/mod_remoteip.conf
    mkdir /fix-data/bin/apache/conf/vhost

    sed -i 's/NameVirtualHost .*//g' /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
    if [ "${Default_Website_Dir}" != "/fix-data/app/default" ]; then
        sed -i "s#/fix-data/app/default#${Default_Website_Dir}#g" /fix-data/bin/apache/conf/httpd.conf
        sed -i "s#/fix-data/app/default#${Default_Website_Dir}#g" /fix-data/bin/apache/conf/extra/httpd-vhosts.conf
    fi

    if [[ "${PHPSelect}" =~ ^[6789]|10$ ]]; then
        sed -i '/^LoadModule php5_module/d' /fix-data/bin/apache/conf/httpd.conf
    fi

    \cp ${cur_dir}/init.d/init.d.httpd /etc/init.d/httpd
    \cp ${cur_dir}/init.d/httpd.service /etc/systemd/system/httpd.service
    chmod +x /etc/init.d/httpd
}
