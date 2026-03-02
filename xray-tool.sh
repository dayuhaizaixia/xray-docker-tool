#!/bin/bash

# ================= 配置区 =================
GH_USER="caojiaxia"
TUNNEL_IMAGE="ghcr.io/$GH_USER/xray-tunnel:latest"
DOCKER_IMAGE="ghcr.io/$GH_USER/xray-docker:latest"
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 开启 BBR
enable_bbr() {
    if ! sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        echo -e "${BLUE}正在开启 BBR 加速...${NC}"
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
        sysctl -p
    fi
}

# 终极链接生成器 (全参数适配)
gen_link() {
    local TYPE=$1      # ws 或 xhttp
    local UUID=$2
    local XPATH=$3
    local ADDR=$4
    local PORT=$5
    local TLS=$6       # tls 或 none
    local REMARK=$7
    
    local ENCODED_PATH=$(echo "$XPATH" | sed 's/\//%2F/g')
    local SECURITY=$TLS
    [ "$TLS" == "none" ] && SECURITY="none"

    # 基础链接
    local LINK="vless://$UUID@$ADDR:$PORT?path=$ENCODED_PATH&security=$SECURITY&encryption=none"

    if [ "$TYPE" == "xhttp" ]; then
        # 补全 XHTTP 核心参数：mode, sni, fp, allowInsecure
        LINK="$LINK&type=xhttp&mode=packet"
        if [ "$TLS" == "tls" ]; then
            LINK="$LINK&sni=$ADDR&fp=chrome&allowInsecure=1"
        fi
    else
        # 补全 WS 核心参数
        LINK="$LINK&type=ws"
        if [ "$TLS" == "tls" ]; then
            LINK="$LINK&sni=$ADDR&fp=chrome&allowInsecure=1"
        fi
    fi

    LINK="$LINK#$REMARK"
    
    echo -e "${YELLOW}================ 终极节点配置 (全参数) ================${NC}"
    echo -e "${GREEN}协议: VLESS + $TYPE${NC} | ${CYAN}TLS: $TLS${NC} | ${CYAN}模式: packet${NC}"
    echo -e "SNI: $ADDR | 指纹: chrome | 允许不安全证书: 1"
    echo -e "${YELLOW}-------------------------------------------------------${NC}"
    echo -e "${CYAN}一键导入链接 (已适配 v2rayN / Shadowrocket / Clash):${NC}"
    echo -e "${BLUE}$LINK${NC}"
    echo -e "${YELLOW}=======================================================${NC}"
}

# 方案 2: NPM + Xray (XHTTP 满配版)
install_npm() {
    enable_bbr
    local IP=$(curl -s ifconfig.me)
    mkdir -p ~/xray-npm && cd ~/xray-npm
    
    read -p "请输入自定义 UUID (回车默认): " MY_UUID
    MY_UUID=${MY_UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
    read -p "请输入 XHTTP 路径 (回车默认 /xhttp): " MY_XPATH
    MY_XPATH=${MY_XPATH:-"/xhttp"}
    
    echo -e "${CYAN}是否准备在 NPM 中配置域名和 SSL 证书？(y/n)${NC}"
    read -p "> " HAS_DOMAIN
    
    if [[ "$HAS_DOMAIN" == "y" || "$HAS_DOMAIN" == "Y" ]]; then
        read -p "请输入你的域名 (例如 node.abc.com): " MY_DOMAIN
        ADDR=$MY_DOMAIN
        PORT=443
        TLS="tls"
    else
        ADDR=$IP
        PORT=80
        TLS="none"
    fi

    cat <<EOF > docker-compose.yml
services:
  npm:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: npm
    restart: always
    ports: ['80:80', '81:81', '443:443']
    volumes: ['./data:/data', './letsencrypt:/etc/letsencrypt']
    networks: [xray_net]
  xray:
    image: $DOCKER_IMAGE
    container_name: xray
    restart: always
    environment:
      - UUID=${MY_UUID}
      - XPATH=${MY_XPATH}
    networks: [xray_net]
networks:
  xray_net:
    driver: bridge
EOF
    docker compose up -d
    echo -e "${GREEN}部署成功！${NC}"
    gen_link "xhttp" "$MY_UUID" "$MY_XPATH" "$ADDR" "$PORT" "$TLS" "NPM_XHTTP_$ADDR"
}

# 方案 1: Tunnel (WS 满配版)
install_tunnel() {
    enable_bbr
    read -p "请输入 Tunnel Token: " TOKEN
    read -p "请输入自定义 UUID (回车默认): " MY_UUID
    MY_UUID=${MY_UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
    read -p "请输入 WS 路径 (回车默认 /ws): " MY_XPATH
    MY_XPATH=${MY_XPATH:-"/ws"}
    read -p "请输入你在 CF 绑定的域名: " MY_DOMAIN
    
    docker rm -f xray-tunnel 2>/dev/null
    docker run -d --name xray-tunnel --restart always \
      -e TUNNEL_TOKEN="$TOKEN" -e UUID="$MY_UUID" -e XPATH="$MY_XPATH" $TUNNEL_IMAGE
    
    echo -e "${GREEN}Tunnel 部署成功！${NC}"
    gen_link "ws" "$MY_UUID" "$MY_XPATH" "$MY_DOMAIN" "443" "tls" "CF_WS_$MY_DOMAIN"
}

# 菜单列表
show_menu() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${GREEN}      Claw VPS Xray 终极工具箱       ${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo "1) 安装 Cloudflare Tunnel 方案 (WS)"
    echo "2) 安装 NPM + Xray 方案 (XHTTP)"
    echo "3) 彻底卸载并清理残留"
    echo "4) 开启 BBR 加速"
    echo "5) 退出"
    echo -e "${BLUE}====================================${NC}"
}

while true; do
    show_menu
    read -p "请选择操作 [1-5]: " choice
    case "$choice" in
        1) install_tunnel ;;
        2) install_npm ;;
        3) docker rm -f xray-tunnel xray npm 2>/dev/null; docker network rm xray_net 2>/dev/null; rm -rf ~/xray-npm; echo -e "${RED}清理完成${NC}"; sleep 2 ;;
        4) enable_bbr; sleep 2 ;;
        5) exit 0 ;;
        *) echo "无效选项"; sleep 1 ;;
    esac
done
