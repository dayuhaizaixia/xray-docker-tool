#!/bin/sh

# 检查变量是否存在，如果不存在则使用默认值
UUID=${UUID:-"c67e108d-b135-4acd-b0b4-33f2d18dff44"}
XPATH=${XPATH:-"/GEdhhrQEkzaq"}

echo "正在启动 Xray，使用 UUID: $UUID 和 路径: $XPATH"

# 使用 sed 替换模板中的占位符，生成实际的 config.json
sed -e "s/\$UUID/$UUID/g" \
    -e "s|\$XPATH|$XPATH|g" \
    /etc/xray/config.template.json > /etc/xray/config.json

# 启动 xray
exec xray -config /etc/xray/config.json
