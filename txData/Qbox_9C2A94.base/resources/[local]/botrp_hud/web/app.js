const hud=document.getElementById('hud');
const $=id=>document.getElementById(id);
const setText=(id,value)=>{const el=$(id);if(el)el.textContent=value??''};
window.addEventListener('message',(event)=>{
 const d=event.data||{};
 if(d.action==='hide'){hud.classList.remove('visible');return}
 if(d.action!=='update')return;
 setText('cash',d.cash);setText('bank',d.bank);
 setText('job',`${d.job||'Civilian'} · ${d.grade||'Freelancer'}`);
 setText('health',`${d.health??0}%`);setText('armor',`${d.armor??0}%`);
 setText('needs',d.needs==null?'--%':`${d.needs}%`);
 setText('voice',d.radio?'Radio':(d.voice||'Normal'));
 setText('ping',`${d.ping??0} ms`);
 hud.classList.toggle('speaking',d.speaking===true);
 hud.classList.toggle('radio',d.radio===true);
 hud.classList.add('visible');
});
