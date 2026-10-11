import { useEffect, useRef, useState } from 'react';
import { ArrowDown, ArrowRight, Check, FileCheck2, FileText, FolderOpen, LockKeyhole, Pause, Play, RotateCcw, ScanLine, ShieldCheck } from 'lucide-react';

const steps = [
  { icon: FolderOpen, title: 'Open your file', label: 'Open', description: 'Start with a PDF, image or text document. Processing happens on your Mac.', status: 'Your original stays untouched.' },
  { icon: ScanLine, title: 'Review the details', label: 'Review', description: 'Local detection suggests sensitive details. You choose what to redact and what to keep.', status: 'Suggestions need your review.' },
  { icon: ShieldCheck, title: 'Make it yours to share', label: 'Redact', description: 'Apply solid masks, add any missed areas and inspect the protected view.', status: 'Selected details covered with solid masks.' },
  { icon: FileCheck2, title: 'Save a separate copy', label: 'Export', description: 'Confirm your review and export a fresh copy. Check the saved result before sharing.', status: 'A separate copy. A clear export receipt.' },
];

export default function Workflow() {
  const [step, setStep] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [visible, setVisible] = useState(false);
  const [foreground, setForeground] = useState(true);
  const [reducedMotion, setReducedMotion] = useState(true);
  const section = useRef<HTMLElement>(null);
  const started = useRef(false);
  const interacted = useRef(false);

  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)');
    const update = () => { setReducedMotion(media.matches); if (media.matches) setPlaying(false); };
    update(); media.addEventListener('change', update);
    const visibility = () => setForeground(!document.hidden);
    document.addEventListener('visibilitychange', visibility);
    const observer = new IntersectionObserver(([entry]) => {
      setVisible(entry.isIntersecting);
      if (entry.isIntersecting && !started.current && !interacted.current && !media.matches) {
        started.current = true; setPlaying(true);
      }
    }, { threshold: 0.25 });
    if (section.current) observer.observe(section.current);
    return () => { observer.disconnect(); media.removeEventListener('change', update); document.removeEventListener('visibilitychange', visibility); };
  }, []);

  useEffect(() => {
    if (!playing || !visible || !foreground || reducedMotion) return;
    const timer = window.setTimeout(() => {
      if (step === steps.length - 1) setPlaying(false);
      else setStep(value => value + 1);
    }, 3600);
    return () => window.clearTimeout(timer);
  }, [step, playing, visible, foreground, reducedMotion]);

  const choose = (index: number) => { interacted.current = true; setPlaying(false); setStep(index); };
  const toggle = () => {
    interacted.current = true;
    if (reducedMotion) { setStep(value => (value + 1) % steps.length); return; }
    if (!playing && step === steps.length - 1) setStep(0);
    setPlaying(value => !value);
  };
  const current = steps[step];
  const running = playing && visible && foreground && !reducedMotion;
  return <section className="section shell workflow" id="how-it-works" ref={section}>
    <div className="section-heading reveal"><div><span className="eyebrow muted">THE MOMENT BEFORE SEND</span><h2>A simple flow.<br/>A more private finish.</h2></div><p>From your original to a considered copy.<br/>Watch the workflow, or explore each step.</p></div>
    <div className={`workflow-theater ${running ? 'is-playing' : ''}`}>
      <div className="workflow-topline"><span><span className="live-dot"/> THE SHARESAFE WORKFLOW</span><button className="play-control" onClick={toggle} aria-label={reducedMotion ? 'Next workflow step' : playing ? 'Pause workflow animation' : step === 3 ? 'Replay workflow animation' : 'Play workflow animation'}>{reducedMotion ? <ArrowRight size={14}/> : playing ? <Pause size={14}/> : step === 3 ? <RotateCcw size={14}/> : <Play size={14}/>}<span>{reducedMotion ? 'Next step' : playing ? 'Pause' : step === 3 ? 'Replay' : 'Play'}</span></button></div>
      <div className="workflow-body">
        <div className={`document-scene scene-${step}`} aria-hidden="true">
          <div className="orbit orbit-one"/><div className="orbit orbit-two"/>
          <div className="document-illustration" key={step}>
            <div className="paper-heading"><span className="paper-monogram">N</span><div>NORTHSTAR<small>Fictional project brief</small></div><FileText size={19}/></div>
            <div className="paper-rule"/><h3>A new chapter.</h3><p>Prepared for the next big thing.</p>
            <div className="paper-lines"><i/><i/><i/></div>
            <span className="paper-label">CLIENT CONTACT</span>
            <div className={`example-detail ${step >= 1 ? 'identified' : ''} ${step >= 2 ? 'masked' : ''}`}><span>olivia@example.com</span>{step === 1 && <span className="found-dot"/>}</div>
            <div className={`example-detail phone-detail ${step >= 1 ? 'identified' : ''} ${step >= 2 ? 'masked' : ''}`}><span>+1 415 555 0182</span>{step === 1 && <span className="found-dot"/>}</div>
            <div className="paper-lines bottom-lines"><i/><i/></div>
            {step === 1 && <div className="scan-beam"/>}
            {step === 3 && <div className="export-seal"><Check size={23}/></div>}
          </div>
          <div className={`scene-badge ${step === 3 ? 'success' : ''}`} key={`badge-${step}`}><current.icon size={16}/>{['Local file opened', 'Review suggested details', 'Solid masks applied', 'Separate copy saved'][step]}</div>
          <div className="scene-caption">WORKFLOW ILLUSTRATION · FICTIONAL DETAILS</div>
        </div>
        <div className="workflow-narrative">
          <span className="workflow-count">0{step + 1}<span> / 04</span></span>
          <div key={step} className="step-story"><h3>{current.title}</h3><p>{current.description}</p><div className="workflow-status"><Check size={15}/>{current.status}</div></div>
          <div className="workflow-local"><LockKeyhole size={13}/><span>On your Mac, from start to finish.</span></div>
        </div>
      </div>
      <div className="workflow-timeline" aria-label="Workflow steps">{steps.map((item,index) => <button key={item.label} className={`${step === index ? 'current' : ''} ${step > index ? 'complete' : ''}`} aria-pressed={step === index} aria-label={`Step ${index + 1}: ${item.label}`} onClick={() => choose(index)}><span className="timeline-node">{step > index ? <Check size={13}/> : `0${index + 1}`}</span><span>{item.label}</span><ArrowRight className="timeline-arrow" size={14}/>{step === index && <span className="step-progress" key={`${index}-${playing}`}><span style={{animationPlayState: running ? 'running' : 'paused'}}/></span>}</button>)}</div>
    </div>
    <p className="workflow-note"><ArrowDown size={13}/> This illustrates the process. Explore real app screenshots above. Detection always needs human review.</p>
  </section>;
}
