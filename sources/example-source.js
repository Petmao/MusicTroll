// 屿声音乐 · 音源脚本模板
// 把这个文件托管到你能访问的地址（比如 https://ys.irepo.cn/source.js），
// 然后在 后台 → 音源/视频源 → 添加，类型选「音乐音源」，地址填那个 URL。
//
// App 侧会 new JSContext，加载本文件，然后调用下面的三个函数。
// 脚本里可以用 nativeHttpGet(url) 同步发 GET（返回字符串），不需要 Promise。

// ---------- 1) 搜索（必须实现）----------
// 入参：keyword 字符串
// 返回：JSON 数组字符串，每项 { title, artist, url }（url 可留空，之后由 getUrl 补）
function search(keyword) {
  // 把这里换成你自己的接口
  var api = "https://你的接口地址/search?keywords=" + encodeURIComponent(keyword);
  var raw = nativeHttpGet(api);
  if (!raw) return "[]";

  var data = JSON.parse(raw);
  var list = (data.data || data.result || []).map(function (x) {
    return {
      title: x.name || x.title || "",
      artist: x.singer || x.artist || "",
      id: x.id || x.songmid || "",
      url: x.url || ""
    };
  });
  return JSON.stringify(list);
}

// ---------- 2) 取播放地址（可选）----------
// 如果 search 已经把 url 填好了，这个函数可以删掉
// 入参：trackJson（search 返回的单条对象序列化后的字符串）
// 返回：可直接播放的地址字符串（mp3/m4a/flac 直链，或 m3u8）
function getUrl(trackJson) {
  var t = JSON.parse(trackJson);
  var api = "https://你的接口地址/url?id=" + encodeURIComponent(t.id || "");
  var raw = nativeHttpGet(api);
  if (!raw) return "";
  var d = JSON.parse(raw);
  return d.url || (d.data && d.data.url) || "";
}

// ---------- 3) 榜单（可选，接上后首页显示真榜单）----------
// 返回：JSON 对象字符串，键是榜单名，值是歌曲数组
// 首页会按「飙升榜 / 热歌榜 / 新歌榜 / DJ 专区」四张卡显示，名称对上就直接替换示例数据
function charts() {
  var out = {};

  var up = nativeHttpGet("https://你的接口地址/toplist?id=up");
  if (up) {
    out["飙升榜"] = (JSON.parse(up).songs || []).map(function (x) {
      return { title: x.name || x.title, artist: x.singer || x.artist, url: x.url || "" };
    });
  }

  // 热歌榜 / 新歌榜 / DJ 专区 同理，没有就跳过，首页会保留示例数据
  return JSON.stringify(out);
}

// ---------- 小工具（可选）----------
// 有些接口返回带 callback 的 jsonp，可以这样剥掉外壳：
function stripJsonp(s) {
  var a = s.indexOf("(");
  var b = s.lastIndexOf(")");
  if (a >= 0 && b > a) return s.slice(a + 1, b);
  return s;
}
