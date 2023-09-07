ARG BASE_IMAGE="scottyhardy/docker-remote-desktop"
ARG TAG="latest"
FROM ${BASE_IMAGE}:${TAG}

ARG DEBIAN_FRONTEND=noninteractive
ENV \
  LANG='C.UTF-8' \
  LC_ALL='C.UTF-8' \
  TZ=Asia/Shanghai \
  WINEDEBUG=-all
  
# Install prerequisites
RUN apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        cabextract \
        git \
        gnupg \
        gosu \
        gpg-agent \
        locales \
        p7zip \
        pulseaudio \
        pulseaudio-utils \
        sudo \
        tzdata \
        unzip \
        wget \
        winbind \
        xvfb \
        zenity \
        ttf-wqy-microhei \
        ttf-wqy-zenhei \
        xfonts-wqy \
        curl \
        gnupg2 \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -fr /tmp/*
    
RUN groupadd group \
  && useradd -m -g group user \
  && usermod -a -G audio user \
  && usermod -a -G video user \
  && chsh -s /bin/bash user \
  && echo 'User Created'
  
# Install wine
ARG WINE_BRANCH="stable"
RUN wget -nv -O- https://dl.winehq.org/wine-builds/winehq.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && echo "deb https://dl.winehq.org/wine-builds/ubuntu/ $(grep VERSION_CODENAME= /etc/os-release | cut -d= -f2) main" >> /etc/apt/sources.list \
    && dpkg --add-architecture i386 \
    && apt-get update \
    && DEBIAN_FRONTEND="noninteractive" apt-get install -y --install-recommends winehq-${WINE_BRANCH} \
    && rm -rf /var/lib/apt/lists/*

# Install winetricks
RUN wget -nv -O /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/bin/winetricks

# Download gecko and mono installers
COPY download_gecko_and_mono.sh /root/download_gecko_and_mono.sh
RUN chmod +x /root/download_gecko_and_mono.sh \
    && /root/download_gecko_and_mono.sh "$(wine --version | sed -E 's/^wine-//')" \
    \
    && su user -c 'WINEARCH=win64 wine wineboot' \
    \
    # wintricks
    && su user -c 'winetricks -q msls31' \
    && su user -c 'winetricks -q ole32' \
    && su user -c 'winetricks -q riched20' \
    && su user -c 'winetricks -q riched30' \
    && su user -c 'winetricks -q win7' \
    \
    # Clean
    && rm -fr /usr/share/wine/{gecko,mono} \
    && rm -fr /home/user/{.cache,tmp}/* \
    && rm -fr /tmp/* \
    && echo 'Wine Initialized'

COPY [A-Z]* /
COPY VERSION /VERSION.docker-wine
COPY src/winescript /usr/local/bin/

# Configure locale for unicode
RUN locale-gen zh_CN.UTF-8
ENV LANG zh_CN.UTF-8

COPY pulse-client.conf /root/pulse/client.conf
COPY entrypoint.sh /usr/bin/entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
