FROM debian:bookworm-slim AS builder
WORKDIR /opt/openresty
RUN apt update && apt -y install sudo cmake wget perl gnupg curl make build-essential git lsb-release
RUN apt install -y --no-install-recommends --no-install-suggests dh-make bzr-builddeb debhelper systemtap-sdt-dev libtemplate-perl
RUN git clone https://github.com/ZanyRain/openresty-packaging.git && mkdir dist
RUN cd openresty-packaging/deb/ && make zlib-build
RUN cd openresty-packaging/deb/ && apt install ./*.deb && mv ./*.deb /opt/openresty/dist/
RUN cd openresty-packaging/deb/ && make pcre-build
RUN cd openresty-packaging/deb/ && apt install ./*.deb && mv ./*.deb /opt/openresty/dist/
RUN cd openresty-packaging/deb/ && make openssl-build
RUN cd openresty-packaging/deb/ && apt install ./*.deb && mv ./*.deb /opt/openresty/dist/
RUN cd openresty-packaging/deb/ && make openresty-build
RUN cd openresty-packaging/deb/ && apt install ./*.deb && mv ./*.deb /opt/openresty/dist/

FROM debian:bookworm-slim
COPY --from=builder /opt/openresty/dist /tmp/dist
RUN DEBIAN_FRONTEND=noninteractive apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        wget \
    && cd /tmp/dist/ && DEBIAN_FRONTEND=noninteractive apt install -y ./openresty-zlib_*.deb ./openresty-zlib-dev_*.deb ./openresty-pcre_*.deb ./openresty-pcre-dev_*.deb ./openresty-openssl_*.deb ./openresty-openssl-dev_*.deb ./openresty_*.deb ./openresty-opm_*.deb ./openresty-resty*.deb && rm -rf /tmp/dist \
    && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && mkdir -p /var/run/openresty \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log \
    && mkdir -p /usr/local/openresty/nginx/conf/ \
    && mkdir -p /etc/nginx/conf.d/ \
    && mkdir -p /etc/nginx/sites-enabled/ \
    && mkdir -p /etc/nginx/ssl/ \
    && mkdir -p /etc/nginx/common/

COPY conf/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY conf/general.conf /etc/nginx/common/general.conf
COPY conf/proxy.conf /etc/nginx/common/proxy.conf
COPY conf/security.conf /etc/nginx/common/security.conf
# Add additional binaries into PATH for convenience
ENV PATH="$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin"
CMD ["/usr/bin/openresty", "-g", "daemon off;"]

# Use SIGQUIT instead of default SIGTERM to cleanly drain requests
# See https://github.com/openresty/docker-openresty/blob/master/README.md#tips--pitfalls
STOPSIGNAL SIGQUIT

