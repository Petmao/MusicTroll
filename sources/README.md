# 音源怎么加（Important）

屿声音乐本身**不含任何音乐内容**，它只是一个播放器。要能听歌，必须给它一个「音源脚本」。

- 引擎：`Isle/Sources/ScriptRunner.swift`（JavaScriptCore）
- 取源：`GET /api/sources?kind=music`（后台配置的 URL 列表）
- 取播放：脚本返回地址 → `POST /api/play/ticket` 换签名票据 → `/stream/...` 代理

## 三步

**1. 准备脚本**

拿 `sources/example-source.js` 改三处：
- `search()` 里的接口地址
- `getUrl()` 里的取流地址（若 search 已给 url 可删）
- `charts()` 里的榜单地址（可选，接上首页就是真榜单）

**2. 托管**

传到你的服务器任意静态位置，例如：

```
/www/wwwroot/isle/server/public/source.js
→ https://ys.irepo.cn/source.js
```

检查：浏览器直接打开该地址应能看到 JS 源码。

**3. 后台添加**

`/admin.html` → 音源/视频源 → 类型「音乐音源」→ 名称随意 → 地址填上一步的 URL → 添加并测速。
绿点表示可达；之后 App「我的 → 音乐音源」里能看到它。

## 脚本接口约定

| 函数 | 入参 | 返回 | 必需 |
|---|---|---|---|
| `search(keyword)` | 关键词 | JSON 数组字符串 `[{title,artist,url?}]` | ✅ |
| `getUrl(trackJson)` | 单条 track 的 JSON | 播放直链（mp3/m4a/flac/m3u8） | 可选 |
| `charts()` | 无 | JSON 对象字符串 `{"飙升榜":[{title,artist}]}` | 可选 |

脚本内可用：
- `nativeHttpGet(url)` → 同步 GET，返回字符串；失败返回空串

## 关于「QQ / 网易云 / 酷狗 / 汽水 / 抖音」现成脚本

这些平台的接口没有公开文档，需要签名参数与设备指纹，社区脚本（LX Music、MusicFree 插件）常随平台改版失效。本项目不内置，原因有二：

1. 涉及平台接口与版权，由你自己决定接哪个源；
2. 内置的脚本一两个月就会失效，反而更难维护。

要做的是：找一份你信任的 JS 源（或自己写），按上面的约定包一层 `search/getUrl/charts`，托管后填进后台即可。
