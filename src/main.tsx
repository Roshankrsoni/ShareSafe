import { StrictMode } from 'react';
import { hydrateRoot, createRoot } from 'react-dom/client';
import App from './App';
import './diskbuddy.css';
const root=document.getElementById('root')!;
if(root.hasChildNodes()) hydrateRoot(root,<StrictMode><App/></StrictMode>);
else createRoot(root).render(<StrictMode><App/></StrictMode>);
