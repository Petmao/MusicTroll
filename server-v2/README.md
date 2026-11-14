# 屿声音乐 · 服务端 v2

Casdoor 账号 + 自研卡密会员 + 音乐源/视频源管理 + 开放 API。
单文件 Node 服务，SQLite 存储，一条 `docker compose up -d` 起飞。

## 目录

```
server-v2/
  package.json
  .env.example
  Dockerfile
  docker-compose.yml
  core.js       连接池 / 建表 / JWT / 卡密 / Casdoor
  server.js     全部路由（账号·卡密·积分·设备·源·管理·开放 API）
  public/
    admin.html  管理后台（单页，无需构建）
```

## 部署

### 1. 上传解压

```bash
mkdir -p /opt/isle && cd /opt/isle
# 把 server-v2 里的东西丢进来，然后：
cp .env.example .env
vim .env
```

`.env` 必改三项：

```ini
JWT_SECRET=至少32位随机串
ADMIN_ACCOUNT=你的后台账号
ADMIN_PASSWORD=你的后台密码
```

生成随机串：

```bash
openssl rand -hex 32
```

### 2. 起服务

```bash
docker compose up -d --build
docker compose logs -f --tail=50
```

看到这两行就成了：

```
[isle] listening on 8787  casdoor=off
[isle] data dir: /data
```

自检：

```bash
curl -s http://127.0.0.1:8787/api/health
# {"ok":true,"name":"Isle Music API v2","version":"2.0.0","casdoor":false,...}
```

### 3. 打开后台

浏览器进 `http://你的服务器IP:8787/admin.html`，用 `.env` 里的账号密码登录。

后台能做的事：

- **概览**：用户数、未用卡密、订单、收入、在线设备、启用源数
- **音乐源 / 视频源**：增删改、单条测试连通、启停、排序
- **卡密**：按档位（VIP/SVIP）+ 天数 + 数量批量生成，一次输出可复制的列表
- **用户**：搜索、加 VIP、加/扣积分
- **订单**：每笔卡密兑换的流水
- **开放 API**：签发 `X-Api-Key` 给第三方
- **审计日志**：登录、兑换、改权限、加源全部落库

### 4. Nginx 反代 + HTTPS

`/etc/nginx/conf.d/isle.conf`：

```nginx
server {
    listen 80;
    server_name ys.irepo.cn;

    client_max_body_size 20m;

    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_read_timeout 300s;
    }
}
```

```bash
nginx -t && systemctl reload nginx
certbot --nginx -d ys.irepo.cn
```

### 5. 客户端指向新域名

`Isle/Config.swift` 里那段 Base64 拆两段，改完重新构建：

当前 `Isle/Config.swift` 已经指向 `https://ys.irepo.cn`，两段 Base64 分别是：

```swift
let parts = ["aHR0cHM6Ly8=", "eXMuaXJlcG8uY24="]
//              https://          ys.irepo.cn
```

要换域名，分别生成两段：

生成：

```bash
echo -n 'https://ys.irepo.cn' | base64
# aHR0cHM6Ly95cy5leGFtcGxlLmNvbQ==
```

把后半段（去掉 `https://` 的结果）换进 `parts[1]`：

```bash
echo -n 'ys.irepo.cn' | base64
```

## Casdoor 接入

不接也能跑，`CASDOOR_ENABLED=0` 时用本地账号密码，和 v1 行为一致。

### 起 Casdoor

```bash
mkdir -p /opt/casdoor/conf /opt/casdoor/logs
cp casdoor/conf/app.conf /opt/casdoor/conf/
docker run -d --name casdoor \
  -p 127.0.0.1:8000:8000 \
  -v /opt/casdoor/conf:/conf \
  -v /opt/casdoor/logs:/logs \
  casbin/casdoor:latest
```

默认管理员 `admin / 123`，进去第一件事改密码。

### 配置应用

1. `组织` → 记下组织名，默认 `built-in`
2. `应用` → 编辑 `app-built-in`
   - 回调 URL 填 `isle://auth`
   - 记下 `Client ID` 与 `Client Secret`
3. 需要微信登录就在 `身份提供商` 里加 WeChat，填 AppID/AppSecret，回调填 `https://door.ys.irepo.cn/callback`

### 打开开关

```ini
CASDOOR_ENABLED=1
CASDOOR_ENDPOINT=https://door.ys.irepo.cn
CASDOOR_CLIENT_ID=你的 Client ID
CASDOOR_CLIENT_SECRET=你的 Client Secret
CASDOOR_ORG=built-in
CASDOOR_APP=app-built-in
CASDOOR_REDIRECT=isle://auth
```

```bash
docker compose restart isle
```

### 客户端流程

```
1  GET  /api/auth/casdoor/url         → { url }
2  打开 url 登录，Casdoor 回跳 isle://auth?code=xxx
3  POST /api/auth/casdoor/exchange    { code }  → { token, user, entitlements }
4  之后所有请求带 Authorization: Bearer <token>
```

