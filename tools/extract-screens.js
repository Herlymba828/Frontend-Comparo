// node extract-screens.js <prototype.html> <sortie.json> <écran>[@bascule] …   ex. accueil@t-first
const {chromium}=require('playwright');const fs=require('fs');
const src=fs.readFileSync(process.argv[2],'utf8');const out=process.argv[3];
(async()=>{const b=await chromium.launch();const res={};
for(const spec of process.argv.slice(4)){const [id,tg]=spec.split('@');
 const pg=await b.newPage({viewport:{width:390,height:844}});await pg.setContent(src);await pg.waitForTimeout(300);
 if(tg)await pg.evaluate(t=>{const e=document.getElementById(t);e.checked=true;e.dispatchEvent(new Event('change',{bubbles:true}));},tg);
 await pg.evaluate(i=>{location.hash=i},id);await pg.waitForTimeout(250);
 res[spec]=await pg.evaluate(()=>{const ph=document.getElementById('phone').cloneNode(true);ph.querySelectorAll('.demo,.toast').forEach(e=>e.remove());return ph.innerHTML;});
 await pg.close();}
fs.writeFileSync(out,JSON.stringify(res));await b.close();})();
