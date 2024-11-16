import os
import sys
import re

folder = sys.argv[1]
suffix = sys.argv[2]

for fname in os.listdir(sys.argv[1]):
  rename = re.sub(r'.*卷(\d+)\(.*', r'\g<1>%s.docx' % suffix, fname)
  os.rename('%s/%s' % (folder, fname), rename)
  print(fname, '=>', rename)
try:
  os.rmdir(folder)
except Exception:
  pass
