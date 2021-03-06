#!/usr/bin/env bash

Export_PHP_Autoconf()
{
    if [[ -s /fix-data/bin/autoconf-2.13/bin/autoconf && -s /fix-data/bin/autoconf-2.13/bin/autoheader ]]; then
        Echo_Green "Autconf 2.13...ok"
    else
        Install_Autoconf
    fi
    export PHP_AUTOCONF=/fix-data/bin/autoconf-2.13/bin/autoconf
    export PHP_AUTOHEADER=/fix-data/bin/autoconf-2.13/bin/autoheader
}

Check_Curl()
{
    if [ -s /fix-data/bin/curl/bin/curl ]; then
        Echo_Green "Curl ...ok"
    else
        Install_Curl
    fi
}

PHP_with_curl()
{
    Get_ARM
    if [[ "${DISTRO}" = "CentOS" && "${Is_ARM}" = "y" ]] || [ "${UseOldOpenssl}" = "y" ];then
        Check_Curl
        with_curl='--with-curl=/fix-data/bin/curl'
    else
        with_curl='--with-curl'
    fi
}

PHP_with_openssl()
{
    if openssl version | grep -Eqi "OpenSSL 1.1.*"; then
        if ( [ "${PHPSelect}" != "" ] &&  echo "${PHPSelect}" | grep -Eqi "[1-5]" ) || ( [ "${php_version}" != "" ] && echo "${php_version}" | grep -Eqi '^5.' ) || echo "${Php_Ver}" | grep -Eqi "php-5."; then
            UseOldOpenssl='y'
        fi
    fi
    if echo "${PHPSelect}" | grep -Eqi "[1-2]" || echo "${php_version}" | grep -Eqi '^5.[2,3].*' || echo "${Php_Ver}" | grep -Eqi "php-5.[2,3].*"; then
        UseOldOpenssl='y'
    fi
    if [ "${UseOldOpenssl}" = "y" ]; then
            Install_Openssl
            with_openssl='--with-openssl=/fix-data/bin/openssl'
    else
        with_openssl='--with-openssl'
    fi
}

PHP_with_fileinfo()
{
    if [ "${Enable_PHP_Fileinfo}" = "n" ];then
        if [ `free -m | grep Mem | awk '{print  $2}'` -lt 1024 ]; then
            with_fileinfo='--disable-fileinfo'
        else
            with_fileinfo=''
        fi
    else
        with_fileinfo=''
    fi
}

Check_PHP_Option()
{
    PHP_with_openssl
    PHP_with_curl
    PHP_with_fileinfo
}

