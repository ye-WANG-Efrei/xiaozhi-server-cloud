# 小智 ESP32 Server — 云端部署

基于 [xinnan-tech/xiaozhi-esp32-server](https://github.com/xinnan-tech/xiaozhi-esp32-server) 的生产环境部署工作区。

## 快速部署

### 1. 克隆仓库

```bash
git clone https://github.com/ye-WANG-Efrei/xiaozhi-server-cloud.git /opt/xiaozhi-server-cloud
cd /opt/xiaozhi-server-cloud
```

### 2. 运行一键部署脚本

```bash
sudo bash deploy.sh
```

脚本会引导完成：
- Docker 安装（未安装时自动安装）
- Docker 镜像加速配置
- 服务器 IP、端口、数据库密码等参数配置
- 是否安装 AI 服务器（2GB 内存服务器建议先跳过）
- 容器启动 + 智控台密钥配置

---

## 服务端口

| 端口 | 用途 |
|------|------|
| 8000 | WebSocket（ESP32 设备连接） |
| 8002 | 智控台管理后台 |
| 8003 | HTTP（OTA 升级 + 视觉分析） |

> 云服务器需在安全组放行以上端口。

---

## 手动管理

### 查看运行状态

```bash
docker compose -f docker-compose_deploy.yml ps
```

### 查看日志

```bash
# AI 服务器
docker logs -f xiaozhi-esp32-server

# 智控台
docker logs -f xiaozhi-esp32-server-web
```

### 停止所有服务

```bash
docker compose -f docker-compose_deploy.yml down
```

### 升级

重新运行 `deploy.sh`，选择升级模式，数据库和上传文件会自动保留。

### 单独补装 AI 服务器

```bash
docker compose -f docker-compose_deploy.yml up -d xiaozhi-esp32-server
```

---

## 目录结构

```
.
├── deploy.sh                 # 一键部署脚本
├── docker-compose_deploy.yml # 容器编排
├── .env.example              # 参数模板（cp 为 .env 后填写）
├── data/                     # 配置文件（.gitignore，不进 git）
├── models/                   # VAD 模型文件（.gitignore，不进 git）
├── mysql/                    # 数据库数据（.gitignore，不进 git）
└── uploadfile/               # 上传文件（.gitignore，不进 git）
```

---

## 服务器配置建议

| 用途 | 最低配置 |
|------|---------|
| 仅智控台测试 | 1 核 2GB |
| 完整 AI 服务 | 4 核 4GB |
| 推荐生产环境 | 4 核 8GB |
