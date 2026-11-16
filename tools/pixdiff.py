import sys,os
from PIL import Image,ImageChops
a,b=sys.argv[1],sys.argv[2];bad=[];noise=[]
for f in sorted(os.listdir(a)):
    pa,pb=os.path.join(a,f),os.path.join(b,f)
    if not os.path.exists(pb): bad.append((f,'missing'));continue
    ia,ib=Image.open(pa).convert('RGB'),Image.open(pb).convert('RGB')
    if ia.size!=ib.size: bad.append((f,'size',ia.size,ib.size));continue
    d=ImageChops.difference(ia,ib)
    if d.getbbox():
        mx=max(m for lo,m in d.getextrema()); n=sum(1 for p in d.convert('L').get_flattened_data() if p>0)
        (noise if (mx<=4 or n<=20) else bad).append((f,d.getbbox(),'px',n,'max',mx))
print(len(os.listdir(a)),'compared;',len(bad),'real differences;',len(noise),'antialiasing noise (<=20 px or <=4/255)')
for x in bad[:40]: print('DIFF',x)
for x in noise[:10]: print('noise',x)
