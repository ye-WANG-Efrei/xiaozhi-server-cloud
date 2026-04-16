#!/bin/bash
# 小智 ESP32 Server — 生产环境一键部署脚本

# ----------------------------------------------------------
# 中断处理
# ----------------------------------------------------------
handle_interrupt() {
  echo ""
  echo "部署已被用户中断"
  exit 1
}
trap handle_interrupt SIGINT SIGTERM

# ----------------------------------------------------------
# 颜色 & whiptail 主题
# ----------------------------------------------------------
export NEWT_COLORS='
root=green,black
window=green,black
border=green,black
title=green,black
button=black,green
actbutton=green,red
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
echo -e "  小智服务端生产环境部署脚本  Ver 2.0  $(date +%Y年%m月%d日)\033[0m"
echo ""
sleep 1

# ----------------------------------------------------------
# 工具函数
# ----------------------------------------------------------
ask_input() {
  local title="$1" prompt="$2" default="$3" result
  result=$(whiptail --title "$title" --inputbox "$prompt" 10 62 "$default" 3>&1 1>&2 2>&3)
  [ $? -ne 0 ] && echo "" || echo "$result"
}

ask_password() {
  local title="$1" prompt="$2" result
  result=$(whiptail --title "$title" --passwordbox "$prompt" 10 62 3>&1 1>&2 2>&3)
  [ $? -ne 0 ] && echo "" || echo "$result"
}

ask_yesno() {
  whiptail --title "$1" --yesno "$2" 14 72 \
    --yes-button "YES  是" \
    --no-button  "NO   否"
  return $?
}

# ----------------------------------------------------------
# root 权限检查
# ----------------------------------------------------------
if [ $EUID -ne 0 ]; then
  echo "请使用 root 权限运行本脚本：sudo bash deploy.sh"
  exit 1
fi

# ----------------------------------------------------------
# 系统检查（仅支持 Debian / Ubuntu）
# ----------------------------------------------------------
if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
    echo "本脚本仅支持 Debian / Ubuntu 系统"
    exit 1
  fi
else
  echo "无法识别系统版本，本脚本仅支持 Debian / Ubuntu 系统"
  exit 1
fi

# ----------------------------------------------------------
# whiptail 检查
# ----------------------------------------------------------
if ! command -v whiptail &>/dev/null; then
  echo "正在安装 whiptail..."
  apt update && apt install -y whiptail
fi

# ----------------------------------------------------------
# 欢迎 & 确认
# ----------------------------------------------------------
whiptail --title "小智 ESP32 Server 生产部署向导" \
  --msgbox "欢迎使用小智服务端生产环境部署脚本！\n\n本向导将完成：\n  • 检查并安装 Docker\n  • 配置 Docker 镜像加速\n  • 检测已有安装并支持升级\n  • 配置服务器网络、端口、数据库\n  • 启动全套容器服务\n  • 引导完成智控台密钥配置\n\n准备好后按 Ok 开始。" \
  18 62

# ----------------------------------------------------------
# curl 检查
# ----------------------------------------------------------
if ! command -v curl &>/dev/null; then
  echo "正在安装 curl..."
  apt update && apt install -y curl
fi

# ----------------------------------------------------------
# Docker 检查 & 安装
# ----------------------------------------------------------
if ! command -v docker &>/dev/null; then
  whiptail --title "Docker 未安装" \
    --msgbox "未检测到 Docker，即将使用阿里云镜像源自动安装 Docker CE。" 10 55

  DISTRO=$(lsb_release -cs)
  apt update
  apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

  mkdir -p /etc/apt/keyrings
  curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://mirrors.aliyun.com/docker-ce/linux/ubuntu $DISTRO stable" \
    > /etc/apt/sources.list.d/docker.list

  apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl start docker && systemctl enable docker

  if ! docker --version &>/dev/null; then
    whiptail --title "安装失败" --msgbox "Docker 安装失败，请检查网络后重试。" 10 50
    exit 1
  fi
  whiptail --title "安装完成" --msgbox "Docker 安装成功！" 8 40
fi

