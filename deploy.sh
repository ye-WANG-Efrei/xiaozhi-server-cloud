#!/bin/bash
# 小智 ESP32 Server — 交互式一键部署脚本

# ----------------------------------------------------------
# 颜色 & whiptail 主题（紫色背景，绿字）
# ----------------------------------------------------------
export NEWT_COLORS='
root=green,black
window=green,black
border=green,black
title=green,black
button=black,green
actbutton=black,brightgreen
entry=black,green
label=green,black
checkbox=green,black
actcheckbox=black,green
compactbutton=black,green
listbox=green,black
actlistbox=black,green
textbox=green,black
acttextbox=black,green
helpline=black,green
roottext=green,black
emptyscale=,black
fullscale=,green
disentry=black,green
shadow=,black
'

# ----------------------------------------------------------
# Banner
# ----------------------------------------------------------
clear
echo -e "\033[32m"
cat << 'BANNER'

__        __    _      _   _    ____       __   __  _____  _____  _____  _____
\ \      / /   / \   | \ | |  / ___|      \ \ / / | ____|| ____|| ____|| ____|
 \ \ /\ / /   / _ \  |  \| | | |  _        \ V /  |  _|  |  _|  |  _|  |  _|
  \ V  V /   / ___ \ | |\  | | |_| |        | |   | |___ | |___ | |___ | |___
   \_/\_/   /_/   \_\|_| \_|  \____|        |_|   |_____||_____||_____||_____|

BANNER
echo -e "\033[32m  脚本作者：WANG YEEEE"
echo -e "  小智服务端全量部署一键安装脚本  Ver 1.0  $(date +%Y年%m月%d日)\033[0m"
echo ""
sleep 1

