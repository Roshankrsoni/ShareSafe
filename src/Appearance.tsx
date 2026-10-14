import {useEffect,useSyncExternalStore} from 'react';
import {Moon,Sun} from 'lucide-react';
type Appearance = 'system' | 'light' | 'dark';
function getInitialAppearance(): Appearance {
 if(typeof document==='undefined')return 'system';
 const preference=document.documentElement.dataset.themePreference;
 return preference==='light'||preference==='dark'?preference:'system';
}
function applyAppearance(preference:Appearance) {
 const dark=preference==='dark'||(preference==='system'&&window.matchMedia('(prefers-color-scheme: dark)').matches);
 document.documentElement.dataset.theme=dark?'dark':'light';
 document.documentElement.dataset.themePreference=preference;
 window.dispatchEvent(new CustomEvent('sharesafe-appearance',{detail:preference}));
 document.documentElement.style.colorScheme=dark?'dark':'light';
 document.querySelector('meta[name="theme-color"]')?.setAttribute('content',dark?'#0f0f10':'#fafaf9');
}
function subscribeAppearance(notify:()=>void){window.addEventListener('sharesafe-appearance',notify);return()=>window.removeEventListener('sharesafe-appearance',notify);}
export function AppearanceControl(){
 const appearance=useSyncExternalStore(subscribeAppearance,getInitialAppearance,()=> 'light' as Appearance);
 useEffect(()=>{const media=window.matchMedia('(prefers-color-scheme: dark)');const update=()=>{if(getInitialAppearance()==='system')applyAppearance('system');};media.addEventListener('change',update);return()=>media.removeEventListener('change',update);},[]);
 const dark=appearance==='dark'||(appearance==='system'&&typeof window!=='undefined'&&window.matchMedia('(prefers-color-scheme: dark)').matches);
 const next=dark?'light':'dark';
 const toggle=()=>{try{localStorage.setItem('sharesafe-appearance',next);}catch{/* Appearance works without storage. */}applyAppearance(next);};
 return <button type="button" className="appearance-control" aria-label={`Switch to ${next} mode`} title={`Switch to ${next} mode`} aria-pressed={dark} onClick={toggle}><span className="appearance-icon" aria-hidden="true">{dark?<Sun size={17}/>:<Moon size={17}/>}</span></button>;
}