# ----------------------------------------------------------
# Docker 镜像加速配置
# ----------------------------------------------------------
MIRROR_CHOICE=$(whiptail --title "Docker 镜像加速" \
  --menu "选择 Docker 镜像加速源（国内服务器强烈推荐）" 18 62 8 \
  "1" "轩辕镜像（推荐）" \
  "2" "腾讯云" \
  "3" "中科大" \
  "4" "网易 163" \
  "5" "华为云" \
  "6" "阿里云" \
  "7" "自定义" \
  "8" "跳过" \
  3>&1 1>&2 2>&3) || exit 1

case $MIRROR_CHOICE in
  1) MIRROR_URL="https://docker.xuanyuan.me" ;;
  2) MIRROR_URL="https://mirror.ccs.tencentyun.com" ;;
  3) MIRROR_URL="https://docker.mirrors.ustc.edu.cn" ;;
  4) MIRROR_URL="https://hub-mirror.c.163.com" ;;
  5) MIRROR_URL="https://05f073ad3c0010ea0f4bc00b7105ec20.mirror.swr.myhuaweicloud.com" ;;
  6) MIRROR_URL="https://registry.aliyuncs.com" ;;
  7) MIRROR_URL=$(ask_input "自定义镜像源" "请输入完整的镜像源 URL" "") ;;
  8) MIRROR_URL="" ;;
esac

if [ -n "$MIRROR_URL" ]; then
  mkdir -p /etc/docker
  [ -f /etc/docker/daemon.json ] && cp /etc/docker/daemon.json /etc/docker/daemon.json.bak
  cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["$MIRROR_URL"],
  "dns": ["8.8.8.8", "114.114.114.114"]
}
EOF
  systemctl restart docker
  whiptail --title "配置完成" --msgbox "已配置镜像加速：$MIRROR_URL" 8 55
fi

# ----------------------------------------------------------
# 升级检测
# ----------------------------------------------------------
if docker inspect xiaozhi-esp32-server &>/dev/null || \
   docker inspect xiaozhi-esp32-server-web &>/dev/null; then

  if ask_yesno "检测到已有安装" \
    "检测到小智服务端已部署。\n\n选「是」执行升级：\n  停止旧容器 → 删除旧镜像 → 保留数据 → 重新拉起\n\n选「否」取消，不做任何改动。"; then

    echo "正在停止并移除旧容器..."
    docker compose -f docker-compose_deploy.yml down 2>/dev/null || true

    for c in xiaozhi-esp32-server xiaozhi-esp32-server-web \
              xiaozhi-esp32-server-db xiaozhi-esp32-server-redis; do
      docker rm -f "$c" 2>/dev/null && echo "已移除容器: $c" || true
    done

    for img in \
      "ghcr.nju.edu.cn/xinnan-tech/xiaozhi-esp32-server:server_latest" \
      "ghcr.nju.edu.cn/xinnan-tech/xiaozhi-esp32-server:web_latest"; do
      docker rmi "$img" 2>/dev/null && echo "已删除镜像: $img" || true
    done

    # 备份现有配置
    if [ -f data/.config.yaml ]; then
      mkdir -p data/backup
      BACKUP="data/backup/.config.yaml.$(date +%Y%m%d%H%M%S)"
      cp data/.config.yaml "$BACKUP"
      echo "已备份配置到 $BACKUP"
    fi

    whiptail --title "升级准备完成" \
      --msgbox "旧容器已清理，数据库和上传文件已保留。\n\n接下来重新确认部署参数。" 12 55
  else
    whiptail --title "已取消" --msgbox "升级已取消，当前部署保持不变。" 8 45
    exit 0
  fi
fi

# ----------------------------------------------------------
# 网络配置
# ----------------------------------------------------------
SERVER_PUBLIC_IP=""
while [ -z "$SERVER_PUBLIC_IP" ]; do
  SERVER_PUBLIC_IP=$(ask_input "【网络配置 1/2】" \
    "请输入服务器公网 IP\n（ESP32 设备通过公网连接时使用）" "")
  [ -z "$SERVER_PUBLIC_IP" ] && \
    whiptail --title "输入错误" --msgbox "公网 IP 不能为空，请重新输入。" 8 40
done

SERVER_LAN_IP=$(ask_input "【网络配置 2/2】" \
  "请输入服务器内网 IP\n（留空则与公网 IP 相同）" "$SERVER_PUBLIC_IP")
