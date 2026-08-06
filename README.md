# ACG-Faka Docker 部署（php-fpm + unix socket，无内置 nginx）

本编排提供三个服务：

- `php`：`php:8.2-fpm` 通用镜像构建扩展环境，源码通过 bind mount 挂载，**不构建进镜像**；监听 unix socket 并映射到宿主机。
- `mysql`：MySQL 8.0。
- `redis`：Redis 7，作为 PHP Session 存储。

不包含 nginx 服务，由宿主机上的 nginx 直接通过 unix socket 对接 php-fpm。

## 目录结构

```text
Dockerfile      php-fpm 运行环境镜像构建文件
nginx.conf      nginx server 配置模板
php/            php-fpm 的 php.ini、www.conf、entrypoint.sh
data/www/       源码（bind mount 到容器 /var/www/html）
data/php/       php-fpm 的 unix socket 映射目录（宿主机 nginx 对接）
data/mysql/     MySQL 数据目录
data/redis/     Redis 数据目录
```

## 首次启动

```bash
# 1. 准备宿主机目录权限
mkdir -p data/www data/php data/mysql data/redis
# 源码放 data/www 下，php-fpm 以 www-data 运行需可写（runtime/config 等）
# chown -R 33:33 data/www    # 或 chmod -R 777 data/www
chown 33:33 data/php && chmod 750 data/php       # www-data，php-fpm socket
chown 999:999 data/mysql && chmod 750 data/mysql  # mysql
# redis:7-alpine 以 root 运行，data/redis 无需 chown

# 2. 拉取镜像并启动（php 镜像来自 yeqingky/acg-faka-docker）
docker compose pull
docker compose up -d

# 3. 确认 php-fpm socket 已就绪
ls -l data/php/php-fpm.sock
```

> 容器内服务进程以各自用户（www-data/mysql/redis）运行，挂载目录属主不对会启动失败；
> 源码目录 `data/www/` 需保证 www-data 可写（如 `chmod -R 777`），
> runtime 等目录由程序运行时自动创建。

## 外部 nginx 配置

参考仓库根目录的 `nginx.conf`（模板）。使用前：

1. 将 `server_name example.com` 替换为你的域名
2. 将 `root /opt/docker/store/data/www` 和 `fastcgi_pass unix:/opt/docker/store/data/php/php-fpm.sock` 替换为实际路径
3. `nginx -t && nginx -s reload`

要点：`SCRIPT_FILENAME` 必须使用容器内路径 `/var/www/html`，php-fpm 会按该路径打开脚本；socket 文件属主 `www-data`、mode `0666`，容器重启后 socket 自动重建，无需重启 nginx。

## 首次安装填写

安装页面里的数据库信息请填写：

```text
数据库地址：mysql
数据库名称：acg-faka
数据库账号：acg-faka
数据库密码：acg-faka
数据库前缀：acg_
```

> MySQL/Redis 不映射宿主机端口，仅容器内部网络互访，不对公网开放。

安装完成后后台地址：

```text
http://<你的域名>/admin
```

## 重置环境

```bash
docker compose down
rm -f data/php/php-fpm.sock
```
