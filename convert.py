import zipfile
import re
import os
import glob
import shutil

for fname in glob.glob('*docx'):
  base = fname.split('.')[0]
  with zipfile.ZipFile(fname, 'r') as ref:
    ref.extractall(base)
  doc = open('%s/word/document.xml' % base, encoding="utf-8").read()
  doc = re.sub(r'<[^a][^>]+>', '', doc)
  doc = re.sub(r'<a[^:]+:[^>]+>', '', doc)
  doc = re.sub(r'<a:[^b][^>]+>', '', doc)
  doc = doc.strip().replace(' cstate="print"', '')
  #doc = re.sub(r'(.{80})', r'\g<1>\n', doc)
  idx = 50
  ret = []
  while True:
    if idx >= len(doc):
      ret.append(doc)
      break
    while doc[idx] in '<a:blip r:embed="rId1234567890"/>':
      idx += 1
    idx += 1
    ret.append(doc[:idx])
    doc = doc[idx:]
    idx = 50
  open('%s.txt' % base, 'w', encoding="utf-8").write('\n'.join(ret))
  doc = open('%s/word/_rels/document.xml.rels' % base).read()
  match = re.findall(r'Id="(rId\d+)" Type="[^"]+" Target="media/(image\d+.png)"', doc)
  if match:
    open('%s.csv' % base, 'w').write('\n'.join([','.join(x) for x in match]))
    os.rename('%s/word/media' % base, '%s_media' % base)
  shutil.rmtree(base)