Ln_PHP_Bin()
{
    ln -sf /fix-data/bin/${Php_Ver}/bin/php /usr/bin/php
    ln -sf /fix-data/bin/${Php_Ver}/bin/phpize /usr/bin/phpize
    ln -sf /fix-data/bin/${Php_Ver}/bin/pear /usr/bin/pear
    ln -sf /fix-data/bin/${Php_Ver}/bin/pecl /usr/bin/pecl
    if [ "${Stack}" = "lnmp" ]; then
        ln -sf /fix-data/bin/${Php_Ver}/sbin/php-fpm /usr/bin/php-fpm
    fi
    rm -f /fix-data/bin/${Php_Ver}/conf.d/*
}

Pear_Pecl_Set()
{
    pear config-set php_ini /fix-data/bin/${Php_Ver}/etc/php.ini
    pecl config-set php_ini /fix-data/bin/${Php_Ver}/etc/php.ini
}

Install_Composer()
{
    echo "Downloading Composer..."
    wget --prefer-family=IPv4 --no-check-certificate -T 120 -t3 ${Download_Mirror}/web/php/composer/composer.phar -O /fix-data/bin/bin/composer
    if [ $? -eq 0 ]; then
        echo "Composer install successfully."
        chmod +x /fix-data/bin/bin/composer
    else
        echo "Composer install failed, try to from composer official website..."
        curl -sS --connect-timeout 30 -m 60 https://getcomposer.org/installer | php -- --install-dir=/fix-data/bin/bin --filename=composer
        if [ $? -eq 0 ]; then
            echo "Composer install successfully."
        fi
    fi
    if [ "${country}" = "CN" ]; then
        composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/
    fi
}

Install_PHP_52()
{
    Echo_Blue "[+] Installing ${Php_Ver}..."
    Check_Curl
    Export_PHP_Autoconf
    cd ${cur_dir}/src && rm -rf ${Php_Ver}
    tar jxf ${Php_Ver}.tar.bz2
    if [ "${Stack}" = "lnmp" ]; then
        gzip -cd ${Php_Ver}-fpm-0.5.14.diff.gz | patch -d ${Php_Ver} -p1
    fi
    cd ${Php_Ver}/
    patch -p1 < ${cur_dir}/src/patch/php-5.2.17-max-input-vars.patch
    patch -p0 < ${cur_dir}/src/patch/php-5.2.17-xml.patch
    patch -p1 < ${cur_dir}/src/patch/debian_patches_disable_SSLv2_for_openssl_1_0_0.patch
    patch -p1 < ${cur_dir}/src/patch/php-5.2-multipart-form-data.patch
    ./buildconf --force
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-mysql=${MySQL_Dir} --with-mysqli=${MySQL_Config} --with-pdo-mysql=${MySQL_Dir} --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --enable-discard-path --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-fastcgi --enable-fpm --enable-force-cgi-redirect --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --with-mime-magic ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysql=${MySQL_Dir} --with-mysqli=${MySQL_Config} --with-pdo-mysql=${MySQL_Dir} --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --enable-discard-path --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext --with-mime-magic ${PHP_Modules_Options}
    fi
    PHP_Make_Install

    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-dist /fix-data/bin/${Php_Ver}/etc/php.ini
    cd ../

    Ln_PHP_Bin

    # php extensions
    sed -i 's#extension_dir = "./"#extension_dir = "/fix-data/bin/${Php_Ver}/lib/php/extensions/no-debug-non-zts-20060613/"\n#' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's#output_buffering =.*#output_buffering = On#' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/; cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server,fsocket/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set

    cd ${cur_dir}/src
    if [ "${Is_64bit}" = "y" ] ; then
        Download_Files ${Download_Mirror}/web/zend/ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz
        tar zxf ZendOptimizer-3.3.9-linux-glibc23-x86_64.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp ZendOptimizer-3.3.9-linux-glibc23-x86_64/data/5_2_x_comp/ZendOptimizer.so /fix-data/bin/zend/
    else
        Download_Files ${Download_Mirror}/web/zend/ZendOptimizer-3.3.9-linux-glibc23-i386.tar.gz
        tar zxf ZendOptimizer-3.3.9-linux-glibc23-i386.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp ZendOptimizer-3.3.9-linux-glibc23-i386/data/5_2_x_comp/ZendOptimizer.so /fix-data/bin/zend/
    fi

    if [ "${Is_ARM}" != "y" ]; then
        cat >/fix-data/bin/${Php_Ver}/conf.d/002-zendoptimizer.ini<<EOF
[Zend Optimizer]
zend_optimizer.optimization_level=1
zend_extension="/fix-data/bin/zend/ZendOptimizer.so"
EOF
    fi

    if [ "${Stack}" = "lnmp" ]; then
        rm -f /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        \cp ${cur_dir}/conf/php-fpm5.2.conf /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        \cp ${cur_dir}/init.d/init.d.php-fpm5.2 /etc/init.d/php-fpm
        chmod +x /etc/init.d/php-fpm
    fi
}

Install_PHP_53()
{
    Echo_Blue "[+] Installing ${Php_Ver}..."
    Check_Curl
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    patch -p1 < ${cur_dir}/src/patch/php-5.3-multipart-form-data.patch
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-magic-quotes --enable-safe-mode --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/register_long_arrays =.*/;register_long_arrays = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/magic_quotes_gpc =.*/;magic_quotes_gpc = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 5.3..."
    cd ${cur_dir}/src
    if [ "${Is_64bit}" = "y" ] ; then
        Download_Files ${Download_Mirror}/web/zend/ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz
        tar zxf ZendGuardLoader-php-5.3-linux-glibc23-x86_64.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp ZendGuardLoader-php-5.3-linux-glibc23-x86_64/php-5.3.x/ZendGuardLoader.so /fix-data/bin/zend/
    else
        Download_Files ${Download_Mirror}/web/zend/ZendGuardLoader-php-5.3-linux-glibc23-i386.tar.gz
        tar zxf ZendGuardLoader-php-5.3-linux-glibc23-i386.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp ZendGuardLoader-php-5.3-linux-glibc23-i386/php-5.3.x/ZendGuardLoader.so /fix-data/bin/zend/
    fi

    if [ "${Is_ARM}" != "y" ]; then
        echo "Write ZendGuardLoader to php.ini..."
        cat >/fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini<<EOF
[Zend ZendGuard Loader]
zend_extension=/fix-data/bin/zend/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=
EOF

        if grep -q '^LoadModule mpm_event_module' /fix-data/bin/apache/conf/httpd.conf && [ "${ApacheSelect}" = "2" ]; then
            mv /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini.disable
        fi
    fi

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

Install_PHP_54()
{
    Echo_Blue "[+] Installing ${Php_Ver}..."
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-intl --with-xsl ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-intl --with-xsl ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 5.4..."
    cd ${cur_dir}/src
    if [ "${Is_64bit}" = "y" ] ; then
        Download_Files ${Download_Mirror}/web/zend/ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64.tar.gz
        tar zxf ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp ZendGuardLoader-70429-PHP-5.4-linux-glibc23-x86_64/php-5.4.x/ZendGuardLoader.so /fix-data/bin/zend/
    else
        Download_Files ${Download_Mirror}/web/zend/ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386.tar.gz
        tar zxf ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp ZendGuardLoader-70429-PHP-5.4-linux-glibc23-i386/php-5.4.x/ZendGuardLoader.so /fix-data/bin/zend/
    fi

    if [ "${Is_ARM}" != "y" ]; then
        echo "Write ZendGuardLoader to php.ini..."
        cat >/fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini<<EOF
[Zend ZendGuard Loader]
zend_extension=/fix-data/bin/zend/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=
EOF

        if grep -q '^LoadModule mpm_event_module' /fix-data/bin/apache/conf/httpd.conf && [ "${ApacheSelect}" = "2" ]; then
            mv /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini.disable
        fi
    fi

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
    chmod +x /etc/systemd/system/php-fpm.service
fi
}

Install_PHP_55()
{
    Echo_Blue "[+] Installing ${Php_Ver}..."
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Modules_Options}
    else
       ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini..."
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 5.5..."
    cd ${cur_dir}/src
    if [ "${Is_64bit}" = "y" ] ; then
        Download_Files ${Download_Mirror}/web/zend/zend-loader-php5.5-linux-x86_64.tar.gz
        tar zxf zend-loader-php5.5-linux-x86_64.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp zend-loader-php5.5-linux-x86_64/ZendGuardLoader.so /fix-data/bin/zend/
    else
        Download_Files ${Download_Mirror}/web/zend/zend-loader-php5.5-linux-i386.tar.gz
        tar zxf zend-loader-php5.5-linux-i386.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp zend-loader-php5.5-linux-i386/ZendGuardLoader.so /fix-data/bin/zend/
    fi

    if [ "${Is_ARM}" != "y" ]; then
        echo "Write ZendGuardLoader to php.ini..."
        cat >/fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini<<EOF
[Zend ZendGuard Loader]
zend_extension=/fix-data/bin/zend/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=
EOF

        if grep -q '^LoadModule mpm_event_module' /fix-data/bin/apache/conf/httpd.conf && [ "${ApacheSelect}" = "2" ]; then
            mv /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini.disable
        fi
    fi

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
    chmod +x /etc/systemd/system/php-fpm.service
fi
}

