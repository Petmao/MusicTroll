#!/usr/bin/env python3
import io
import sys


def load(p):
    with io.open(p, encoding='utf-8') as f:
        return f.read()


def save(p, s):
    with io.open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def sub(s, old, new, label):
    if old not in s:
        if new and new in s:
            print('SKIP ' + label)
            return s
        print('MISS ' + label)
        sys.exit(1)
    print('OK   ' + label)
    return s.replace(old, new, 1)


p = 'server-v2/public/admin.html'
s = load(p)

s = sub(s, '''      tr.innerHTML = '<td>' + u.id + '</td><td class="mono">' + esc(u.account) + '</td><td>' + esc(u.nickname) + '</td><td>' + esc(u.role) + '</td><td>' + exp + '</td><td>' + u.points + '</td>' +
        '<td><button class="ghost" onclick="grantVip(' + u.id + ')">加VIP</button> <button class="ghost" onclick="givePoints(' + u.id + ')">加积分</button></td>';''',
    '''      var roleTag = u.role === 'svip' ? '<span class="tag" style="background:rgba(240,205,140,.2);color:#f0cd8c">SVIP</span>'
        : (u.role === 'vip' ? '<span class="tag ok">VIP</span>' : '<span class="tag">free</span>');
      tr.innerHTML = '<td>' + u.id + '</td><td class="mono">' + esc(u.account) + '</td><td>' + esc(u.nickname) + '</td><td>' + roleTag + '</td><td>' + exp + '</td><td>' + u.points + '</td>' +
        '<td><button class="ghost" onclick="grantRole(' + u.id + ', &#39;vip&#39;)">VIP</button> ' +
        '<button class="ghost" onclick="grantRole(' + u.id + ', &#39;svip&#39;)">SVIP</button> ' +
        '<button class="ghost" onclick="grantRole(' + u.id + ', &#39;free&#39;)">降级</button> ' +
        '<button class="ghost" onclick="givePoints(' + u.id + ')">加积分</button></td>';''', 'admin 用户行加 SVIP')

s = sub(s, '''function grantVip(id) {
  var days = prompt('天数', '30');
  if (!days) return;
  api('/api/admin/users/' + id, { method: 'PATCH', body: { role: 'vip', days: Number(days) } })
    .then(function () { loadUsers(''); }).catch(function (e) { alert(e.message); });
}''',
    '''function grantRole(id, role) {
  var days = '0';
  if (role !== 'free') {
    days = prompt('给多少天（负数为扣减）', '30');
    if (days === null) return;
    if (!Number(days)) { alert('天数要写数字'); return; }
  }
  api('/api/admin/users/' + id, {
    method: 'PATCH',
    body: { role: role, days: Number(days) }
  })
    .then(function () { loadUsers(''); })
    .catch(function (e) { alert(e.message); });
}''', 'admin grantRole')

save(p, s)
print('admin.html done')
print('PATCH25 DONE')
