// node snap-previews.js <dsProjectDir> <outDir>
const {chromium}=require('playwright');const fs=require('fs');const path=require('path');
const [ds,out]=process.argv.slice(2).map(p=>path.resolve(p));fs.mkdirSync(out,{recursive:true});
const nm=path.resolve(__dirname,'node_modules');
(async()=>{const b=await chromium.launch();
for(const theme of ['light','dark']){const pg=await b.newPage({viewport:{width:420,height:400}});const errs=[];pg.on('pageerror',e=>errs.push(e.message));
 for(const c of fs.readdirSync(path.join(ds,'components'))){const pv=path.join(ds,'components',c,'preview.html');if(!fs.existsSync(pv))continue;
  const src=fs.readFileSync(pv,'utf8');const body=src.slice(src.indexOf('<body>')+6,src.indexOf('</body>'));
  const doc=`<!doctype html><html data-theme="${theme}"><head><meta charset="utf-8"><link rel="stylesheet" href="file://${ds}/tokens.css"><link rel="stylesheet" href="file://${ds}/components/bundle.css">
  <script src="file://${nm}/react/umd/react.production.min.js"></script><script src="file://${nm}/react-dom/umd/react-dom.production.min.js"></script><script src="file://${ds}/components/bundle.js"></script></head><body>${body}</body></html>`;
  const tmp=path.join(out,'__p.html');fs.writeFileSync(tmp,doc);await pg.goto('file://'+tmp,{waitUntil:'networkidle'});await pg.evaluate(()=>document.fonts.ready);await pg.waitForTimeout(150);
  await pg.screenshot({path:`${out}/${theme}-${c}.png`,fullPage:true});}
 if(errs.length)console.log(theme,'errors',errs);await pg.close();}
fs.unlinkSync(path.join(out,'__p.html'));await b.close();console.log('ok');})();
