const {chromium}=require('playwright');const fs=require('fs');
const src=fs.readFileSync(process.argv[2],'utf8');
const html='<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"></head><body>'+src+'</body></html>';
(async()=>{const b=await chromium.launch();const pg=await b.newPage({viewport:{width:1280,height:860}});const errs=[];pg.on('pageerror',e=>errs.push(e.message));
await pg.setContent(html);await pg.waitForTimeout(300);
const ids=await pg.evaluate(()=>[...document.querySelectorAll('.nav .grp button')].map(b=>b.dataset.go));
for(const id of ids){await pg.click(`.nav [data-go="${id}"]`);await pg.waitForTimeout(40);const ov=await pg.evaluate(()=>{const s=document.getElementById('scr');return s?s.scrollWidth>s.clientWidth+2:false});if(ov)errs.push('overflow:'+id);}
// flow: publish -> validate -> fiche
await pg.click('.nav [data-go="m-publier"]');await pg.fill('#pub-price','4800');await pg.click('#f-publish button[type=submit]');
await pg.click('.nav [data-go="bo-validation"]');await pg.click('[data-act="bo-pub"]');
await pg.click('.nav [data-go="fiche"]');await pg.waitForTimeout(100);
const best=await pg.evaluate(()=>document.querySelector('.tag.big-tag')?.textContent);
await pg.screenshot({path:'shots/proto-fiche.png'});
const m=await b.newPage({viewport:{width:390,height:844},deviceScaleFactor:1});await m.setContent(html);await m.waitForTimeout(200);await m.screenshot({path:'shots/proto-mobile.png'});
console.log('screens',ids.length,'best after publish',best,'errors',JSON.stringify(errs));await b.close();})();
