#!/bin/bash

# 检查输入参数,如何输入参数小于1，就打印提示，如果输入为1，就是设置的端口，否则需要输入3三个参数，分别为用户名和密码
if [ $# -lt 1 ]; then
    echo "Usage: $0 <port> [username] [password]"
    exit 1
elif [ $# -eq 1 ]; then
    port=$1
    authtype="noauth"
elif [ $# -eq 3 ]; then
    port=$1
    username=$2
    password=$3
    authtype="password"
else
    echo "Usage: $0 <port> [username] [password]"
    exit 1
fi

# 检查配置文件是否存在
if [ ! -d "config" ]; then
    echo "Config file missing. Exiting."
    exit 1
fi

# 检查是否安装了Docker
if ! command -v docker >/dev/null; then
    echo "Docker is not installed. Do you want to install it? (yes/no)"
    read -r answer
    if [ "$answer" = "yes" ]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
    else
        echo "Docker is required. Exiting."
        exit 1
    fi
fi

# 检查是否安装了Docker Compose
if ! command -v docker-compose >/dev/null; then
    echo "Docker Compose is not installed. Do you want to install it? (yes/no)"
    read -r answer
    if [ "$answer" = "yes" ]; then
        # 获取最新版本
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
        sudo curl -L "https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    else
        echo "Docker Compose is required. Exiting."
        exit 1
    fi
fi

# 重新生成xray配置文件进行替换
cat > config/config.json <<EOL
{
  "api": {
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ],
    "tag": "api"
  },
  "dns": null,
  "fakeDns": null,
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 62789,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "sniffing": null,
      "streamSettings": null,
      "tag": "api"
    },
    {
      "listen": null,
      "port": $port,
      "protocol": "socks",
      "settings": {
        "accounts": [
          {
            "pass": "$password",
            "user": "$username"
          }
        ],
        "auth": "$authtype",
        "ip": "127.0.0.1",
        "udp": false
      },
      "sniffing": null,
      "streamSettings": null,
      "tag": "inbound-31445"
    }
  ],
  "log": {
    "error": "./error.log",
    "loglevel": "warning"
  },
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "socks",
      "settings": {
        "servers": [
          {
            "address": "tor-privoxy",
            "port": 38801
          },
          {
            "address": "tor-privoxy",
            "port": 38802
          },
          {
            "address": "tor-privoxy",
            "port": 38803
          },
          {
            "address": "tor-privoxy",
            "port": 38804
          },
          {
            "address": "tor-privoxy",
            "port": 38805
          },
          {
            "address": "tor-privoxy",
            "port": 38806
          },
          {
            "address": "tor-privoxy",
            "port": 38807
          },
          {
            "address": "tor-privoxy",
            "port": 38808
          },
          {
            "address": "tor-privoxy",
            "port": 38809
          },
          {
            "address": "tor-privoxy",
            "port": 38810
          }
        ]
      },
      "tag": "socks_out"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true
    }
  },
  "reverse": null,
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "domain": [
          "regexp:.*"
        ],
        "outboundTag": "socks_out",
        "type": "field"
      },
      {
        "ip": [
          "0.0.0.0/0",
          "::/0"
        ],
        "outboundTag": "socks_out",
        "type": "field"
      },
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked",
        "type": "field"
      },
      {
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ],
        "type": "field"
      }
    ]
  },
  "stats": {},
  "transport": null
}
EOL


# 生成Docker Compose文件
cat > docker-compose.yml <<EOL
version: '3'

services:
  xray:
    image: teddysun/xray:latest
    container_name: xray
    hostname: xray
    volumes:
      - ./config/config.json:/etc/xray/config.json
    tty: true
    restart: unless-stopped
    ports:
      - $port:$port

  tor-privoxy:
    restart: always
    image: peterdavehello/tor-socks-proxy:latest
    volumes:
      - ./config/torrc:/etc/tor/torrc
    ports:
      - "127.0.0.1:38801:38801" # Tor SOCKS proxy
      - "127.0.0.1:38802:38802" # Tor SOCKS proxy
      - "127.0.0.1:38803:38803" # Tor SOCKS proxy
      - "127.0.0.1:38804:38804" # Tor SOCKS proxy
      - "127.0.0.1:38805:38805" # Tor SOCKS proxy
      - "127.0.0.1:38806:38806" # Tor SOCKS proxy
      - "127.0.0.1:38807:38807" # Tor SOCKS proxy
      - "127.0.0.1:38808:38808" # Tor SOCKS proxy
      - "127.0.0.1:38809:38809" # Tor SOCKS proxy
      - "127.0.0.1:38810:38810" # Tor SOCKS proxy
      - "127.0.0.1:9050:9050" # Tor proxy
EOL


docker-compose down
docker-compose up -d