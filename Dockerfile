FROM debian:stable-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/steam

# Install dependencies required by SteamCMD/Source dedicated servers
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        curl \
        tar \
        bzip2 \
        locales \
        libc6-i386 \
        lib32gcc-s1 \
        lib32stdc++6 \
        libstdc++6:i386 \
        libcurl4:i386 \
        libtinfo6:i386 \
        libncurses6:i386 \
        libbz2-1.0:i386 \
        zlib1g:i386 && \
    ln -sf /lib/i386-linux-gnu/libtinfo.so.6 /lib/i386-linux-gnu/libtinfo.so.5 && \
    ln -sf /lib/i386-linux-gnu/libncurses.so.6 /lib/i386-linux-gnu/libncurses.so.5 && \
    rm -rf /var/lib/apt/lists/*

# Create a user for running the server
RUN useradd -m steam

# Set working directory
WORKDIR /home/steam

USER steam

# Download and install SteamCMD
RUN mkdir /home/steam/steamcmd && \
    cd /home/steam/steamcmd && \
    wget https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz && \
    tar -xvzf steamcmd_linux.tar.gz && \
    rm steamcmd_linux.tar.gz && \
    mkdir -p /home/steam/.steam/sdk32 /home/steam/.steam/sdk64 && \
    ln -sf /home/steam/steamcmd/linux32/steamclient.so /home/steam/.steam/sdk32/steamclient.so && \
    ln -sf /home/steam/steamcmd/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so

# Install Day of Defeat: Source server using SteamCMD
RUN /home/steam/steamcmd/steamcmd.sh +force_install_dir /home/steam/dods \
    +login anonymous \
    +app_update 232290 validate \
    +quit

ENV MMSOURCE_BRANCH=1.12
ENV SOURCEMOD_BRANCH=1.12
# DoD:S Linux dedicated server is 32-bit. The Metamod tarball also ships metamod_x64.vdf + linux64/, which
# leads to dlopen of ELFCLASS64 libraries and startup failure; remove the x64-only stub.
RUN MMS_FILE="$(curl -fsSL "https://mms.alliedmods.net/mmsdrop/${MMSOURCE_BRANCH}/mmsource-latest-linux" | tr -d '\r\n')" && \
    wget -O /tmp/mmsource.tar.gz "https://mms.alliedmods.net/mmsdrop/${MMSOURCE_BRANCH}/${MMS_FILE}" && \
    tar -xzf /tmp/mmsource.tar.gz -C /home/steam/dods/dod && \
    SM_FILE="$(curl -fsSL "https://sm.alliedmods.net/smdrop/${SOURCEMOD_BRANCH}/sourcemod-latest-linux" | tr -d '\r\n')" && \
    wget -O /tmp/sourcemod.tar.gz "https://sm.alliedmods.net/smdrop/${SOURCEMOD_BRANCH}/${SM_FILE}" && \
    tar -xzf /tmp/sourcemod.tar.gz -C /home/steam/dods/dod && \
    rm -f /tmp/mmsource.tar.gz /tmp/sourcemod.tar.gz && \
    rm -f /home/steam/dods/dod/addons/metamod_x64.vdf && \
    rm -rf /home/steam/dods/dod/addons/metamod/bin/linux64

# Expose default DoD:S ports (used when not running with host networking)
EXPOSE 27015/udp 27015/tcp 27020/udp

USER root

COPY --chown=steam:steam dod/cfg /home/steam/dods/dod/cfg
COPY --chown=steam:steam dod/addons /home/steam/dods/dod/addons
COPY --chown=steam:steam dod/downloadlists /home/steam/dods/dod/downloadlists
COPY --chown=steam:steam dod/materials /home/steam/dods/dod/materials
COPY --chown=steam:steam dod/models /home/steam/dods/dod/models
COPY --chown=steam:steam dod/resource /home/steam/dods/dod/resource
COPY --chown=steam:steam dod/sound /home/steam/dods/dod/sound

# Set user
USER steam

# Set working directory to game server
WORKDIR /home/steam/dods

# Controls LAN/WAN behavior:
# - SV_LAN=1 (default): LAN server
# - SV_LAN=0: WAN/internet server
ENV SV_LAN=1

# Start the server using runtime-configurable LAN mode
CMD ["sh", "-c", "./srcds_run -game dod -console -usercon -ip 0.0.0.0 -port 27015 -tickrate 66 +sv_lan ${SV_LAN} +map dod_anzio +maxplayers 32 +exec server.cfg"]