# ----------------------------------------------------------
# 工具函数：whiptail 输入框
# ----------------------------------------------------------
ask_input() {
  local title="$1"
  local prompt="$2"
  local default="$3"
  local result
  result=$(whiptail --title "$title" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
  local exit_code=$?
  [ $exit_code -ne 0 ] && echo "" || echo "$result"
}

ask_password() {
  local title="$1"
  local prompt="$2"
  local result
  result=$(whiptail --title "$title" --passwordbox "$prompt" 10 60 3>&1 1>&2 2>&3)
  local exit_code=$?
  [ $exit_code -ne 0 ] && echo "" || echo "$result"
}

ask_yesno() {
  local title="$1"
  local prompt="$2"
  whiptail --title "$title" --yesno "$prompt" 10 60
  return $?
}

# ----------------------------------------------------------
# 欢迎界面
# ----------------------------------------------------------
whiptail --title "小智 ESP32 Server 部署向导" \
  --msgbox "欢迎使用小智服务端全量部署脚本！\n\n本向导将引导你完成以下配置：\n  • 服务器网络地址\n  • 各服务运行端口\n  • 数据库账号密码\n  • Redis 密码\n\n准备好后按 Ok 开始。" \
  16 60

# ----------------------------------------------------------
# 网络配置
# ----------------------------------------------------------
SERVER_PUBLIC_IP=""
while [ -z "$SERVER_PUBLIC_IP" ]; do
  SERVER_PUBLIC_IP=$(ask_input "【网络配置 1/2】" \
    "请输入服务器公网 IP\n（ESP32 设备通过公网连接时使用）" "")
  [ -z "$SERVER_PUBLIC_IP" ] && whiptail --title "输入错误" --msgbox "公网 IP 不能为空，请重新输入。" 8 40
done

SERVER_LAN_IP=$(ask_input "【网络配置 2/2】" \
  "请输入服务器内网 IP\n（局域网设备使用；留空则与公网 IP 相同）" "$SERVER_PUBLIC_IP")
[ -z "$SERVER_LAN_IP" ] && SERVER_LAN_IP="$SERVER_PUBLIC_IP"

# ----------------------------------------------------------
# 端口配置
# ----------------------------------------------------------
WS_PORT=$(ask_input "【端口配置 1/3】" \
  "WebSocket 端口\n（ESP32 设备连接，通常不需要修改）" "8000")
[ -z "$WS_PORT" ] && WS_PORT="8000"

HTTP_PORT=$(ask_input "【端口配置 2/3】" \
  "HTTP 端口\n（OTA 升级 + 视觉分析接口）" "8003")
[ -z "$HTTP_PORT" ] && HTTP_PORT="8003"

WEB_PORT=$(ask_input "【端口配置 3/3】" \
  "智控台端口\n（浏览器访问管理后台）" "8002")
[ -z "$WEB_PORT" ] && WEB_PORT="8002"

# ----------------------------------------------------------
# 数据库配置
# ----------------------------------------------------------
MYSQL_ROOT_PASSWORD=""
while [ -z "$MYSQL_ROOT_PASSWORD" ]; do
  MYSQL_ROOT_PASSWORD=$(ask_password "【数据库配置 1/2】" \
    "请设置 MySQL root 密码\n（不能为空，请牢记）")
  [ -z "$MYSQL_ROOT_PASSWORD" ] && whiptail --title "输入错误" --msgbox "密码不能为空，请重新输入。" 8 40
done

MYSQL_DATABASE=$(ask_input "【数据库配置 2/2】" \
  "数据库名称" "xiaozhi_esp32_server")
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE="xiaozhi_esp32_server"

# ----------------------------------------------------------
# Redis 配置
# ----------------------------------------------------------
REDIS_PASSWORD=$(ask_password "【Redis 配置】" \
  "请设置 Redis 密码\n（留空表示不设密码）")

# ----------------------------------------------------------
# 时区配置
# ----------------------------------------------------------
TZ=$(ask_input "【时区配置】" "时区设置" "Asia/Shanghai")
[ -z "$TZ" ] && TZ="Asia/Shanghai"

# ----------------------------------------------------------
# 确认信息
# ----------------------------------------------------------
whiptail --title "请确认配置信息" --yesno \
"以下是你的配置，确认无误后开始部署：

  公网 IP    ：$SERVER_PUBLIC_IP
  内网 IP    ：$SERVER_LAN_IP
  WS  端口   ：$WS_PORT
  HTTP 端口  ：$HTTP_PORT
  智控台端口 ：$WEB_PORT
  数据库名   ：$MYSQL_DATABASE
  MySQL 密码 ：$(echo "$MYSQL_ROOT_PASSWORD" | sed 's/./*/g')
  Redis 密码 ：$([ -z "$REDIS_PASSWORD" ] && echo "（不设密码）" || echo "$REDIS_PASSWORD" | sed 's/./*/g')
  时区       ：$TZ

确认部署？" 22 60

if [ $? -ne 0 ]; then
  whiptail --title "已取消" --msgbox "部署已取消。" 8 40
  exit 0
fi

# ----------------------------------------------------------
# 生成 .env
# ----------------------------------------------------------
cat > .env <<EOF
SERVER_PUBLIC_IP=$SERVER_PUBLIC_IP
SERVER_LAN_IP=$SERVER_LAN_IP
WS_PORT=$WS_PORT
HTTP_PORT=$HTTP_PORT
WEB_PORT=$WEB_PORT
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=$MYSQL_DATABASE
REDIS_PASSWORD=$REDIS_PASSWORD
TZ=$TZ
EOF

# ----------------------------------------------------------
# 生成 data/.config.yaml
# ----------------------------------------------------------
mkdir -p data
cat > data/.config.yaml <<EOF
server:
  websocket: ws://${SERVER_PUBLIC_IP}:${WS_PORT}/xiaozhi/v1/
  vision_explain: http://${SERVER_PUBLIC_IP}:${HTTP_PORT}/mcp/vision/explain
EOF

# ----------------------------------------------------------
# 下载 VAD 模型文件（可选）
# ----------------------------------------------------------
MODEL_PATH="./models/SenseVoiceSmall/model.pt"
MODEL_URL="https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt"

if [ ! -f "$MODEL_PATH" ]; then
  whiptail --title "【VAD 模型】" --yesno \
"检测到 VAD 语音识别模型文件不存在。

是否现在下载？（约 500MB，需要一段时间）

  下载地址：ModelScope iic/SenseVoiceSmall
  保存路径：$MODEL_PATH

选择「否」可跳过，后续容器启动时会自动下载。" 16 65

  if [ $? -eq 0 ]; then
    mkdir -p ./models/SenseVoiceSmall
    echo ""
    echo -e "\033[32m正在下载 VAD 模型文件，请耐心等待...\033[0m"
    echo -e "\033[32m下载地址：$MODEL_URL\033[0m"
    echo ""
    if curl -L --progress-bar -o "$MODEL_PATH" "$MODEL_URL"; then
      whiptail --title "下载完成" --msgbox "VAD 模型文件下载成功！" 8 40
    else
      whiptail --title "下载失败" --msgbox "下载失败，请检查网络连接。\n后续可手动下载后放置到：\n$MODEL_PATH" 10 55
      rm -f "$MODEL_PATH"
    fi
  else
    whiptail --title "已跳过" --msgbox "已跳过模型下载。\n容器启动后将自动下载，或您可手动下载放置到：\n$MODEL_PATH" 10 55
  fi
else
  whiptail --title "VAD 模型" --msgbox "检测到模型文件已存在，跳过下载。" 8 50
fi

# ----------------------------------------------------------
# 启动 Docker 服务
# ----------------------------------------------------------
clear
echo -e "\033[32m"
cat << 'BANNER'

__        __    _      _   _    ____       __   __  _____  _____  _____  _____
\ \      / /   / \   | \ | |  / ___|      \ \ / / | ____|| ____|| ____|| ____|
 \ \ /\ / /   / _ \  |  \| | | |  _        \ V /  |  _|  |  _|  |  _|  |  _|
  \ V  V /   / ___ \ | |\  | | |_| |        | |   | |___ | |___ | |___ | |___
   \_/\_/   /_/   \_\|_| \_|  \____|        |_|   |_____||_____||_____||_____|

BANNER
echo -e "\033[0m"
echo -e "\033[32m正在启动所有服务，请稍候...\033[0m"
echo ""

docker compose -f docker-compose_deploy.yml up -d

echo ""
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m  部署完成！\033[0m"
echo ""
echo -e "\033[32m  智控台   ：\033[0mhttp://${SERVER_PUBLIC_IP}:${WEB_PORT}"
echo -e "\033[32m  WebSocket：\033[0mws://${SERVER_PUBLIC_IP}:${WS_PORT}/xiaozhi/v1/"
echo -e "\033[32m  视觉分析 ：\033[0mhttp://${SERVER_PUBLIC_IP}:${HTTP_PORT}/mcp/vision/explain"
echo -e "\033[32m================================================\033[0m"
