# 屿声音乐 · 服务端部署说明

接口域名：**https://ys.irepo.cn**
客户端里 `Config.apiBaseURL` 已指向这个地址，改域名只需改这一个常量。

---

## 一、五步上线

```bash
# 1. 上传
scp -r server root@你的服务器:/opt/isle/
cd /opt/isle/server

# 2. 装依赖（Node 20+）
npm install --omit=dev

# 3. 配置
cp .env.example .env
nano .env      # 三个密钥用 openssl rand -hex 32 生成，ADMIN_PASSWORD 自己定

# 4. 起服务（先手动跑一遍看日志）
node server.js
curl http://127.0.0.1:8787/api/health

# 5. 反代 + HTTPS
cp nginx.conf /etc/nginx/conf.d/ys.irepo.cn.conf
certbot --nginx -d ys.irepo.cn
nginx -s reload
```

用 Docker 更省事：

```bash
cp .env.example .env && nano .env
docker compose up -d --build
docker compose logs -f
```

systemd（不用 Docker 时）：

```ini
# /etc/systemd/system/isle.service
[Unit]
Description=Isle Music API
After=network.target
[Service]
WorkingDirectory=/opt/isle/server
EnvironmentFile=/opt/isle/server/.env
ExecStart=/usr/bin/node server.js
Restart=always
[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable --now isle
```

---

## 二、必改的五个环境变量

| 变量 | 作用 | 怎么生成 |
|---|---|---|
| `JWT_SECRET` | 登录 token 签名 | `openssl rand -hex 32` |
| `APP_SECRET` | 手机号 / 设备密钥加密 | `openssl rand -hex 32` |
| `STREAM_SECRET` | 播放票据签名 | `openssl rand -hex 32` |
| `ADMIN_PASSWORD` | 后台登录密码 | 自己定，别用弱密码 |
| `ALLOW_HOSTS` | 允许代理的音源域名白名单 | 按实际音源填，留空=不限（不推荐） |

`APP_SECRET` 一旦上线**不要改**，改了之后所有已加密的手机号和设备密钥都解不开。

---

## 三、后台怎么用

浏览器打开 `https://ys.irepo.cn/admin.html`，用 `ADMIN_PASSWORD` 登录。

- **生成卡密**：选 VIP/SVIP、天数（0=永久）、数量 → 生成后复制发给用户
- **用户表**：改角色（VIP30/SVIP30/降级）、封禁、看手机号、**加/扣积分**
- **签到与积分设置**：改第 1–6 天积分、第 7 天送什么、兑换价格，保存后立刻生效，不用重启

---

## 四、会员与权限

| 角色 | 能做什么 |
|---|---|
| `free` | 登录、改密码、看设置 |
| `vip` | 听歌、音源、视频源配置、收藏歌单、本地加密播放 |
| `svip` | 以上全部 ＋ 养眼视频 |

到期自动降级（`normalize()` 里做），下次请求就生效。

---

## 五、播放防盗链

1. 客户端调 `POST /api/play/ticket` 拿票据（音频需 vip、视频需 svip）
2. 拿到的是 `/stream/audio/<base64>?uid=&exp=&sig=`，**不是真实地址**
3. `/stream/*` 每次请求都重新校验签名 + 查数据库角色，封号/到期立刻 403
4. 上游域名受 `ALLOW_HOSTS` 限制，同时拦掉 `localhost` / `10.*` / `192.168.*` / `169.254.*` 防 SSRF

本地导入的音乐走 `POST /api/play/permit` 领 5 分钟通行证，播放中每 60 秒续签，续不上就停。

---

## 六、设备额度与换绑

- 默认每账号 3 台（`MAX_DEVICES_DEFAULT`，后台可给单用户单独调 `max_devices`）
- 自助解绑：进 24 小时宽限期（`DEVICE_UNBIND_GRACE_HOURS`），期内不能再解绑（`DEVICE_UNBIND_COOLDOWN_DAYS=30`）
- 管理员可强制失效某台设备、重置冷却

---

## 七、积分经济（默认值）

| 来源 | 数值 |
|---|---|
| 每日签到 | 10 / 10 / 15 / 15 / 20 / 20 |
| 连签 7 天 | 额外 1 天 VIP（后台可改成 SVIP 或积分） |
| 邀请成功 | 双方各 7 天 VIP |
| 兑换 | VIP 300/1000 分，SVIP 1000/6000 分（1/7 天） |

所有积分变动都写 `points` 账本（`reason` 区分 checkin/exchange/invite/admin），可追溯。

---

## 八、备份

```bash
# 每天 4 点备份数据库和头像
0 4 * * * tar czf /backup/isle-$(date +\%F).tgz /opt/isle/server/data
```

数据全在 `server/data/`：`data.db`（含 WAL）、`avatars/`。迁服务器整目录拷过去即可。

---

## 九、常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| App 提示「网络异常」 | 没走 HTTPS 或证书不对 | iOS ATS 要求 https，`certbot` 签好 |
| 播放 403 `need_svip` | 账号不是 SVIP | 后台发卡密或改角色 |
| 播放 502 `upstream_*` | 音源域名不在白名单 / 上游挂了 | 补 `ALLOW_HOSTS`，或换音源 |
| 拖动进度条卡住 | Nginx 开了 buffering | `/stream/` 加 `proxy_buffering off` |
| 装完 App 立刻掉登录 | `JWT_SECRET` 换过 | 别换，或让用户重登 |
| 头像传不上去 | 超过 512KB | 客户端已压到 512×512，检查是否走了压缩 |
