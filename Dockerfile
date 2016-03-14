FROM debian:jessie

ENV nginx_version 
ENV openssl_version 
ENV zlib_version 
ENV pcre_version 
ENV geoip_version 

RUN apt-get update \
        && apt-get install -y wget git build-essential curl \
        libxml2-dev libxslt-dev libgd-dev libtool autoconf \
	&& rm -rf /var/lib/apt/lists/*

RUN cd /usr/local/src && wget http://nginx.org/download/nginx-$nginx_version.tar.gz \
        && wget http://www.openssl.org/source/openssl-$openssl_version.tar.gz \
        && wget http://zlib.net/zlib-$zlib_version.tar.gz \
        && wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$pcre_version.tar.gz \
        && tar -zxf nginx-$nginx_version.tar.gz \
        && tar -zxf openssl-$openssl_version.tar.gz \
        && tar -zxf zlib-$zlib_version.tar.gz \
        && tar -zxf pcre-$pcre_version.tar.gz \
        && git clone https://github.com/maxmind/geoip-api-c -b v$geoip_version --depth=1 \
        && git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git --depth=1 \
        && rm *.tar.gz

RUN cd /usr/local/src/pcre-$pcre_version \
        && ./configure && make && make install
RUN cd /usr/local/src/geoip-api-c \
        && ./bootstrap \
        && ./configure && make && make install \
        && echo '/usr/local/lib' > /etc/ld.so.conf.d/geoip.conf

RUN cd /usr/local/src/nginx-$nginx_version \
        && ./configure --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat \ 
           -Werror=format-security -D_FORTIFY_SOURCE=2' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro' \
           --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --http-log-path=/var/log/nginx/access.log \
           --error-log-path=/var/log/nginx/error.log --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid \
           --http-client-body-temp-path=/var/lib/nginx/body --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
           --http-proxy-temp-path=/var/lib/nginx/proxy --http-scgi-temp-path=/var/lib/nginx/scgi \
           --http-uwsgi-temp-path=/var/lib/nginx/uwsgi --with-debug --with-pcre-jit --with-ipv6 --with-http_ssl_module \
           --with-http_stub_status_module --with-http_realip_module --with-http_addition_module --with-http_dav_module \
           --with-http_geoip_module --with-http_gzip_static_module --with-http_image_filter_module --with-http_sub_module \
           --with-http_xslt_module --with-mail --with-mail_ssl_module \
           --add-module=/usr/local/src/ngx_http_substitutions_filter_module --with-openssl=/usr/local/src/openssl-$openssl_version \
           --with-zlib=/usr/local/src/zlib-$zlib_version --with-stream --with-stream_ssl_module \
           --with-http_ssl_module --with-http_v2_module --with-threads \
        && make install 

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log 

RUN mkdir /var/lib/nginx 

ENV LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib 

EXPOSE 80 443

CMD ["/usr/share/nginx/sbin/nginx", "-g", "daemon off;"]
