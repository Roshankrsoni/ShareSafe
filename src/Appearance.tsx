import {useEffect,useSyncExternalStore} from 'react';
import {Monitor,Moon,Sun} from 'lucide-react';
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
 document.querySelector('meta[name="theme-color"]')?.setAttribute('content',dark?'#080a0d':'#fafbfc');
}
function subscribeAppearance(notify:()=>void){window.addEventListener('sharesafe-appearance',notify);return()=>window.removeEventListener('sharesafe-appearance',notify);}
export function AppearanceControl(){
 const appearance=useSyncExternalStore(subscribeAppearance,getInitialAppearance,()=> 'system' as Appearance);
 useEffect(()=>{const media=window.matchMedia('(prefers-color-scheme: dark)');const update=()=>{if(getInitialAppearance()==='system')applyAppearance('system');};media.addEventListener('change',update);return()=>media.removeEventListener('change',update);},[]);
 const select=(value:Appearance)=>{try{if(value==='system')localStorage.removeItem('sharesafe-appearance');else localStorage.setItem('sharesafe-appearance',value);}catch{/* Appearance works without storage. */}applyAppearance(value);};
 return <label className="appearance-control"><span className="appearance-icon" aria-hidden="true">{appearance==='system'?<Monitor size={16}/>:appearance==='dark'?<Moon size={16}/>:<Sun size={16}/>}</span><span className="visually-hidden">Website appearance</span><select aria-label="Website appearance" value={appearance} onChange={event=>select(event.target.value as Appearance)}><option value="system">System</option><option value="light">Light</option><option value="dark">Dark</option></select></label>;
}
