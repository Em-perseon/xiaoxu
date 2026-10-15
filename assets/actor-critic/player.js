(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const bounds = [0, 6, 10, 15, 20, 42, 55, 59];
  const duration = 59, total = duration * 3;
  const chapters = ['生成','评分','计算回报','比较预期','更新 Actor','更新 Critic','学到了什么'];
  let time = 0, reward = 1, firstReward = 1, playing = false, previous = null, frame;
  const clamp = x => Math.max(0,Math.min(1,x));
  const ease = x => { x=clamp(x); return x*x*(3-2*x); };
  const lerp = (a,b,t) => a+(b-a)*ease(t);
  const sign = n => (n>=0?'+':'')+n.toFixed(1);
  const green = '#247b69', red = '#bd6258', gold = '#ac7538';
  const color = () => reward ? green : red;
  const text = (x,y,s,cls='',fill='') => `<text x="${x}" y="${y}" class="${cls}"${fill?` style="fill:${fill}"`:''}>${s}</text>`;
  const character = (kind,x,y,scale=1) => `<g transform="translate(${x} ${y}) scale(${scale})"><ellipse cy="104" rx="70" ry="10" fill="#dce3d9" opacity=".5"/><use href="#${kind}"/></g>`;
  const token = (x,y,word,scale=1,opacity=1) => `<g transform="translate(${x} ${y}) scale(${scale})" opacity="${opacity}"><rect x="-55" y="-43" width="110" height="86" rx="17" fill="white" stroke="#b4cfc2" stroke-width="2"/>${text(0,13,word,'token-word')}</g>`;
  const badge = (x,y,label,c,scale=1) => `<g transform="translate(${x} ${y}) scale(${scale})"><circle r="37" fill="${c}"/>${text(0,label.length>1?10:12,label,label.length>1?'number compact':'number','white')}</g>`;
  const path = d => `<path d="${d}" fill="none" stroke="#bbc8c0" stroke-width="2" stroke-dasharray="6 9" marker-end="url(#arrow)"/>`;
  function signal(x1,y1,x2,y2,p,c,amount=1) {
    let s='';
    for(let j=0;j<amount;j++) { const q=clamp(p-j*.09); if(q>0&&q<1)s+=`<circle cx="${lerp(x1,x2,q)}" cy="${lerp(y1,y2,q)-35*Math.sin(q*Math.PI)}" r="${7-j*.5}" fill="${c}" opacity="${1-j*.12}"/>`; }
    return s;
  }
  function render() {
    const round = Math.min(2, Math.floor(time / duration)), local = time - round * duration;
    const history = ActorCriticModel.rounds(firstReward), current = history[round];
    reward = current.reward;
    let scene=bounds.findIndex((b,i)=>local>=b&&local<bounds[i+1]); if(scene<0)scene=6;
    const t=local-bounds[scene], data=current.data, last=reward?'4':'5', words=['答案','是',last];
    let s='',caption='',subtitle='';
    if(scene===0) {
      caption=round?'带着上轮学到的，再试一次':'先让 Actor 试着回答'; subtitle=`第 ${round+1} 轮 · 问题：2 + 2 = ?`;
      s=character('robot',155,270)+text(155,410,'Actor','label')+path('M235 270H790');
      words.forEach((w,i)=>{const p=ease((t-i*1.3-.4)/.9);s+=token(lerp(235,380+i*170,p),270-35*Math.sin(p*Math.PI),w,.5+.5*p,p);});
      s+=text(535,160,'一个接一个，生成 token','small');
    } else if(scene===1) {
      caption='答完了，才知道得了几分'; subtitle= t<1.5?'评判器检查最终答案':reward?'答对：奖励 1':'答错：奖励 0';
      s=character('robot',145,265)+text(145,405,'Actor','label')+character('judge',755,265)+text(755,405,'评判器','label');
      s+=path('M235 265H655');
      s+=`<g transform="translate(${lerp(355,480,t/1.5)} 260)"><rect x="-120" y="-50" width="240" height="100" rx="20" fill="white" stroke="#b4cfc2" stroke-width="2"/>${text(0,13,`答案是 ${last}`,'token-word')}</g>`;
      if(t>1.5) {let p=ease((t-1.5)/.5);s+=`<g transform="translate(780 205) rotate(-12) scale(${p})"><circle r="46" fill="${color()}"/>${text(0,18,reward?'✓':'×','token-word','white')}</g>`;s+=badge(480,390,String(reward),color(),p);}
    } else if(scene===2) {
      caption='这次结果，成为每一步的回报';subtitle='γ = 1，每一步的回报都等于最终奖励';
      const xs=[220,450,680];
      xs.forEach((x,i)=>{s+=token(x,145,words[i])+text(x,80,`第 ${i+1} 步`,'small');s+=path(`M450 415Q${x} 380 ${x} 265`);const p=(t-i*.55-.5)/1.4;s+=signal(450,415,x,255,p,color(),4);if(p>=1)s+=badge(x,255,String(reward),color())+text(x,320,'回报','small');});
      s+=badge(450,425,String(reward),color());
    } else if(scene===3) {
      caption='实际结果，和预想差多少？';subtitle='优势 = 回报 − 旧预估';
      s=character('critic',112,310,.8)+text(112,440,'Critic','label');
      data.forEach((r,i)=>{const x=325+i*200,p=ease((t-i*.35)/1.2),base=370,h=180;
        s+=text(x,70,words[i],'label');s+=`<rect x="${x-32}" y="${base-h}" width="64" height="${h}" rx="16" fill="#edf0e7"/><rect x="${x-32}" y="${base-h*r.value}" width="64" height="${h*r.value}" rx="12" fill="#d9b785"/>`;
        s+=text(x,411,`预估 ${r.value.toFixed(1)}`,'small');
        const yy=base-h*reward;s+=`<path d="M${x-52} ${yy}H${x+52}" stroke="${color()}" stroke-width="4" opacity="${p}"/>`;
        const old=base-h*r.value;s+=`<path d="M${x+51} ${old}h12V${lerp(old,yy,p)}h-12" fill="none" stroke="${color()}" stroke-width="3"/>`;
        if(t>1.5+i*.35)s+=badge(x,125,sign(r.advantage),color(),.85);
      });
      s+=text(560,475,`横线：实际回报 ${reward}`,'small',color());
    } else if(scene===4) {
      const r=data[2], p=clamp((t-12)/4), q=lerp(current.before,current.after,p);
      const z=Math.log(r.probability/(1-r.probability)), dz=.5*r.advantage*(1-r.probability);
      caption=t<9?'为什么要改变这个答案的概率？':`下次：选 ${last} 的概率${reward?'上升':'下降'}`;
      subtitle=t<9?'目标是提高期望回报；优势告诉策略，这次选择比预期好还是差':'先更新倾向分数 z，再由 sigmoid 换算概率；不是直接加上优势';
      if(t<9) {
        s=character('robot',155,275,1.05)+text(155,425,'Actor','label');
        s+=text(570,65,`同一状态：问题 +「答案是」；本轮选了 ${last}`,'small');
        s+=text(570,130,`A = G − V旧 = ${reward} − ${r.value.toFixed(2)} = ${r.advantage.toFixed(2)}`,'label',color());
        s+=text(570,205,'策略损失 L = −A × ln p','label');
        s+=text(570,245,`p 是此状态下选 ${last} 的概率；更新时 A 固定`,'small');
        s+=text(570,315,reward?'A > 0：p 越大，L 越小':'A < 0：p 越小，L 越小','label',color());
        s+=text(570,365,reward?'降低损失 → 提高这次选择的概率':'降低损失 → 降低这次选择的概率','label');
        s+=text(570,445,'A = 0 时，这一项不推动策略更新','small');
      } else {
      s=character('robot',155,265,1.12)+text(155,425,'Actor','label');
      s+=text(575,35,'z新 = z旧 + α A (1 − p旧)','label');
      s+=text(575,70,`α = 0.5；p新 = sigmoid(z新) = 1 / (1 + exp(−z新))`,'small');
      [4,5].forEach((n,i)=>{const x=425+i*290; s+=token(x,156,String(n));if(String(n)===last)s+=`<rect x="${x-66}" y="102" width="132" height="108" rx="24" fill="none" stroke="${color()}" stroke-width="4"/>`;
        s+=text(x,244,String(n)===last?'本轮选中':'另一个候选','small');});
      s+=text(575,295,`z：${z.toFixed(3)} ${dz>=0?'+':'−'} ${Math.abs(dz).toFixed(3)} = ${(z+dz).toFixed(3)}`,'label',color());
      s+=signal(350,295,215,235,(t-10)/2,color(),4);
      const x=340,w=470,y=332;
      s+=`<rect x="${x}" y="${y}" width="${w}" height="48" rx="12" fill="#e6c8b8"/><path d="M${x+12} ${y}H${x+w*q}V${y+48}H${x+12}Q${x} ${y+48} ${x} ${y+36}V${y+12}Q${x} ${y} ${x+12} ${y}" fill="${green}"/><path d="M${x+w*current.before} ${y-10}v68" stroke="#253c34" stroke-width="2" stroke-dasharray="4 4"/>`;
      s+=text(425,423,`4：${(q*100).toFixed(1)}%`,'label',green)+text(715,423,`5：${((1-q)*100).toFixed(1)}%`,'label',red);
      s+=text(575,474,`虚线是更新前 · 选 ${last}：${(r.probability*100).toFixed(1)}% → ${(lerp(r.probability,r.newProbability,p)*100).toFixed(1)}%`,'small');
      }
    } else if(scene===5) {
      caption=reward?'预估偏低了，向实际回报调高':'预估偏高了，向实际回报调低';
      subtitle='这里每次修正一半差距（学习率 α = 0.5），不把一次经历当成永远的答案';
      s=text(450,35,'V新 = V旧 + α × (G − V旧)','label');
      s+=text(450,70,`V：预估回报　G：本轮实际回报 ${reward}　α：每次修正的比例`,'small');
      s= s+character('critic',140,280,.95)+text(140,420,'Critic','label');
      const states=['只有问题 → 生成「答案」前','问题 +「答案」→ 生成「是」前',`问题 +「答案是」→ 生成「${last}」前`];
      data.forEach((r,i)=>{const y=162+i*118,p=clamp((t-2-i*1.2)/2.5),value=lerp(r.value,r.newValue,p),x=330,w=450;
        s+=text(555,y-31,states[i],'small');
        s+=`<path d="M${x} ${y}H${x+w}" stroke="#dce3d9" stroke-width="10" stroke-linecap="round"/><path d="M${x+w*value} ${y}H${x+w*reward}" stroke="${color()}" stroke-width="4" opacity=".25"/>`;
        s+=`<circle cx="${x+w*r.value}" cy="${y}" r="12" fill="none" stroke="${gold}" stroke-width="2" stroke-dasharray="3 3"/><circle cx="${x+w*value}" cy="${y}" r="12" fill="${gold}"/><path d="M${x+w*reward} ${y-15}v30" stroke="${color()}" stroke-width="4"/>`;
        s+=text(555,y+39,`${r.value.toFixed(2)} + 0.5 × (${reward} − ${r.value.toFixed(2)}) = ${r.newValue.toFixed(2)}`,'small',gold);
      });
      s+=text(450,490,'虚线圆：旧预估　实心圆：调整过程　红/绿线：实际回报','small');
    } else {
      caption=round===2?'三轮经历，留在了模型里':'这一轮结束，学习不会清零';subtitle=round===2?'概率影响选择，但不保证每次都答对':'下一轮沿用刚更新的概率与价值预估';
      s=character('robot',280,235,1.25)+character('critic',620,235,1.25);
      s+=text(280,410,'Actor','label')+text(620,410,'Critic','label');
      s+=text(280,455,`P(4) = ${(current.after*100).toFixed(1)}%`)+text(620,455,`V = ${data[2].newValue.toFixed(2)}`);
      s+=`<path d="M330 100Q450 25 570 100" fill="none" stroke="#b4cfc2" stroke-width="3" stroke-dasharray="8 8"/>`;
    }
    $('scene').innerHTML=s; if($('caption').textContent!==caption)$('caption').textContent=caption;
    const stamp = n => `${String(Math.floor(n/60)).padStart(2,'0')}:${String(Math.floor(n%60)).padStart(2,'0')}`;
    $('subtitle').textContent=subtitle;$('seek').value=time;$('time').textContent=`${stamp(time)} / ${stamp(total)}`;$('chapter').textContent=`${scene+1} / 7 · ${chapters[scene]}`;
    document.querySelectorAll('[data-round]').forEach(b=>b.setAttribute('aria-pressed',String(Number(b.dataset.round)===round)));
    $('next').disabled=time>=total;$('play').textContent=playing?'Ⅱ 暂停':time>=total?'↺ 再看一次':'▶ 播放';
  }
  function tick(now) { if(!playing)return;if(previous!==null)time=Math.min(total,time+(now-previous)/1000);previous=now;if(time>=total)playing=false;render();if(playing)frame=requestAnimationFrame(tick); }
  function pause(){playing=false;previous=null;cancelAnimationFrame(frame);render();}
  function play(){if(time>=total)time=0;playing=true;previous=null;render();frame=requestAnimationFrame(tick);}
  $('play').addEventListener('click',()=>playing?pause():play());
  $('replay').addEventListener('click',()=>{pause();time=0;play();});
  $('seek').addEventListener('input',()=>{const next=Number($('seek').value);pause();time=next;render();});
  $('next').addEventListener('click',()=>{pause();const start=Math.min(2,Math.floor(time/duration))*duration;const local=time-start;const i=bounds.findIndex(b=>b>local+.01);if(local>=20&&local<29)time=start+40;else if(i===4)time=start+20;else time=i>=0&&i<7?start+bounds[i]+(bounds[i+1]-bounds[i])*.9:Math.min(total,start+duration);render();});
  document.querySelectorAll('[data-round]').forEach(b=>b.addEventListener('click',()=>{pause();time=Number(b.dataset.round)*duration;render();}));
  for(const [id,r] of [['success',1],['failure',0]]) $(id).addEventListener('click',()=>{pause();firstReward=r;time=0;$('success').setAttribute('aria-pressed',String(r===1));$('failure').setAttribute('aria-pressed',String(r===0));render();});
  document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
  $('seek').max=total;
  render();
})();
