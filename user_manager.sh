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
                "tag": ""  # 设置默认值
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
                "tag": ""  # 设置默认值
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
                "remark": remark,
                "port": port,
                "protocol": protocol,
                "settings": {
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
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "none",
                    "tcpSettings": {
                        "acceptProxyProtocol": False,
                        "header": {
                            "type": "none"
                        }
                    }
                },
                "sniffing": {
                    "enabled": False,
                    "destOverride": ["http", "tls", "quic", "fakedns"],
                    "metadataOnly": False,
                    "routeOnly": False
                },
                "allocator": {
                    "strategy": "always",
                    "refresh": 5,
                    "concurrency": 3
                },
                "tag": ""  # 设置默认值
            }

        elif protocol == "socks":
            user_data = {
                "remark": remark,
                "port": port,
                "protocol": protocol,
                "settings": '{"auth":"password","accounts":[{"user":"admin","pass":"admin"}],"udp":true,"ip":"127.0.0.1"}',
                "sniffing": '{"enabled":false,"destOverride":["http","tls","quic","fakedns"],"metadataOnly":false,"routeOnly":false}',
                "allocator": '{"strategy":"always","refresh":5,"concurrency":3}',
                "enable": 1,
                "tag": ""  # 设置默认值
            }

        config["inbounds"].append(user_data)

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