Install_PHP_56()
{
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --enable-intl --with-xsl ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 5.6..."
    cd ${cur_dir}/src
    if [ "${Is_64bit}" = "y" ] ; then
        Download_Files ${Download_Mirror}/web/zend/zend-loader-php5.6-linux-x86_64.tar.gz
        tar zxf zend-loader-php5.6-linux-x86_64.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp zend-loader-php5.6-linux-x86_64/ZendGuardLoader.so /fix-data/bin/zend/
    else
        Download_Files ${Download_Mirror}/web/zend/zend-loader-php5.6-linux-i386.tar.gz
        tar zxf zend-loader-php5.6-linux-i386.tar.gz
        mkdir -p /fix-data/bin/zend/
        \cp zend-loader-php5.6-linux-i386/ZendGuardLoader.so /fix-data/bin/zend/
    fi

    if [ "${Is_ARM}" != "y" ]; then
        echo "Write ZendGuardLoader to php.ini..."
        cat >/fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini<<EOF
[Zend ZendGuard Loader]
zend_extension=/fix-data/bin/zend/ZendGuardLoader.so
zend_loader.enable=1
zend_loader.disable_licensing=0
zend_loader.obfuscation_level_support=3
zend_loader.license_path=
EOF

        if grep -q '^LoadModule mpm_event_module' /fix-data/bin/apache/conf/httpd.conf && [ "${ApacheSelect}" = "2" ]; then
            mv /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini /fix-data/bin/${Php_Ver}/conf.d/002-zendguardloader.ini.disable
        fi
    fi

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

Install_PHP_7()
{
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 7.0..."
    echo "unavailable now."

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

Install_PHP_71()
{
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --with-mcrypt --enable-ftp --with-gd --enable-gd-native-ttf ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 7.1..."
    echo "unavailable now."

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

Install_PHP_72()
{
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 7.2..."
    echo "unavailable now."

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

Install_PHP_73()
{
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype-dir=/fix-data/bin/freetype --with-jpeg-dir --with-png-dir --with-zlib --with-libxml-dir=/usr --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --with-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --enable-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 7.3..."
    echo "unavailable now."

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

Install_PHP_74()
{
    Install_Libzip
    Echo_Blue "[+] Installing ${Php_Ver}"
    Tarj_Cd ${Php_Ver}.tar.bz2 ${Php_Ver}
    if [ "${Stack}" = "lnmp" ]; then
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --enable-fpm --with-fpm-user=app --with-fpm-group=app --enable-mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype=/fix-data/bin/freetype --with-jpeg --with-png --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --with-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Modules_Options}
    else
        ./configure --prefix=/fix-data/bin/${Php_Ver} --with-config-file-path=/fix-data/bin/${Php_Ver}/etc --with-config-file-scan-dir=/fix-data/bin/${Php_Ver}/conf.d --with-apxs2=/fix-data/bin/apache/bin/apxs --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd --with-iconv-dir --with-freetype=/fix-data/bin/freetype --with-jpeg --with-png --with-zlib --enable-xml --disable-rpath --enable-bcmath --enable-shmop --enable-sysvsem --enable-inline-optimization ${with_curl} --enable-mbregex --enable-mbstring --enable-intl --enable-pcntl --enable-ftp --enable-gd ${with_openssl} --with-mhash --enable-pcntl --enable-sockets --with-xmlrpc --with-zip --without-libzip --enable-soap --with-gettext ${with_fileinfo} --enable-opcache --with-xsl --with-pear ${PHP_Modules_Options}
    fi

    PHP_Make_Install

    Ln_PHP_Bin

    echo "Copy new php configure file..."
    mkdir -p /fix-data/bin/${Php_Ver}/{etc,conf.d}
    \cp php.ini-production /fix-data/bin/${Php_Ver}/etc/php.ini

    cd ${cur_dir}
    # php extensions
    echo "Modify php.ini......"
    sed -i 's/post_max_size =.*/post_max_size = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/upload_max_filesize =.*/upload_max_filesize = 50M/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;date.timezone =.*/date.timezone = PRC/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/short_open_tag =.*/short_open_tag = On/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/max_execution_time =.*/max_execution_time = 300/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    sed -i 's/disable_functions =.*/disable_functions = passthru,exec,system,chroot,chgrp,chown,shell_exec,proc_open,proc_get_status,popen,ini_alter,ini_restore,dl,openlog,syslog,readlink,symlink,popepassthru,stream_socket_server/g' /fix-data/bin/${Php_Ver}/etc/php.ini
    Pear_Pecl_Set
    Install_Composer

    echo "Install ZendGuardLoader for PHP 7.4..."
    echo "unavailable now."

if [ "${Stack}" = "lnmp" ]; then
    echo "Creating new php-fpm configure file..."
    cp ${cur_dir}/conf/php/php-fpm.conf /fixdata/bin/${Php_Ver}/etc/php-fpm.conf

    echo "Copy php-fpm init.d file..."
    \cp ${cur_dir}/src/${Php_Ver}/sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    \cp ${cur_dir}/init.d/php-fpm.service /etc/systemd/system/php-fpm.service
    chmod +x /etc/init.d/php-fpm
fi
}

LNMP_PHP_Opt()
{
    if [[ ${MemTotal} -gt 1024 && ${MemTotal} -le 2048 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 20#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 10#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 10#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 20#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
    elif [[ ${MemTotal} -gt 2048 && ${MemTotal} -le 4096 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 40#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 20#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 20#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 40#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
    elif [[ ${MemTotal} -gt 4096 && ${MemTotal} -le 8192 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 60#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 30#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 30#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 60#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
    elif [[ ${MemTotal} -gt 8192 ]]; then
        sed -i "s#pm.max_children.*#pm.max_children = 80#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.start_servers.*#pm.start_servers = 40#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.min_spare_servers.*#pm.min_spare_servers = 40#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
        sed -i "s#pm.max_spare_servers.*#pm.max_spare_servers = 80#" /fix-data/bin/${Php_Ver}/etc/php-fpm.conf
    fi
}

Creat_PHP_Tools()
{
    echo "Create PHP Info Tool..."
    cat >${Default_Website_Dir}/phpinfo.php<<eof
<?php
phpinfo();
?>
eof

    echo "Copy PHP Prober..."
    cd ${cur_dir}/src
    tar zxf p.tar.gz
    \cp p.php ${Default_Website_Dir}/p.php

    \cp ${cur_dir}/conf/index.html ${Default_Website_Dir}/index.html
    \cp ${cur_dir}/conf/lnmp.gif ${Default_Website_Dir}/lnmp.gif

    if [ ${PHPSelect} -ge 4 ]; then
        echo "Copy Opcache Control Panel..."
        \cp ${cur_dir}/conf/ocp.php ${Default_Website_Dir}/ocp.php
    fi
    echo "============================Install PHPMyAdmin================================="
    [[ -d ${Default_Website_Dir}/phpmyadmin ]] && rm -rf ${Default_Website_Dir}/phpmyadmin
    tar Jxf ${PhpMyAdmin_Ver}.tar.xz
    mv ${PhpMyAdmin_Ver} ${Default_Website_Dir}/phpmyadmin
    \cp ${cur_dir}/conf/config.inc.php ${Default_Website_Dir}/phpmyadmin/config.inc.php
    sed -i 's/LNMPORG/LNMP.org_0'$RANDOM`date '+%s'`$RANDOM'9_VPSer.net/g' ${Default_Website_Dir}/phpmyadmin/config.inc.php
    mkdir ${Default_Website_Dir}/phpmyadmin/{upload,save}
    chmod 755 -R ${Default_Website_Dir}/phpmyadmin/
    chown app:app -R ${Default_Website_Dir}/phpmyadmin/
    echo "============================phpMyAdmin install completed======================="
}
