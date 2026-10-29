#!/usr/bin/env bash
# Shiro-721 是"流程说明"型条目：没有一键脚本（每字节爆破都要带合法 cookie），
# 这里只把步骤与判定写清；照着 GUI 工具走一遍即可。
echo '# shiro-721：Padding Oracle 流程条目，按下面步骤用 shiro_attack / ShiroExploit 复现'
# Shiro-721 复现要点（工具化，不要手搓）
#
# 1) 前置：拿到一个合法 rememberMe cookie（登录后 / 或找一个已登录用户）
# 2) 工具：shiro_attack / ShiroExploit / ysoserial + padding_oracle.py
#    java -jar shiro_attack.jar
#      目标 URL:  http://TARGET:PORT/
#      合法 cookie: rememberMe=xxxx
#      链: CommonsBeanutils1 / CommonsCollections5
# 3) 原理：把 gadget 密文分 16 字节块，逐块爆破前一块密文，
#    以"服务端返回 deleteMe 与否"作为 oracle，最终得到可解密的合法密文。
# 4) 判定成功：DNSLOG / 回连端口收到目标发起的外连。
#
# 纪律：单目标探测请求数很大，务必限速（>=0.2s/请求），业务高峰不要跑。
