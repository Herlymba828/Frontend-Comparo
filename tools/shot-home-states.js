const {chromium}=require('playwright');const fs=require('fs');
const src=fs.readFileSync(process.argv[2],'utf8');const out=process.argv[3];
(async()=>{const b=await chromium.launch();
async function toggle(pg,id){await pg.evaluate(id=>{const t=document.getElementById(id);if(!t)throw new Error('pas de bascule '+id);t.checked=!t.checked;t.dispatchEvent(new Event('change',{bubbles:true}));},id);await pg.waitForTimeout(150);}
async function go(pg,h){await pg.evaluate(h=>{location.hash=h},h);await pg.waitForTimeout(200);}
for(const [name,setup,dark] of [['normal',null,false],['sans-liste','emptycart',false],['premier','t-first',false],['hors-connexion','t-off',false],['reseau-lent','t-slow',false],['normal-sombre',null,true]]){
 const pg=await b.newPage({viewport:{width:390,height:844},colorScheme:dark?'dark':'light'});await pg.setContent(src,{waitUntil:'networkidle'});await pg.evaluate(()=>document.fonts.ready);await pg.waitForTimeout(300);
 if(setup==='emptycart'){await go(pg,'panier');for(let i=0;i<10;i++){const q=await pg.$('[data-act="qty"][data-d="-1"]');if(!q)break;await q.click();await pg.waitForTimeout(80);}}
 else if(setup){await toggle(pg,setup);}
 await go(pg,'accueil');
 await pg.screenshot({path:`${out}/${name}-a.png`});
 await pg.evaluate(()=>{const s=document.getElementById('scr');s.scrollTop=s.scrollHeight;});await pg.waitForTimeout(100);
 await pg.screenshot({path:`${out}/${name}-b.png`});await pg.close();}
await b.close();})();
