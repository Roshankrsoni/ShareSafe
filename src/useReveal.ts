import { useEffect } from 'react';
export function useReveal(){
 useEffect(()=>{
  const media=matchMedia('(prefers-reduced-motion: reduce)');
  const elements=document.querySelectorAll('.section-heading,.showcase-heading,.feature-main,.feature-small,.privacy-copy,.privacy-facts article,.pricing-intro,.price-card,.faq-section,.final-cta,.workflow-film');
  const observer=new IntersectionObserver(entries=>{for(const entry of entries)if(entry.isIntersecting){entry.target.classList.remove('is-queued');entry.target.classList.add('has-entered');observer.unobserve(entry.target);}},{threshold:.08});
  if(!media.matches)elements.forEach((element,index)=>{element.classList.add('motion-reveal');if(element.getBoundingClientRect().top>innerHeight){element.classList.add('is-queued');(element as HTMLElement).style.setProperty('--reveal-delay',`${index%2*70}ms`);}observer.observe(element);});
  const show=()=>{if(media.matches)elements.forEach(element=>element.classList.remove('is-queued'));};media.addEventListener('change',show);
  return()=>{observer.disconnect();media.removeEventListener('change',show);elements.forEach(element=>element.classList.remove('is-queued'));};
 },[]);
}