[ -z "$SERVER_LAN_IP" ] && SERVER_LAN_IP="$SERVER_PUBLIC_IP"

# ----------------------------------------------------------
# 端口配置
# ----------------------------------------------------------
WS_PORT=$(ask_input "【端口配置 1/3】" \
  "WebSocket 端口（ESP32 设备连接）" "8000")
[ -z "$WS_PORT" ] && WS_PORT="8000"

HTTP_PORT=$(ask_input "【端口配置 2/3】" \
  "HTTP 端口（OTA 升级 + 视觉分析）" "8003")
[ -z "$HTTP_PORT" ] && HTTP_PORT="8003"

WEB_PORT=$(ask_input "【端口配置 3/3】" \
  "智控台端口（浏览器访问管理后台）" "8002")
[ -z "$WEB_PORT" ] && WEB_PORT="8002"

# ----------------------------------------------------------
# 数据库配置
# ----------------------------------------------------------
MYSQL_ROOT_PASSWORD=""
while [ -z "$MYSQL_ROOT_PASSWORD" ]; do
  MYSQL_ROOT_PASSWORD=$(ask_password "【数据库配置 1/2】" \
    "请设置 MySQL root 密码（不能为空，请牢记）")
  [ -z "$MYSQL_ROOT_PASSWORD" ] && \
    whiptail --title "输入错误" --msgbox "密码不能为空，请重新输入。" 8 40
done

MYSQL_DATABASE=$(ask_input "【数据库配置 2/2】" "数据库名称" "xiaozhi_esp32_server")
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE="xiaozhi_esp32_server"

# ----------------------------------------------------------
# Redis 配置
# ----------------------------------------------------------
REDIS_PASSWORD=$(ask_password "【Redis 配置】" \
  "请设置 Redis 密码（留空表示不设密码）")

# ----------------------------------------------------------
# 时区配置
# ----------------------------------------------------------
TZ=$(ask_input "【时区配置】" "时区设置" "Asia/Shanghai")
[ -z "$TZ" ] && TZ="Asia/Shanghai"

# ----------------------------------------------------------
# AI 服务器安装选择
# ----------------------------------------------------------
INSTALL_AI_SERVER=0
if ask_yesno "【AI 服务器】" \
  "是否安装 AI 服务器（xiaozhi-esp32-server）？\n\n包含：Python 服务、语音识别、大模型对话\n内存占用：额外 ~800MB，峰值可达 ~1.5GB\n\n选「是」完整安装（推荐 4GB+ 内存）\n选「否」仅安装智控台 + 数据库（适合 2GB 服务器测试）"; then
  INSTALL_AI_SERVER=1
fi

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
  AI 服务器  ：$([ $INSTALL_AI_SERVER -eq 1 ] && echo "安装" || echo "跳过（可后续补装）")

确认部署？" 24 62

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
# 下载 VAD 模型（仅安装 AI 服务器时）
# ----------------------------------------------------------
if [ $INSTALL_AI_SERVER -eq 1 ]; then
  MODEL_PATH="./models/SenseVoiceSmall/model.pt"
  MODEL_URL="https://modelscope.cn/models/iic/SenseVoiceSmall/resolve/master/model.pt"

  if [ ! -f "$MODEL_PATH" ]; then
    if ask_yesno "【VAD 模型】" \
      "检测到 VAD 语音识别模型不存在（约 500MB）。\n\n选「是」现在下载。\n选「否」跳过，容器启动后将自动下载。"; then
      mkdir -p ./models/SenseVoiceSmall
      echo -e "\033[32m正在下载 VAD 模型，请耐心等待...\033[0m"
      if curl -L --progress-bar -o "$MODEL_PATH" "$MODEL_URL"; then
        whiptail --title "下载完成" --msgbox "VAD 模型下载成功！" 8 40
      else
        whiptail --title "下载失败" \
          --msgbox "下载失败，请检查网络。\n容器启动后将自动下载，或手动放置到：\n$MODEL_PATH" 10 55
        rm -f "$MODEL_PATH"
      fi
    else
      whiptail --title "已跳过" \
        --msgbox "已跳过。容器启动后将自动下载模型。" 8 50
    fi
  fi
fi

