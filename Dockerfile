FROM php:7.3.11-fpm-alpine
WORKDIR /src

# Update APK repos
RUN apk update

# Set www-data to UID 500
RUN apk --no-cache add shadow && usermod -u 500 www-data

RUN apk add gnu-libiconv --update-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted
ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

# Install dependencies
RUN apk --no-cache add \
        openssl-dev \
        git \
        libmcrypt-dev \
        openssh-client \
        icu-dev \
        libxml2-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        supervisor \
        autoconf \
        wget \
        libzip-dev \
        dpkg-dev \
        dpkg \
        file \
        imap-dev \
        wkhtmltopdf \
        g++ \
        gcc \
        libc-dev \
        make \
        pkgconf \
        re2c \
        alpine-sdk \
        zip \
        poppler-utils \
        msttcorefonts-installer \
        fontconfig

# Add SSH config
RUN echo "IdentityFile ~/.ssh/id_rsa" >> /etc/ssh/ssh_config \
    && mkdir /root/.ssh/ \
    && chmod 700 /root/.ssh \
    && echo "git.loan.co.uk,172.31.47.106 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBDBGNszu9a8hxedoxRzs2/l8zSgS1swuf5xC1ioMEo8uVTphGrimEAWjFncqlsHvIMAP/XbzwUj7hKnapub15Vc=" > ~/.ssh/known_hosts \
    && echo "git.onthemoney.net,63.34.88.63 ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHShhT6qoVZOniwJoao+1hz/GrLwoIv2D3BLKiQ4CyAwGz8pi8XNsy7qgmJOibaLcRUIB934t9QxVYGgdrgZWoM=" >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts

# Enable PECL modules
RUN pecl install apcu_bc mailparse

# Install PHP extensions
RUN docker-php-ext-configure imap --with-imap-ssl \
    && docker-php-ext-install \
        opcache \
        bcmath \
        mysqli \
        pcntl \
        iconv \
        pdo \
        pdo_mysql \
        zip \
        intl \
        opcache \
        mbstring \
        xml \
        gd \
        soap \
        imap \
    && docker-php-ext-enable \
        opcache \
        apcu \
        opcache \
        mailparse

#Restarts PHP_FPM
RUN kill -USR2 1

# Delete junk
RUN apk del build-base linux-headers pcre-dev openssl-dev \
    && rm -rf /var/cache/apk/*

# Setup php configs
RUN echo "date.timezone=Europe/London" >  /usr/local/etc/php/conf.d/system.ini \
    && echo 'log_errors_max_len = 9223372036854775807' >> /usr/local/etc/php/conf.d/system.ini \
    && echo "memory_limit = 512M;" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "upload_max_filesize=50M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size=50M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.memory_consumption=512" >>/usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.interned_strings_buffer=64" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.max_accelerated_files=32531" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.validate_timestamps=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.revalidate_freq=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.save_comments=1" >> /usr/local/etc/php/conf.d/opcache.ini \
    && echo "opcache.fast_shutdown=0" >> /usr/local/etc/php/conf.d/opcache.ini \
    && sed -i 's/127.0.0.1:9000/0.0.0.0:9000/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/pm.max_children = 5/pm.max_children = 50/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/pm.start_servers = 2/pm.start_servers = 8/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/pm.min_spare_servers = 1/pm.min_spare_servers = 5/g' /usr/local/etc/php-fpm.d/www.conf \
    && sed -i 's/pm.max_spare_servers = 3/pm.max_spare_servers = 10/g' /usr/local/etc/php-fpm.d/www.conf \
    && echo 'security.limit_extensions = .php .js' >>  /usr/local/etc/php-fpm.d/www.conf \
    && echo '[global]' > /usr/local/etc/php-fpm.d/docker.conf \
    && echo 'error_log = /proc/self/fd/2' >> /usr/local/etc/php-fpm.d/docker.conf \
    && echo '[www]' >> /usr/local/etc/php-fpm.d/docker.conf \
    && echo 'access.log = /proc/self/fd/2' >> /usr/local/etc/php-fpm.d/docker.conf \
    && echo 'clear_env = no' >> /usr/local/etc/php-fpm.d/docker.conf \
    && echo 'catch_workers_output = yes' >> /usr/local/etc/php-fpm.d/docker.conf \
    && echo 'decorate_workers_output = no' >> /usr/local/etc/php-fpm.d/docker.conf

# Setup Composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/bin/ --filename=composer \ 
    && chmod +x /bin/composer \
    && composer global require hirak/prestissimo \
    && rm -rf composer-setup.php

# Setup pcov
RUN pecl install pcov && docker-php-ext-enable pcov
