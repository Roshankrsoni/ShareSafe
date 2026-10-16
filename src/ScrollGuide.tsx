import {useEffect,useState} from 'react';
import {ArrowRight,MessageCircle,X} from 'lucide-react';
import {track} from './analytics';
import {pricing,purchaseState} from './config';

type GuideStep = {id:string;eyebrow:string;title:string;text:string;cta?:{label:string;href:string}};

const STEPS: GuideStep[] = [
  {id:'demo',eyebrow:'You’re in the demo',title:'This is Detect — real captures.',text:'Local detection + OCR suggest sensitive details beside your doc. Nothing is uploaded.',cta:{label:'See the workflow',href:'#how-it-works'}},
  {id:'how-it-works',eyebrow:'What’s happening',title:'Open → Review → Redact → Export.',text:'Watch the 20-second walkthrough. Your original stays untouched; export writes a separate copy.',cta:{label:'Compare views',href:'#features'}},
  {id:'features',eyebrow:'Try this',title:'Drag the comparison slider.',text:'Left is Review, right is Protected. Solid masks replace pixels — blur alone isn’t enough.',cta:{label:'How review works',href:'#problem'}},
  {id:'problem',eyebrow:'Why it matters',title:'Briefs carry more than you meant.',text:'These are actual review + receipt panels. Every suggestion needs your call: Redact or Keep.'},
  {id:'specs',eyebrow:'Good to know',title:'Native tools, practical limits.',text:'macOS 14+, 40 pages / 25 MB max. OCR depends on scan quality. Image-only export, no searchable text.'},
  {id:'privacy',eyebrow:'Privacy check',title:'Everything runs on your Mac.',text:'No document uploads, no app account. You control sharing, backups, and the final inspect-before-send.'},
  {id:'pricing',eyebrow:'One-time purchase',title:'ShareSafe for $2.',text:'Checkout is available through Dodo Payments. App download delivery details are still being finalized.',cta:{label:purchaseState(pricing).label,href:purchaseState(pricing).href}},
  {id:'faq',eyebrow:'Before you share',title:'Plain answers, incl. tradeoffs.',text:'Detection can miss or over-flag. Export checks don’t certify completeness — always inspect the copy.'},
];

const DISMISS_KEY = 'sharesafe-guide-dismissed';

export default function ScrollGuide(){
  const [active,setActive] = useState(0);
  const [pastHero,setPastHero] = useState(false);
  const [dismissed,setDismissed] = useState(false);
  const [minimized,setMinimized] = useState(false);

  useEffect(()=>{
    try{if(sessionStorage.getItem(DISMISS_KEY)==='1'){setDismissed(true);return;}}catch{/* private mode */}
  },[]);

  useEffect(()=>{
    let raf = 0;
    const onScroll = ()=>{
      if(raf) return;
      raf = requestAnimationFrame(()=>{
        raf = 0;
        setPastHero(window.scrollY > Math.min(640, window.innerHeight * 0.7));
      });
    };
    onScroll();
    window.addEventListener('scroll',onScroll,{passive:true});
    return ()=>{window.removeEventListener('scroll',onScroll);if(raf)cancelAnimationFrame(raf);};
  },[]);

  useEffect(()=>{
    const sections = STEPS.map(s=>document.getElementById(s.id)).filter((el):el is HTMLElement=>!!el);
    if(!sections.length) return;
    let current = -1;
    const pick = ()=>{
      const mid = window.innerHeight * 0.45;
      let best = 0, bestDist = Infinity;
      sections.forEach((el,i)=>{
        const r = el.getBoundingClientRect();
        // Prefer section containing the viewport midpoint, else nearest
        const dist = (r.top <= mid && r.bottom >= mid) ? 0 : Math.min(Math.abs(r.top-mid),Math.abs(r.bottom-mid));
        if(dist < bestDist){bestDist = dist;best = i;}
      });
      if(best !== current){current = best;setActive(best);}
    };
    pick();
    let ticking = false;
    const onScroll = ()=>{if(ticking)return;ticking=true;requestAnimationFrame(()=>{ticking=false;pick();});};
    window.addEventListener('scroll',onScroll,{passive:true});
    window.addEventListener('resize',onScroll);
    return ()=>{window.removeEventListener('scroll',onScroll);window.removeEventListener('resize',onScroll);};
  },[]);

  useEffect(()=>{
    if(pastHero && !dismissed && !minimized) track('guide_view',{location:STEPS[active]?.id});
  },[active,pastHero,dismissed,minimized]);

  const dismiss = (permanent:boolean)=>{
    setDismissed(true);
    track('guide_dismiss',{location:STEPS[active]?.id});
    if(permanent){try{sessionStorage.setItem(DISMISS_KEY,'1');}catch{/* ignore */}}
  };

  if(dismissed || !pastHero){
    if(!pastHero || !dismissed) return null;
    return <button className="sg-fab" aria-label="Reopen ShareSafe guide" onClick={()=>{setDismissed(false);setMinimized(false);}}><MessageCircle size={18}/><span>Guide</span></button>;
  }

  if(minimized){
    return <button className="sg-fab" aria-label="Reopen ShareSafe guide" onClick={()=>setMinimized(false)}><MessageCircle size={18}/><span>{STEPS[active]?.eyebrow ?? 'Guide'}</span></button>;
  }

  const step = STEPS[active] ?? STEPS[0];
  return <aside className="scroll-guide" role="status" aria-live="polite" aria-label="ShareSafe scroll guide" key={step.id}>
    <div className="sg-card">
      <div className="sg-head">
        <span className="sg-avatar" aria-hidden="true"><img src="/favicon.svg" width="18" height="21" alt=""/></span>
        <div className="sg-head-text"><strong>ShareSafe guide</strong><span>{step.eyebrow} · {active+1}/{STEPS.length}</span></div>
        <div className="sg-head-actions">
          <button className="sg-icon" aria-label="Minimize guide" onClick={()=>setMinimized(true)}>—</button>
          <button className="sg-icon" aria-label="Dismiss guide" onClick={()=>dismiss(true)}><X size={15}/></button>
        </div>
      </div>
      <div className="sg-body" key={`${step.id}`}>
        <p className="sg-title">{step.title}</p>
        <p className="sg-text">{step.text}</p>
        {step.cta && <a className="sg-cta" href={step.cta.href} onClick={()=>track('guide_cta',{location:step.id})}>{step.cta.label}<ArrowRight size={14}/></a>}
      </div>
      <div className="sg-dots" role="tablist" aria-label="Guide sections">
        {STEPS.map((s,i)=><a key={s.id} href={`#${s.id}`} role="tab" aria-selected={i===active} aria-label={s.title} className={i===active?'on':''} onClick={()=>{setActive(i);track('guide_cta',{location:`dot-${s.id}`});}}><i/></a>)}
      </div>
    </div>
  </aside>;
}
