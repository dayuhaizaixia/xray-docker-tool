#!/bin/bash
export UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}
export XPATH=${XPATH:-/randompath}

# 这一步会将 template 转换为真正的 config.json
envsubst '${UUID},${XPATH}' < /etc/xray/config.template.json > /etc/xray/config.json

exec /usr/bin/xray -config /etc/xray/config.json