首次登录自动建本地用户，`account` 是 `cd_` 加 sub 的哈希前 10 位，`casdoor_sub` 唯一约束保证不重复。

## 接口清单

### 账号

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/auth/register` | `{account,nickname,password,phone?,inviteCode?}` |
| POST | `/api/auth/login` | `{account,password}` |
| GET | `/api/auth/me` | 当前用户 + 权益 |
| POST | `/api/auth/password` | `{oldPassword,newPassword}` |
| GET | `/api/auth/check-account?account=` | 查重 |
| GET | `/api/auth/casdoor/status` | 是否开启 |
| GET | `/api/auth/casdoor/url` | 拿登录地址 |
| POST | `/api/auth/casdoor/exchange` | code 换 token |

### 会员

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/redeem` | `{code}`，事务里写 codes + orders + entitlements |
| GET | `/api/orders` | 我的订单 |
| GET | `/api/points` | 积分余额与流水 |
| GET | `/api/checkin/status` | 今日是否签到、连签天数 |
| POST | `/api/checkin` | 签到，连签 7 天翻倍 |
| GET | `/api/invite/me` | 邀请码与已邀请列表 |

### 设备

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/api/device/register` | `{deviceId,name}`，超限返回 `device_limit` |
| GET | `/api/device/list?deviceId=` | 设备列表 |
| POST | `/api/device/unbind` | `{deviceId}` |

### 源与播放

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/sources?kind=music\|video` | 启用的源（需登录） |
| GET | `/api/search?kw=` | 依次打启用的音乐源，返回第一个有结果的 |
| POST | `/api/play/ticket` | `{url,kind}` → 短签名流地址 |
| GET | `/api/play/stream` | 票据校验后代理音频 |

### 管理（Bearer admin token）

| 方法 | 路径 |
|---|---|
| POST | `/api/admin/login` |
| GET | `/api/admin/stats` |
| GET | `/api/admin/users?q=&page=` |
| PATCH | `/api/admin/users/:id` |
| POST | `/api/admin/users/:id/points` |
| POST | `/api/admin/codes` |
| GET | `/api/admin/codes?unused=1` |
| GET | `/api/admin/orders` |
| GET/POST | `/api/admin/sources` |
| PATCH/DELETE | `/api/admin/sources/:id` |
| POST | `/api/admin/sources/:id/test` |
| GET/POST | `/api/admin/api-keys` |
| DELETE | `/api/admin/api-keys/:id` |
| GET | `/api/admin/audit` |

### 开放 API（第三方，`X-Api-Key`）

```bash
# 拉源列表
curl -H "X-Api-Key: isle_xxx" "https://ys.irepo.cn/open/v1/sources?kind=music"

# 代搜索
curl -H "X-Api-Key: isle_xxx" "https://ys.irepo.cn/open/v1/search?kw=夜航星"
```

返回：

```json
{
  "keyword": "夜航星",
  "results": [
    { "source": "网易云直连", "status": 200, "ms": 182, "data": { } }
  ]
}
```

## 源的配置格式

后台添加源时的字段：

| 字段 | 例子 | 说明 |
|---|---|---|
| 名称 | `网易云直连` | 显示名 |
| 地址 | `https://api.xxx.com/search?keyword={kw}` | `{kw}` 会被替换成搜索词 |
| 方法 | `GET` | GET / POST |
| 结果路径 | `result.songs` | 点号路径，从响应里取数组 |
| 额外参数 | `{"limit":20}` | 拼到 query 上 |
| 请求头 | `{"Referer":"https://music.163.com/"}` | 有的源校验 Referer |
| 排序 | `0` | 越小越先请求 |

音乐源 `status` 显示 200 是通的，`502/0` 是连不上，`403` 是被挡了 Referer。

## 数据与备份

数据全在 `./data/isle.db`（SQLite，WAL 模式）。

```bash
# 热备（不影响读写）
sqlite3 data/isle.db ".backup data/backup-$(date +%F).db"

# 还原
docker compose down
cp data/backup-2026-11-14.db data/isle.db
docker compose up -d
```

定时任务写 crontab：

```cron
0 4 * * * cd /opt/isle && sqlite3 data/isle.db ".backup data/backup-$(date +\%F).db" && find data -name 'backup-*.db' -mtime +14 -delete
```

## 排错

| 现象 | 查这里 |
|---|---|
| 502 | `docker compose logs isle` |
| 后台打不开 | `curl 127.0.0.1:8787/api/health`，端口没起就是容器挂了 |
| 兑换返回 `code_not_found` | 卡密大写，后台生成的是 `MT-XXXXXX` |
| 兑换返回 `code_used` | `codes.used_by` 已有值，别再发同一张 |
| Casdoor 报 `casdoor_token_failed` | client_secret 或 redirect_uri 对不上，回跳地址必须和 Casdoor 应用里一字不差 |
| 源测试 403 | 补 `Referer` 和 `User-Agent` 请求头 |

## 版本

v2.0.0 — 从 v1 拆出独立目录，不动 `server/`，可并行跑两套做灰度。