# ----------------------------------------------------------
# 启动服务
# ----------------------------------------------------------
clear
echo -e "\033[32m正在拉取镜像并启动服务，请稍候...\033[0m"
echo ""

if [ $INSTALL_AI_SERVER -eq 1 ]; then
  docker compose -f docker-compose_deploy.yml up -d
else
  docker compose -f docker-compose_deploy.yml up -d \
    xiaozhi-esp32-server-db \
    xiaozhi-esp32-server-redis \
    xiaozhi-esp32-server-web
fi

if [ $? -ne 0 ]; then
  whiptail --title "启动失败" \
    --msgbox "容器启动失败，请检查日志：\n\n  docker compose -f docker-compose_deploy.yml logs" \
    10 62
  exit 1
fi

# ----------------------------------------------------------
# 健康检查：等待智控台就绪（最长 3 分钟）
# ----------------------------------------------------------
echo -e "\033[32m正在等待智控台启动（最长 3 分钟）...\033[0m"
TIMEOUT=180
START=$(date +%s)
while true; do
  if docker logs xiaozhi-esp32-server-web 2>&1 | grep -q "Started AdminApplication in"; then
    echo -e "\033[32m智控台已就绪。\033[0m"
    break
  fi
  if [ $(( $(date +%s) - START )) -gt $TIMEOUT ]; then
    whiptail --title "启动超时" \
      --msgbox "智控台未在 3 分钟内就绪，可能仍在初始化。\n\n请稍后手动检查：\n  docker logs xiaozhi-esp32-server-web" \
      12 60
    break
  fi
  sleep 3
done

# ----------------------------------------------------------
# 智控台密钥配置
# ----------------------------------------------------------
# ----------------------------------------------------------
# 智控台密钥配置（用普通终端输入，支持正常粘贴）
# ----------------------------------------------------------
clear
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m  配置智控台密钥\033[0m"
echo -e "\033[32m================================================\033[0m"
echo ""
echo -e "  1. 用浏览器访问智控台："
echo -e "     \033[0mhttp://${SERVER_PUBLIC_IP}:${WEB_PORT}\033[32m"
echo ""
echo -e "  2. 注册第一个账号（即超级管理员）"
echo ""
echo -e "  3. 登录后进入："
echo -e "     顶部菜单 → 参数字典 → 参数管理"
echo -e "     找到参数编码：\033[33mserver.secret\033[32m"
echo -e "     复制该参数值"
echo ""
echo -e "  提示：云服务器请先在安全组放行端口 ${WS_PORT}、${HTTP_PORT}、${WEB_PORT}"
echo ""
echo -e "\033[32m================================================\033[0m"
echo -e "\033[0m"
echo -n "请粘贴 server.secret（留空跳过）: "
read -r SECRET_KEY

if [ -n "$SECRET_KEY" ]; then
  cat >> data/.config.yaml <<EOF

manager-api:
  url: http://xiaozhi-esp32-server-web:${WEB_PORT}/xiaozhi
  secret: ${SECRET_KEY}
EOF
  docker restart xiaozhi-esp32-server
  echo -e "\033[32m密钥已写入，AI 服务器已重启。\033[0m"
else
  echo -e "\033[33m已跳过密钥配置，后续可编辑 data/.config.yaml 手动添加。\033[0m"
fi

# ----------------------------------------------------------
# 完成
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
echo -e "\033[32m================================================\033[0m"
echo -e "\033[32m  部署完成！\033[0m"
echo ""
echo -e "\033[32m  智控台   ：\033[0mhttp://${SERVER_PUBLIC_IP}:${WEB_PORT}"
echo -e "\033[32m  OTA 地址 ：\033[0mhttp://${SERVER_PUBLIC_IP}:${WEB_PORT}/xiaozhi/ota/"
echo -e "\033[32m  WebSocket：\033[0mws://${SERVER_PUBLIC_IP}:${WS_PORT}/xiaozhi/v1/"
echo -e "\033[32m  视觉分析 ：\033[0mhttp://${SERVER_PUBLIC_IP}:${HTTP_PORT}/mcp/vision/explain"
echo -e "\033[32m================================================\033[0m"
echo ""
echo -e "\033[33m  提示：云服务器安全组需放行端口 ${WS_PORT}、${HTTP_PORT}、${WEB_PORT}\033[0m"
echo ""
