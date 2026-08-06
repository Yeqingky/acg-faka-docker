# ACG-Faka Docker 部署

ACG-Faka 发卡系统的 Docker 部署方案：源码通过 bind mount 挂载（**不构建进镜像**），php-fpm 监听 unix socket，由宿主机 nginx 对接。

- 原项目：<https://github.com/lizhipay/acg-faka>

## 架构

```text
浏览器 ──> 宿主机 nginx ──(unix socket)──> faka-php (php:8.2-fpm)
                                            ├── faka-mysql (MySQL 8.0)
                                            └── faka-redis (Redis 7，Session 存储)
```

- php 镜像来自 Docker Hub：`yeqingky/acg-faka-docker:latest`
- 三个服务均 `restart: always`，任何原因退出自动重启
- MySQL/Redis 不映射宿主机端口，仅容器内部网络互访，不对公网开放

## 目录结构

```text
Dockerfile       php-fpm 运行环境镜像构建文件
nginx.conf       nginx server 配置模板
php/             php.ini、www.conf、entrypoint.sh
data/www/        源码（bind mount 到容器 /var/www/html）
data/php/        php-fpm unix socket 映射目录（宿主机 nginx 对接）
data/mysql/      MySQL 数据目录
data/redis/      Redis 数据目录
```

## 快速开始

### 1. 准备目录和权限

```bash
mkdir -p data/www data/php data/mysql data/redis
chown -R 33:33 data/www              # www-data，php-fpm 运行需可写（或 chmod -R 777）
chown 33:33 data/php && chmod 750 data/php
chown 999:999 data/mysql && chmod 750 data/mysql
```

> `redis:7-alpine` 以 root 运行，`data/redis` 无需 chown。
> 目录属主对应关系可通过 `docker run --rm <镜像> id <用户>` 验证。

### 2. 放入源码

将 ACG-Faka 源码放入 `data/www/`，并确保 www-data 可写（runtime/config 等目录由程序运行时自动创建）。

### 3. 启动

```bash
docker compose pull
docker compose up -d

# 确认 socket 已就绪
ls -l data/php/php-fpm.sock
```

## 外部 nginx 配置

使用仓库根目录的 `nginx.conf` 模板，修改三处：

1. `server_name example.com` → 你的域名
2. `root /opt/docker/store/data/www` → 实际源码路径
3. `fastcgi_pass unix:/opt/docker/store/data/php/php-fpm.sock` → 实际 socket 路径

```bash
nginx -t && nginx -s reload
```

关键点：`SCRIPT_FILENAME` 必须使用**容器内路径** `/var/www/html`，php-fpm 按该路径打开脚本；socket 属主 `www-data`、mode `0666`，容器重启后自动重建，无需重启 nginx。

## 首次安装

浏览器访问站点，安装页面数据库信息填写：

```text
数据库地址：mysql
数据库名称：acg-faka
数据库账号：acg-faka
数据库密码：acg-faka
数据库前缀：acg_
```

安装完成后台地址：`http://<你的域名>/admin`

## 常用操作

```bash
# 查看日志
docker compose logs -f --tail=100 faka-php

# 进入容器
docker exec -it faka-php bash

# 更新镜像并重启
docker compose pull && docker compose up -d

# 数据库导入（数据目录已挂载 data/mysql，SQL 文件放进去即可）
docker exec -i faka-mysql mysql -uroot -pacg-faka --default-character-set=utf8mb4 acg-faka < /path/to/backup.sql

# 查看数据库用户权限
docker exec faka-mysql mysql -uacg-faka -pacg-faka -e "SHOW GRANTS;"
```

## 重置环境

```bash
docker compose down
rm -f data/php/php-fpm.sock
```

数据目录 `data/*` 不受影响；如需彻底清空数据，另行删除对应目录。
