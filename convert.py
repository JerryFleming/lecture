import zipfile
import re
import os
import glob
import shutil
import sys

base_string = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
def to_base(num, base):
  ret = ''
  while num:
    ret += base_string[num % base]
    num //= base
  return ret[::-1] or '0'

def rep(x):
  if not isinstance(x, tuple):
    fnd = x.group(1)
  else:
    fnd = x[0]
  if len(fnd) > 1:
    fnd = to_base(int(fnd), len(base_string))
  if not isinstance(x, tuple):
    return fnd
  else:
    return fnd, x[1]

for fname in sorted(glob.glob('*docx')):
  base = fname.split('.')[0]
  with zipfile.ZipFile(fname, 'r') as ref:
    ref.extractall(base)
  doc = open('%s/word/document.xml' % base, encoding="utf-8").read()
  doc = re.sub(r'<[^a][^>]+>', '', doc)
  doc = re.sub(r'<a[^:]+:[^>]+>', '', doc)
  doc = re.sub(r'<a:[^b][^>]+>', '', doc)
  doc = doc.strip().replace(' cstate="print"', '')
  doc = re.sub(r'<a:blip r:embed="rId(\d+)"/>', rep, doc)
  doc = re.sub(r'[ 　]*', r'', doc)
  doc = re.sub(r'(.{%s})' % sys.argv[1], r'\g<1>\n', doc)
  open('%s.txt' % base, 'w', encoding="utf-8").write(doc)
  doc = open('%s/word/_rels/document.xml.rels' % base).read()
  match = re.findall(r'Id="rId(\d+)" Type="[^"]+" Target="media/(image\d+.png)"', doc)
  if match:
    open('%s.csv' % base, 'w').write('\n'.join([','.join(rep(x)) for x in match]) + '\n')
    folder = '%s_media' % base
    if os.path.exists(folder):
      shutil.rmtree(folder)
    os.rename('%s/word/media' % base, folder)
  shutil.rmtree(base)
