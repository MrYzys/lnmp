#!/usr/bin/env bash

Upgrade_Nginx()
{
    Cur_Nginx_Version=`/fix-data/bin/nginx/sbin/nginx -v 2>&1 | cut -c22-`

    if [ -s /fix-data/bin/include/jemalloc/jemalloc.h ] && /fix-data/bin/nginx/sbin/nginx -V 2>&1|grep -Eqi 'ljemalloc'; then
        NginxMAOpt="--with-ld-opt='-ljemalloc'"
    elif [ -s /fix-data/bin/include/gperftools/tcmalloc.h ] && grep -Eqi "google_perftools_profiles" /fix-data/bin/nginx/conf/nginx.conf; then
        NginxMAOpt='--with-google_perftools_module'
    else
        NginxMAOpt=""
    fi

    Nginx_Version=""
    echo "Current Nginx Version:${Cur_Nginx_Version}"
    echo "You can get version number from http://nginx.org/en/download.html"
    read -p "Please enter nginx version you want, (example: 1.18.0): " Nginx_Version
    if [ "${Nginx_Version}" = "" ]; then
        echo "Error: You must enter a nginx version!!"
        exit 1
    fi
    echo "+---------------------------------------------------------+"
    echo "|    You will upgrade nginx version to ${Nginx_Version}"
    echo "+---------------------------------------------------------+"

    Press_Start

    echo "============================check files=================================="
    cd ${cur_dir}/src
    if [ -s nginx-${Nginx_Version}.tar.gz ]; then
        echo "nginx-${Nginx_Version}.tar.gz [found]"
    else
        echo "Notice: nginx-${Nginx_Version}.tar.gz not found!!!download now......"
        wget -c --progress=bar:force http://nginx.org/download/nginx-${Nginx_Version}.tar.gz
        if [ $? -eq 0 ]; then
            echo "Download nginx-${Nginx_Version}.tar.gz successfully!"
        else
            echo "You enter Nginx Version was:"${Nginx_Version}
            Echo_Red "Error! You entered a wrong version number, please check!"
            sleep 5
            exit 1
        fi
    fi
    echo "============================check files=================================="

    Install_Nginx_Openssl
    Install_Nginx_Lua
    Install_Pcre
    Tar_Cd nginx-${Nginx_Version}.tar.gz nginx-${Nginx_Version}
    Get_Dist_Version
    if [[ "${DISTRO}" = "Fedora" && ${Fedora_Version} -ge 28 ]]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-libxcrypt.patch
    fi
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.14.2 ${Nginx_Version})
    if gcc -dumpversion|grep -q "^[8]" && [ "${Nginx_Ver_Com}" == "1" ]; then
        patch -p1 < ${cur_dir}/src/patch/nginx-gcc8.patch
    fi
    Nginx_Ver_Com=$(${cur_dir}/include/version_compare 1.9.4 ${Nginx_Version})
    if [[ "${Nginx_Ver_Com}" == "0" ||  "${Nginx_Ver_Com}" == "1" ]]; then
        ./configure --user=app --group=app --prefix=/fix-data/bin/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_spdy_module --with-http_gzip_static_module --with-ipv6 --with-http_sub_module ${Nginx_With_Openssl} ${Nginx_With_Pcre} ${Nginx_Module_Lua} ${NginxMAOpt} ${Nginx_Modules_Options}
    else
        ./configure --user=app --group=app --prefix=/fix-data/bin/nginx --with-http_stub_status_module --with-http_ssl_module --with-http_v2_module --with-http_gzip_static_module --with-http_sub_module --with-stream --with-stream_ssl_module ${Nginx_With_Openssl} ${Nginx_With_Pcre} ${Nginx_Module_Lua} ${NginxMAOpt} ${Nginx_Modules_Options}
    fi
    make -j `grep 'processor' /proc/cpuinfo | wc -l`
    if [ $? -ne 0 ]; then
        make
    fi

    mv /fix-data/bin/nginx/sbin/nginx /fix-data/bin/nginx/sbin/nginx.${Upgrade_Date}
    \cp objs/nginx /fix-data/bin/nginx/sbin/nginx
    echo "Test nginx configure file..."
    /fix-data/bin/nginx/sbin/nginx -t
    echo "upgrade..."
    make upgrade

    cd ${cur_dir} && rm -rf ${cur_dir}/src/nginx-${Nginx_Version}
    if [ "${Enable_Nginx_Lua}" = 'y' ]; then
        if ! grep -q "content_by_lua 'ngx.say(\"hello world\")';" /fix-data/bin/nginx/conf/nginx.conf; then
            sed -i "/location \/nginx_status/i\        location /lua\n        {\n            default_type text/html;\n            content_by_lua 'ngx.say\(\"hello world\"\)';\n        }\n" /fix-data/bin/nginx/conf/nginx.conf
        fi
    fi

    echo "Checking ..."
    if [[ -s /fix-data/bin/nginx/conf/nginx.conf && -s /fix-data/bin/nginx/sbin/nginx ]]; then
        echo "Program will display Nginx Version......"
        /fix-data/bin/nginx/sbin/nginx -v
        Echo_Green "======== upgrade nginx completed ======"
    else
        Echo_Red "Error: Nginx upgrade failed."
    fi
}
