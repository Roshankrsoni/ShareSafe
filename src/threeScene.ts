import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

export function createScene(host: HTMLDivElement, variant: 'hero' | 'seal', onUnavailable: () => void) {
  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.setClearColor(0x000000, 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  host.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 80);
  camera.position.set(0, 0, variant === 'hero' ? 14 : 7.5);
  const pmrem = new THREE.PMREMGenerator(renderer);
  const room = new RoomEnvironment();
  const environment = pmrem.fromScene(room, 0.04);
  scene.environment = environment.texture;
  room.dispose(); pmrem.dispose();
  scene.add(new THREE.HemisphereLight(0xe8ffff, 0x233456, 1.4));
  const key = new THREE.DirectionalLight(0xffffff, 3); key.position.set(-3, 4, 5); scene.add(key);
  const rim = new THREE.DirectionalLight(0x34c759, 2); rim.position.set(4, -2, 1); scene.add(rim);
  const red = new THREE.MeshPhysicalMaterial({ color: 0xde041f, metalness: 0.28, roughness: 0.24, clearcoat: 1, clearcoatRoughness: 0.2 });
  const ivory = new THREE.MeshStandardMaterial({ color: 0xf5f6f9, metalness: 0.1, roughness: 0.4 });
  const graphite = new THREE.MeshStandardMaterial({ color: 0x20232d, roughness: 0.5 });
  const sage = new THREE.MeshStandardMaterial({ color: 0xc6e8cf, metalness: 0.18, roughness: 0.3 });
  const shieldShape = new THREE.Shape();
  shieldShape.moveTo(0,1.15); shieldShape.lineTo(.93,.8); shieldShape.lineTo(.85,-.15); shieldShape.quadraticCurveTo(.72,-.83,0,-1.17); shieldShape.quadraticCurveTo(-.72,-.83,-.85,-.15); shieldShape.lineTo(-.93,.8); shieldShape.closePath();
  const shield = new THREE.Group();
  const body = new THREE.Mesh(new THREE.ExtrudeGeometry(shieldShape,{depth:.23,bevelEnabled:true,bevelSegments:3,steps:1,bevelSize:.08,bevelThickness:.07,curveSegments:20}),red);
  shield.add(body);
  const checkPath = new THREE.CatmullRomCurve3([new THREE.Vector3(-.42,0,.36),new THREE.Vector3(-.1,-.32,.36),new THREE.Vector3(.45,.4,.36)]);
  shield.add(new THREE.Mesh(new THREE.TubeGeometry(checkPath,20,.065,8,false),ivory));
  scene.add(shield);
  const doc = new THREE.Group();
  const pageShape = new THREE.Shape();
  const x=-.78,y=-1.08,w=1.56,h=2.16,r=.12;
  pageShape.moveTo(x+r,y);pageShape.lineTo(x+w-r,y);pageShape.quadraticCurveTo(x+w,y,x+w,y+r);pageShape.lineTo(x+w,y+h-r);pageShape.quadraticCurveTo(x+w,y+h,x+w-r,y+h);pageShape.lineTo(x+r,y+h);pageShape.quadraticCurveTo(x,y+h,x,y+h-r);pageShape.lineTo(x,y+r);pageShape.quadraticCurveTo(x,y,x+r,y);
  const pageGeometry = new THREE.ExtrudeGeometry(pageShape,{depth:.045,bevelEnabled:true,bevelSize:.035,bevelThickness:.025,bevelSegments:2});
  for(let i=2;i>=0;i--){const page = new THREE.Mesh(pageGeometry,ivory);page.position.set(i*.13,i*.07,-i*.17);doc.add(page);}
  for(let i=0;i<5;i++){const bar = new THREE.Mesh(new THREE.BoxGeometry(i%2 ? .65:1.02,i===2?.13:.025,.012),i===2?graphite:sage);bar.position.set(i%2?-.16:0,.52-i*.23,.09);doc.add(bar);}
  if(variant==='hero')scene.add(doc);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(1.65,.018,8,80),sage);
  ring.rotation.set(.25,.4,.15);shield.add(ring);
  let running=false,frame=0,last=0,time=0,disposed=false;
  let targetX=0,targetY=0;
  const pointer=(event:PointerEvent)=>{const box=host.getBoundingClientRect();targetX=((event.clientX-box.left)/box.width-.5)*.16;targetY=((event.clientY-box.top)/box.height-.5)*.12;};
  // A passive listener creates restrained parallax without tracking or storing pointer data.
  host.parentElement?.parentElement?.addEventListener('pointermove',pointer,{passive:true});
  const pose=()=>{
    shield.rotation.set(-.1+Math.sin(time*.5)*.08+targetY,.35+Math.sin(time*.35)*.18+targetX,-.13);
    doc.rotation.set(.12+targetY,-.35+Math.sin(time*.4)*.12+targetX,.16);
    shield.position.y=Math.sin(time*.7)*.09;doc.position.y=.1+Math.cos(time*.55)*.12;
  };
  const render=()=>{pose();renderer.render(scene,camera);};
  const animate=(now:number)=>{if(!running||disposed)return;frame=requestAnimationFrame(animate);if(now-last<33)return;time+=Math.min((now-last)/1000,.05);last=now;render();};
  const setRunning=(value:boolean)=>{if(disposed||value===running)return;running=value;if(value){last=performance.now();frame=requestAnimationFrame(animate);}else cancelAnimationFrame(frame);};
  const resize=()=>{const width=host.clientWidth,height=host.clientHeight;if(!width||!height)return;renderer.setSize(width,height);camera.aspect=width/height;camera.updateProjectionMatrix();const spread=Math.tan(THREE.MathUtils.degToRad(16))*14*camera.aspect*.79;shield.position.x=variant==='hero'?-spread:0;doc.position.x=spread;render();};
  const observer=new ResizeObserver(resize);observer.observe(host);resize();
  const lost=(event:Event)=>{event.preventDefault();setRunning(false);host.style.opacity='0';onUnavailable();};
  renderer.domElement.addEventListener('webglcontextlost',lost);
  return {setRunning,dispose(){disposed=true;cancelAnimationFrame(frame);observer.disconnect();host.parentElement?.parentElement?.removeEventListener('pointermove',pointer);renderer.domElement.removeEventListener('webglcontextlost',lost);scene.traverse(object=>{if(object instanceof THREE.Mesh){object.geometry.dispose();}});red.dispose();ivory.dispose();graphite.dispose();sage.dispose();environment.dispose();renderer.dispose();renderer.domElement.remove();}};
}
