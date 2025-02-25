#!/usr/bin/env python3

import os
import sys
import subprocess
import sqlite3
import json
import uuid

# 检测是否安装Python
def check_python():
    try:
        subprocess.check_output(["python3", "--version"])
    except FileNotFoundError:
        print("Python未安装，正在安装Python...")
        subprocess.run(["sudo", "apt-get", "update"])
        subprocess.run(["sudo", "apt-get", "install", "-y", "python3"])

# 检测是否安装SQLite
def check_sqlite():
    try:
        subprocess.check_output(["sqlite3", "--version"])
    except FileNotFoundError:
        print("SQLite未安装，正在安装SQLite...")
        subprocess.run(["sudo", "apt-get", "update"])
        subprocess.run(["sudo", "apt-get", "install", "-y", "sqlite3"])

# 连接数据库并添加用户
def add_users_to_db(protocol, num_users, start_port):
    db_path = "/etc/x-ui/x-ui.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    for i in range(num_users):
        port = start_port + i
        remark = f"{protocol}{i+1}"
        user_uuid = str(uuid.uuid4())

        if protocol == "vmess":
            settings = {
                "clients": [
                    {
                        "id": user_uuid,
                        "security": "auto",
                        "email": "",
                        "limitIp": 0,
                        "totalGB": 0,
                        "expiryTime": 0,
                        "enable": True,
                        "tgId": "",
                        "subId": "",
                        "comment": "",
                        "reset": 0
                    }
                ]
            }
            stream_settings = {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "acceptProxyProtocol": False,
                    "header": {
                        "type": "none"
                    }
                }
            }
            sniffing = {
                "enabled": False,
                "destOverride": ["http", "tls", "quic", "fakedns"],
                "metadataOnly": False,
                "routeOnly": False
            }
            allocate = {
                "strategy": "always",
                "refresh": 5,
                "concurrency": 3
            }

            user_data = {
                "remark": remark,
                "port": port,
                "protocol": protocol,
                "settings": json.dumps(settings),
                "stream_settings": json.dumps(stream_settings),
                "sniffing": json.dumps(sniffing),
                "allocate": json.dumps(allocate),
                "tag": str(uuid.uuid4())  # 使用 UUID 生成唯一的 tag
            }

        elif protocol == "socks":
            settings = '{"auth":"password","accounts":[{"user":"admin","pass":"admin"}],"udp":true,"ip":"127.0.0.1"}'
            sniffing = '{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}'
            allocate = '{"strategy":"always","refresh":5,"concurrency":3}'

            user_data = {
                "remark": remark,
                "port": port,
                "protocol": protocol,
                "settings": settings,
                "stream_settings": "",
                "sniffing": sniffing,
                "allocate": allocate,
                "enable": 1,
                "tag": str(uuid.uuid4())  # 使用 UUID 生成唯一的 tag
            }

        # 插入数据
        cursor.execute("INSERT INTO inbounds (remark, port, protocol, settings, stream_settings, sniffing, allocate, tag) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                       (user_data["remark"], user_data["port"], user_data["protocol"], user_data["settings"], user_data["stream_settings"], user_data["sniffing"], user_data["allocate"], user_data["tag"]))

    conn.commit()
    conn.close()

# 更新配置文件
def update_config_file(protocol, num_users, start_port):
    config_path = "/usr/local/x-ui/bin/config.json"
    with open(config_path, "r") as f:
        config = json.load(f)

    for i in range(num_users):
        port = start_port + i
        remark = f"{protocol}{i+1}"
        user_uuid = str(uuid.uuid4())

        if protocol == "vmess":
            user_data = {
                "listen": "0.0.0.0",  # 监听地址
                "port": port,  # 端口号
                "protocol": protocol,  # 协议类型
                "settings": {
                    "clients": [
                        {
                            "id": user_uuid,  # 客户端 UUID
                            "security": "auto",  # 加密方式
                            "email": "",  # 客户端邮箱
                            "limitIp": 0,  # IP 限制
                            "totalGB": 0,  # 总流量限制
                            "expiryTime": 0,  # 过期时间
                            "enable": True,  # 是否启用
                            "tgId": "",  # Telegram ID
                            "subId": "",  # 订阅 ID
                            "comment": "",  # 备注
                            "reset": 0  # 流量重置
                        }
                    ]
                },
                "streamSettings": {
                    "network": "tcp",  # 网络协议
                    "security": "none",  # 安全设置
                    "tcpSettings": {
                        "acceptProxyProtocol": False,  # 是否接受代理协议
                        "header": {
                            "type": "none"  # TCP 头部类型
                        }
                    }
                },
                "sniffing": {
                    "enabled": False,  # 是否启用流量嗅探
                    "destOverride": ["http", "tls", "quic", "fakedns"],  # 目标协议
                    "metadataOnly": False,  # 是否仅嗅探元数据
                    "routeOnly": False  # 是否仅用于路由
                },
                "allocate": {
                    "strategy": "always",  # 分配策略
                    "refresh": 5,  # 刷新间隔
                    "concurrency": 3  # 并发连接数
                },
                "tag": str(uuid.uuid4())  # 使用 UUID 生成唯一的 tag
            }

        elif protocol == "socks":
            user_data = {
                "listen": "0.0.0.0",  # 监听地址
                "port": port,  # 端口号
                "protocol": protocol,  # 协议类型
                "settings": {
                    "auth": "password",  # 认证方式
                    "accounts": [
                        {
                            "user": "admin",  # 用户名
                            "pass": "admin"  # 密码
                        }
                    ],
                    "udp": True,  # 是否支持 UDP
                    "ip": "127.0.0.1"  # 绑定 IP
                },
                "streamSettings": None,  # 流设置
                "sniffing": {
                    "enabled": False,  # 是否启用流量嗅探
                    "destOverride": ["http", "tls", "quic", "fakedns"],  # 目标协议
                    "metadataOnly": False,  # 是否仅嗅探元数据
                    "routeOnly": False  # 是否仅用于路由
                },
                "allocate": {
                    "strategy": "always",  # 分配策略
                    "refresh": 5,  # 刷新间隔
                    "concurrency": 3  # 并发连接数
                },
                "tag": str(uuid.uuid4())  # 使用 UUID 生成唯一的 tag
            }

        # 将新用户数据添加到 inbounds 部分
        config["inbounds"].append(user_data)

    # 将更新后的配置写回文件
    with open(config_path, "w") as f:
        json.dump(config, f, indent=4)

# 重启 3XUI 服务
def restart_xui_service():
    print("正在重启 3XUI 服务...")
    subprocess.run(["systemctl", "restart", "x-ui"])

# 主函数
def main():
    check_python()
    check_sqlite()

    print("你想使用什么类型？")
    print("1. vmess")
    print("2. socks")
    protocol_choice = input("请输入：")
    protocol = "vmess" if protocol_choice == "1" else "socks"

    num_users = int(input("你想要添加多少个用户？请输入："))
    start_port = int(input("端口号从多少开始？请输入："))

    add_users_to_db(protocol, num_users, start_port)
    update_config_file(protocol, num_users, start_port)
    restart_xui_service()

    print(f"成功添加了{num_users}个{protocol}用户，端口号从{start_port}开始。")

if __name__ == "__main__":
    main()
