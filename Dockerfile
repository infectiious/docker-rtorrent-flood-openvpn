FROM alpine:3.13

ARG RTORRENT_VER=0.9.8
ARG LIBTORRENT_VER=0.13.8
ARG MEDIAINFO_VER=20.09
ARG FLOOD_VER=4.4.1
ARG BUILD_CORES

VOLUME /data
VOLUME /config

ENV UID=991 GID=991 \
    FLOOD_SECRET=supersecret30charactersminimum \
    WEBROOT=/ \
    DISABLE_AUTH=false \
    RTORRENT_SOCK=true \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

RUN NB_CORES=${BUILD_CORES-`getconf _NPROCESSORS_CONF`} \
 && apk -U upgrade \
 echo "@community http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
 && apk --no-cache add bash \
    dumb-init \
    ip6tables \
    ufw@community \
    openvpn \
    shadow \
    curl \
    jq \
    tzdata \
    openrc \
    tinyproxy \
    tinyproxy-openrc \
    openssh \
    unrar \
    git \
    ca-certificates \
    curl \
    ncurses \
    openssl \
    gzip \
    zip \
    zlib \
    s6 \
    su-exec \
    python2 \
    nodejs \
    nodejs-npm \
    unrar \
    findutils \
 && apk add --no-cache -t \
    build-dependencies \
    build-base \
    git \
    libtool \
    automake \
    autoconf \
    wget \
    tar \
    xz \
    zlib-dev \
    cppunit-dev \
    openssl-dev \
    ncurses-dev \
    curl-dev \
    binutils \
    linux-headers \
 && cd /tmp && mkdir libtorrent rtorrent \
 && cd libtorrent && wget -qO- https://github.com/rakshasa/libtorrent/archive/v${LIBTORRENT_VER}.tar.gz | tar xz --strip 1 \
 && cd ../rtorrent && wget -qO- https://github.com/rakshasa/rtorrent/releases/download/v${RTORRENT_VER}/rtorrent-${RTORRENT_VER}.tar.gz | tar xz --strip 1 \
 && cd /tmp \
 && git clone https://github.com/mirror/xmlrpc-c.git \
 && cd /tmp/xmlrpc-c/advanced && ./configure && make -j ${NB_CORES} && make install \
 && cd /tmp/libtorrent && ./autogen.sh && ./configure && make -j ${NB_CORES} && make install \
 && cd /tmp/rtorrent && ./autogen.sh && ./configure --with-xmlrpc-c && make -j ${NB_CORES} && make install \
 && cd /tmp \
 && wget -q http://mediaarea.net/download/binary/mediainfo/${MEDIAINFO_VER}/MediaInfo_CLI_${MEDIAINFO_VER}_GNU_FromSource.tar.gz \
 && wget -q http://mediaarea.net/download/binary/libmediainfo0/${MEDIAINFO_VER}/MediaInfo_DLL_${MEDIAINFO_VER}_GNU_FromSource.tar.gz \
 && tar xzf MediaInfo_DLL_${MEDIAINFO_VER}_GNU_FromSource.tar.gz \
 && tar xzf MediaInfo_CLI_${MEDIAINFO_VER}_GNU_FromSource.tar.gz \
 && cd /tmp/MediaInfo_DLL_GNU_FromSource && ./SO_Compile.sh \
 && cd /tmp/MediaInfo_DLL_GNU_FromSource/ZenLib/Project/GNU/Library && make install \
 && cd /tmp/MediaInfo_DLL_GNU_FromSource/MediaInfoLib/Project/GNU/Library && make install \
 && cd /tmp/MediaInfo_CLI_GNU_FromSource && ./CLI_Compile.sh \
 && cd /tmp/MediaInfo_CLI_GNU_FromSource/MediaInfo/Project/GNU/CLI && make install \
 && strip -s /usr/local/bin/rtorrent \
 && strip -s /usr/local/bin/mediainfo \
 && ln -sf /usr/local/bin/mediainfo /usr/bin/mediainfo \
 && mkdir /usr/flood && cd /usr/flood && wget -qO- https://github.com/jesec/flood/archive/v${FLOOD_VER}.tar.gz | tar xz --strip 1 \
 && npm install && npm cache clean --force \
 && apk del build-dependencies \
 && rm -rf /var/cache/apk/* /tmp/* \
 && rm -rf /tmp/* /var/tmp/* \
 && groupmod -g 1000 users \
 && useradd -u 911 -U -d /config -s /bin/false abc \
 && usermod -G users abc

# Add configuration and scripts

ADD openvpn/ /etc/openvpn/
ADD tinyproxy /opt/tinyproxy/
ADD scripts /etc/scripts/

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    GLOBAL_APPLY_PERMISSIONS=true \
    TRANSMISSION_HOME=/data/transmission-home \
    TRANSMISSION_RPC_PORT=9091 \
    TRANSMISSION_DOWNLOAD_DIR=/data/completed \
    TRANSMISSION_INCOMPLETE_DIR=/data/incomplete \
    TRANSMISSION_WATCH_DIR=/data/watch \
    CREATE_TUN_DEVICE=true \
    ENABLE_UFW=false \
    UFW_ALLOW_GW_NET=false \
    UFW_EXTRA_PORTS= \
    UFW_DISABLE_IPTABLES_REJECT=false \
    PUID= \
    PGID= \
    DROP_DEFAULT_ROUTE= \
    WEBPROXY_ENABLED=false \
    WEBPROXY_PORT=8888 \
    WEBPROXY_USERNAME= \
    WEBPROXY_PASSWORD= \
    LOG_TO_STDOUT=false \
    HEALTH_CHECK_HOST=google.com

# HEALTHCHECK --interval=1m CMD /etc/scripts/healthcheck.sh

# Add labels to identify this image and version
ARG REVISION
# Set env from build argument or default to empty string
ENV REVISION=${REVISION:-""}
LABEL org.opencontainers.image.source=https://github.com/haugene/docker-transmission-openvpn
LABEL org.opencontainers.image.revision=$REVISION
LABEL description="BitTorrent client with WebUI front-end" \
      rtorrent="rTorrent BiTorrent client v$RTORRENT_VER" \
      libtorrent="libtorrent v$LIBTORRENT_VER" \
      maintainer="Testing"

# Compatability with https://hub.docker.com/r/willfarrell/autoheal/
LABEL autoheal=true

COPY rootfs /

RUN chmod +x /usr/local/bin/* /etc/s6.d/*/* /etc/s6.d/.s6-svscan/* \
 && cd /usr/flood/ && npm run build

VOLUME /data /flood-db

# Expose port and run
EXPOSE 3000 49184 49184/udp
CMD ["dumb-init", "/etc/openvpn/start.sh"]
