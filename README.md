# 屿声音乐 · Isle Music

TrollStore（巨魔）安装的音乐 + 短视频客户端，带会员体系与自建后端。

- 短名：屿声　英文：Isle　接口：**https://ys.irepo.cn**
- 仓库：`Petmao/MusicTroll`

## 目录

```
server/            服务端（Node 20 + Express + SQLite）
  db.js            建表
  config.js        签到/兑换/邀请的在线配置
  device.js        设备密钥与换绑
  stream.js        播放票据 / 流代理 / 本地播放许可
  server.js        全部路由
  public/admin.html  管理后台
  Dockerfile  docker-compose.yml  nginx.conf  README-DEPLOY.md

Isle/              客户端（SwiftUI）
  Config.swift     域名与常量（改域名只改这里）
  Network/APIClient.swift  AuthStore.swift
  Crypto/MTE.swift  DeviceKey.swift
  Gate/Gates.swift  播放闸门

build_tipa.sh      TrollStore 打包脚本（产物 Isle.tipa）
```

## 服务端部署

见 `server/README-DEPLOY.md`，五步：装依赖 → 填 `.env` → 起进程 → Nginx 反代 → certbot 签证书。

## 角色

| 角色 | 能力 |
|---|---|
| free | 登录 / 改密码 / 看设置 |
| vip | 听歌、音源、收藏歌单、本地加密播放 |
| svip | 以上全部 ＋ 养眼视频 |

## 免责

在线内容、可用音质与播放结果取决于第三方平台和所配置的音源；本项目不内置任何音乐或视频内容。
