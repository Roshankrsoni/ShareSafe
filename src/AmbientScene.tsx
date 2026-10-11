import { useEffect, useRef, useState } from 'react';
import { Pause, Play, ShieldCheck } from 'lucide-react';

export default function AmbientScene({ variant = 'hero' }: { variant?: 'hero' | 'seal' }) {
  const host = useRef<HTMLDivElement>(null);
  const controller = useRef<{ setRunning: (value: boolean) => void; dispose: () => void } | null>(null);
  const [paused, setPaused] = useState(false);
  const [ready, setReady] = useState(false);
  const pauseRef = useRef(false);
  useEffect(() => {
    const node = host.current;
    if (!node) return;
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    if (media.matches) return;
    let disposed = false, visible = false, loading = false;
    const update = () => controller.current?.setRunning(visible && !document.hidden && !media.matches && !pauseRef.current);
    const observer = new IntersectionObserver(async ([entry]) => {
      visible = entry.isIntersecting;
      if (visible && !controller.current && !loading && node.clientWidth > 0) {
        loading = true;
        try {
          const { createScene } = await import('./threeScene');
          if (disposed) return;
          controller.current = createScene(node, variant, () => setReady(false));
          setReady(true);
        } catch { /* A static shield remains when WebGL is unavailable. */ }
      }
      update();
    }, { rootMargin: '100px' });
    observer.observe(node);
    media.addEventListener('change', update);
    document.addEventListener('visibilitychange', update);
    return () => { disposed = true; observer.disconnect(); media.removeEventListener('change', update); document.removeEventListener('visibilitychange', update); controller.current?.dispose(); controller.current = null; };
  }, [variant]);
  return <div className={`ambient-scene ambient-${variant} ${ready ? 'scene-ready' : ''}`}>
    <div className="three-host" ref={host} aria-hidden="true"/>
    <div className="three-fallback" aria-hidden="true"><ShieldCheck/></div>
    {ready && <button className="scene-motion-control" aria-label={paused ? 'Play 3D animation' : 'Pause 3D animation'} onClick={() => {pauseRef.current = !paused;setPaused(!paused);controller.current?.setRunning(paused && !document.hidden && !window.matchMedia('(prefers-reduced-motion: reduce)').matches);}}>{paused ? <Play size={11}/> : <Pause size={11}/>}<span>{paused ? 'Play motion' : 'Pause motion'}</span></button>}
  </div>;
}
