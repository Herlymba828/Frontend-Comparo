// node snap-all.js <proto.html> <wfProjectDir> <dsProjectDir> <outDir>
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');
const [protoF,wfDir,dsDir,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const src=fs.readFileSync(protoF,'utf8');
const html='<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"></head><body>'+src+'</body></html>';
(async()=>{const b=await chromium.launch();
for(const theme of ['light','dark']){
 const pg=await b.newPage({viewport:{width:1280,height:860},colorScheme:theme});await pg.setContent(html,{waitUntil:'networkidle'});await pg.evaluate(()=>document.fonts.ready);await pg.waitForTimeout(400);
 const ids=await pg.evaluate(()=>[...document.querySelectorAll('.nav .grp button')].map(b=>b.dataset.go));
 for(const id of ids){await pg.click(`.nav [data-go="${id}"]`);await pg.waitForTimeout(60);
  await pg.screenshot({path:`${out}/p-${theme}-${id}-a.png`});
  await pg.evaluate(()=>{const s=document.getElementById('scr');if(s)s.scrollTop=s.scrollHeight;});await pg.waitForTimeout(30);
  await pg.screenshot({path:`${out}/p-${theme}-${id}-b.png`});}
 await pg.close();}
// canvas screens
const tok=path.resolve(dsDir,'tokens.css'),bun=path.resolve(dsDir,'components/bundle.css');
const files=fs.readdirSync(wfDir).filter(f=>/^(HF|BO)-.*\.dc\.html$/.test(f));
for(const theme of ['light','dark']){
 const pg=await b.newPage({viewport:{width:390,height:844},colorScheme:theme});
 for(const f of files){let s=fs.readFileSync(path.join(wfDir,f),'utf8');
  const head=[...s.matchAll(/<link rel="stylesheet" href="([^"]+)">/g)].map(m=>m[1]).filter(h=>!h.startsWith('http')).map(h=>h==='ds/wf/tokens.css'?tok:h==='ds/wf/components/bundle.css'?bun:path.resolve(wfDir,h));
  const body=s.slice(s.indexOf('<x-dc>')+6,s.indexOf('</x-dc>')).replace(/<helmet>([\s\S]*?)<\/helmet>/,(m,g)=>g.replace(/<link[^>]*fonts[^>]*>/,''));
  const doc='<!doctype html><html><head><meta charset="utf-8">'+head.map(h=>'<link rel="stylesheet" href="file://'+h+'">').join('')+'</head><body'+(theme==='dark'?' data-theme="dark"':'')+'>'+body+'</body></html>';
  const tmp=path.resolve(wfDir,'__snap.html');fs.writeFileSync(tmp,doc.replace('<html>','<html'+(theme==='dark'?' data-theme="dark"':'')+'>'));
  const w=f.startsWith('BO-')?1280:390;await pg.setViewportSize({width:w,height:f.startsWith('BO-')?800:844});
  await pg.goto('file://'+tmp,{waitUntil:'networkidle'});await pg.evaluate(()=>document.fonts.ready);await pg.waitForTimeout(120);await pg.screenshot({path:`${out}/c-${theme}-${f.replace('.dc.html','')}.png`,fullPage:true});}
 await pg.close();}
fs.unlinkSync(path.resolve(wfDir,'__snap.html'));
await b.close();console.log('done',fs.readdirSync(out).length);})();
