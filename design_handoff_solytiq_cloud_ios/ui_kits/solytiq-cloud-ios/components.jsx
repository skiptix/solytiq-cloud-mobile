// Solytiq Cloud · iOS v2 — Components
// Exports: SFSymbol, PhoneFrame, NavHeader, TaskRow, QuickAdd, StatCard,
//   FloatingTabBar, SolFloatBtn, SideRail, Card, SectionHeader, Field,
//   EmptyRow, Badge, FileBadge, StorageBar, friendlyDate, todayIso

const { useState, useRef } = React;

// ─── Date helpers ─────────────────────────────────────────────
function friendlyDate(iso) {
  if (!iso) return '';
  const [y,m,d] = iso.slice(0,10).split('-').map(Number);
  const date = new Date(y,m-1,d);
  const now = new Date(); now.setHours(0,0,0,0);
  const tom = new Date(now); tom.setDate(now.getDate()+1);
  if (date.getTime()===now.getTime()) return 'Today';
  if (date.getTime()===tom.getTime()) return 'Tomorrow';
  if (date<now) return 'Overdue';
  return date.toLocaleDateString('en-US',{month:'short',day:'numeric'});
}
window.friendlyDate = friendlyDate;
window.todayIso = ()=>new Date().toISOString().slice(0,10);

// ─── SFSymbol ─────────────────────────────────────────────────
function SFSymbol({name,size=17,color,weight=400,fill=false,style:sty={}}) {
  return (
    <span className="material-symbols-rounded" style={{
      fontSize:size, color:color||'currentColor',
      fontVariationSettings:`'FILL' ${fill?1:0},'wght' ${weight},'GRAD' 0,'opsz' ${Math.min(48,Math.max(20,size))}`,
      lineHeight:1, flexShrink:0, display:'inline-flex', alignItems:'center', ...sty
    }}>{name}</span>
  );
}

// ─── PhoneFrame ───────────────────────────────────────────────
function PhoneFrame({children}) {
  return (
    <div style={{
      width:393, height:852, borderRadius:56, background:'#14102a', padding:9,
      boxShadow:'0 50px 120px rgba(0,0,0,0.70), 0 0 0 2px rgba(255,255,255,0.08), inset 0 1px 0 rgba(255,255,255,0.06)',
      position:'relative', flexShrink:0,
    }}>
      <div style={{
        width:'100%', height:'100%', borderRadius:47, overflow:'hidden',
        background:'var(--sc-page)', position:'relative', display:'flex', flexDirection:'column',
      }}>
        <div style={{
          flexShrink:0, height:54, padding:'17px 30px 0',
          display:'flex', alignItems:'center', justifyContent:'space-between',
          zIndex:100, color:'var(--sc-text)', pointerEvents:'none',
        }}>
          <span className="sc-mono" style={{fontWeight:600,fontSize:17}}>9:41</span>
          <div style={{display:'flex',alignItems:'center',gap:6}}>
            <svg width="18" height="11" viewBox="0 0 18 11">
              <rect x="0" y="7" width="3" height="4" rx="0.5" fill="currentColor"/>
              <rect x="5" y="5" width="3" height="6" rx="0.5" fill="currentColor"/>
              <rect x="10" y="3" width="3" height="8" rx="0.5" fill="currentColor"/>
              <rect x="15" y="0" width="3" height="11" rx="0.5" fill="currentColor"/>
            </svg>
            <svg width="16" height="11" viewBox="0 0 16 11">
              <path d="M8 3a6.5 6.5 0 0 1 5 2.3l1-1a8 8 0 0 0-12 0l1 1A6.5 6.5 0 0 1 8 3Z" fill="currentColor"/>
              <path d="M8 7a3.5 3.5 0 0 1 2.5 1l1-1A5 5 0 0 0 4.5 7l1 1A3.5 3.5 0 0 1 8 7Z" fill="currentColor"/>
              <circle cx="8" cy="10" r="1.3" fill="currentColor"/>
            </svg>
            <svg width="25" height="12" viewBox="0 0 25 12">
              <rect x="0.5" y="0.5" width="22" height="11" rx="3" stroke="currentColor" strokeOpacity="0.4" fill="none"/>
              <rect x="2" y="2" width="19" height="8" rx="1.5" fill="currentColor"/>
              <path d="M24 4v4c.8-.3 1-1 1-2s-.2-1.7-1-2Z" fill="currentColor" opacity="0.45"/>
            </svg>
          </div>
        </div>
        <div style={{position:'absolute',top:12,left:'50%',transform:'translateX(-50%)',
          width:126,height:36,borderRadius:100,background:'#060310',zIndex:110}}/>
        <div style={{flex:1,overflow:'hidden',position:'relative'}}>{children}</div>
        <div style={{position:'absolute',bottom:8,left:'50%',transform:'translateX(-50%)',
          width:134,height:5,borderRadius:100,background:'rgba(28,27,34,0.36)',zIndex:100}}/>
      </div>
    </div>
  );
}

// ─── NavHeader ────────────────────────────────────────────────
function NavHeader({title,eyebrow,subtitle,leading,trailing,large=true,scrollY=0}) {
  const scrolled = scrollY > 52 || !large;
  // Smooth large-title fade: starts fading at 10px, fully gone by 52px
  const largeOp  = large ? Math.max(0, 1 - Math.max(0, scrollY - 10) / 42) : 0;
  const largeShift = large ? Math.min(14, Math.max(0, scrollY - 10) * 0.3) : 14;
  return (
    <div style={{
      position:'sticky', top:0, zIndex:60,
      background: scrolled ? 'var(--sc-glass-bg)' : 'transparent',
      backdropFilter: scrolled ? 'blur(22px)' : 'none',
      WebkitBackdropFilter: scrolled ? 'blur(22px)' : 'none',
      borderBottom: (large && scrolled) ? '0.5px solid var(--sc-glass-border)' : 'none',
      transition:'background 220ms, border-color 220ms',
    }}>
      <div style={{position:'relative',display:'flex',alignItems:'center',justifyContent:'space-between',padding:'10px 20px 0',minHeight:44}}>
        <div style={{width:80,display:'flex',alignItems:'center'}}>{leading}</div>
        {scrolled && (
          <span style={{fontWeight:600,fontSize:16,color:'var(--sc-text)',
            position:'absolute',left:84,right:84,textAlign:'center',
            animation:'screenIn 200ms ease both', whiteSpace:'nowrap',
            overflow:'hidden', textOverflow:'ellipsis',
            pointerEvents:'none'}}>
            {title}
          </span>
        )}
        <div style={{width:80,display:'flex',alignItems:'center',justifyContent:'flex-end'}}>{trailing}</div>
      </div>
      {large && (
        <div style={{
          padding:'4px 22px 14px', textAlign:'center',
          opacity: largeOp,
          transform: `translateY(-${largeShift}px)`,
          pointerEvents: scrolled ? 'none' : 'auto',
          overflow: 'hidden',
          maxHeight: scrolled ? 0 : 200,
          transition: scrolled ? 'max-height 220ms ease, opacity 80ms' : 'none',
        }}>
          {eyebrow && <div style={{fontSize:10,fontWeight:700,letterSpacing:'0.10em',color:'var(--sc-primary-soft)',textTransform:'uppercase',marginBottom:4}}>{eyebrow}</div>}
          <div style={{fontSize:30,fontWeight:700,letterSpacing:'-0.025em',color:'var(--sc-text)',lineHeight:1.1}}>{title}</div>
          {subtitle && <div style={{fontSize:13,color:'var(--sc-text-3)',marginTop:5,lineHeight:1.45}}>{subtitle}</div>}
        </div>
      )}
      {large && scrolled && <div style={{height:8}}/>}
    </div>
  );
}

// ─── TaskRow ──────────────────────────────────────────────────
function TaskRow({task,divider=false,onClick,listBadge,index=0}) {
  const app = window.useApp();
  const [checking, setChecking] = useState(false);
  const PC = {High:'#ea580c',Medium:'#f59e0b',Low:'#787584'};
  const BC = {
    Work:{bg:'#fff5d6',fg:'#6e5e0d'}, Personal:{bg:'#F5F3FF',fg:'#5e4dbb'},
    Urgent:{bg:'#ffdad6',fg:'#ba1a1a'}, Tip:{bg:'#eff6ff',fg:'#1D4ED8'},
  };
  const bc = task.badge ? BC[task.badge] : null;
  const fd = friendlyDate(task.deadline);
  const overdue = fd === 'Overdue';

  const handleCheck = e => {
    e.stopPropagation();
    setChecking(true);
    setTimeout(() => { app.toggleTask(task.id); setChecking(false); }, 220);
  };

  return (
    <div onClick={onClick}
      style={{
        display:'flex', alignItems:'center', gap:11, padding:'var(--sc-row-py, 11px) 16px',
        borderBottom: divider ? '0.5px solid var(--sc-separator)' : 'none',
        cursor: onClick ? 'pointer' : 'default',
        animation: `rowSlideIn 280ms cubic-bezier(0.34,1.2,0.64,1) ${index * 40}ms both`,
        transition: 'background 150ms ease',
        willChange: 'transform',
      }}
      onMouseEnter={e=>{ if(onClick) e.currentTarget.style.background='var(--sc-hover)'; }}
      onMouseLeave={e=>e.currentTarget.style.background='transparent'}
      onMouseDown={e=>{ if(onClick) e.currentTarget.style.transform='scale(0.985)'; }}
      onMouseUp={e=>e.currentTarget.style.transform='scale(1)'}
    >
      <button onClick={handleCheck}
        style={{
          width:24, height:24, borderRadius:8, flexShrink:0, cursor:'pointer',
          border: `1.5px solid ${task.checked ? 'var(--sc-primary)' : 'var(--sc-border)'}`,
          background: task.checked ? 'var(--sc-primary)' : 'transparent',
          display:'flex', alignItems:'center', justifyContent:'center',
          transition: 'border-color 200ms, background 200ms',
          outline:'none', overflow:'hidden',
          transform: checking ? 'scale(0.82)' : 'scale(1)',
          transition: 'transform 180ms cubic-bezier(0.34,1.56,0.64,1), background 200ms, border-color 200ms',
        }}>
        {task.checked && (
          <svg width="11" height="9" viewBox="0 0 12 10" fill="none"
            style={{animation:'checkPop 320ms cubic-bezier(0.34,1.56,0.64,1) both'}}>
            <path d="M1 5l3 3.5 7-7.5" stroke="white" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        )}
      </button>
      <div style={{flex:1, minWidth:0}}>
        <div style={{
          fontSize:14.5, lineHeight:1.3,
          color: task.checked ? 'var(--sc-text-4)' : 'var(--sc-text)',
          textDecoration: task.checked ? 'line-through' : 'none',
          overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap',
          transition: 'color 200ms ease, text-decoration 200ms ease',
        }}>{task.title}</div>
        <div style={{display:'flex',alignItems:'center',gap:6,marginTop:3,flexWrap:'wrap'}}>
          {fd && !task.checked && (
            <span style={{fontSize:11,color:overdue?'var(--sc-danger)':'var(--sc-text-4)',
              fontWeight:overdue?600:400,display:'flex',alignItems:'center',gap:2}}>
              <SFSymbol name="calendar_today" size={10} color={overdue?'var(--sc-danger)':'var(--sc-text-4)'}/>
              {fd}
            </span>
          )}
          {listBadge && <span style={{fontSize:10,color:'var(--sc-text-4)'}}>· {listBadge}</span>}
          {bc && <span style={{fontSize:10,fontWeight:600,background:bc.bg,color:bc.fg,borderRadius:9999,padding:'1px 7px'}}>{task.badge}</span>}
          {Array.isArray(task.subItems) && task.subItems.length>0 && (
            <span style={{fontSize:10,fontWeight:600,color:'var(--sc-primary)',background:'var(--sc-primary-bg)',borderRadius:9999,padding:'1px 7px',display:'flex',alignItems:'center',gap:3}}>
              <SFSymbol name="checklist" size={10} color="var(--sc-primary)"/>
              {task.subItems.filter(s=>s.checked).length}/{task.subItems.length}
            </span>
          )}
          {task.linkedListId && (
            <span style={{fontSize:10,fontWeight:600,color:'#0d9488',background:'rgba(13,148,136,0.10)',borderRadius:9999,padding:'1px 7px',display:'flex',alignItems:'center',gap:3}}>
              <SFSymbol name="account_tree" size={10} color="#0d9488"/>Sublist
            </span>
          )}
        </div>
      </div>
      {task.priority && !task.checked && (
        <div style={{width:7,height:7,borderRadius:'50%',background:PC[task.priority]||'#ccc',flexShrink:0}}/>
      )}
      {task.checked && (
        <SFSymbol name="check_circle" size={17} color="var(--sc-success)" fill
          style={{animation:'springScale 300ms cubic-bezier(0.34,1.56,0.64,1) both'}}/>
      )}
      {onClick && !task.checked && (
        <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
      )}
    </div>
  );
}

// ─── QuickAdd ─────────────────────────────────────────────────
function QuickAdd({onAdd,placeholder='Add task…'}) {
  const [text,setText] = useState('');
  const [focus,setFocus] = useState(false);
  const submit = ()=>{const t=text.trim();if(!t)return;onAdd({title:t});setText('');};
  return (
    <div style={{display:'flex',alignItems:'center',gap:10,padding:'11px 14px',
      background:'var(--sc-card)',borderRadius:16,
      border:`0.5px solid ${focus?'var(--sc-primary)':'var(--sc-border)'}`,
      boxShadow:focus?'0 0 0 3px rgba(94,77,187,0.10)':'none',transition:'all 180ms'}}>
      <div style={{width:24,height:24,borderRadius:8,flexShrink:0,
        background:focus?'var(--sc-primary)':'var(--sc-primary-bg)',
        display:'flex',alignItems:'center',justifyContent:'center',transition:'background 200ms'}}>
        <SFSymbol name="add" size={16} color={focus?'#fff':'var(--sc-primary)'} weight={600}/>
      </div>
      <input value={text} onChange={e=>setText(e.target.value)}
        onFocus={()=>setFocus(true)} onBlur={()=>setFocus(false)}
        onKeyDown={e=>e.key==='Enter'&&submit()}
        placeholder={placeholder}
        style={{flex:1,background:'transparent',border:'none',outline:'none',
          fontFamily:'var(--sc-font)',fontSize:14.5,color:'var(--sc-text)'}}/>
      {text.trim() && (
        <button onClick={submit} style={{background:'var(--sc-primary)',border:'none',
          borderRadius:8,padding:'5px 12px',color:'#fff',fontSize:12.5,fontWeight:600,
          cursor:'pointer',flexShrink:0,animation:'screenIn 140ms ease both'}}>Add</button>
      )}
    </div>
  );
}

// ─── StatCard ─────────────────────────────────────────────────
function StatCard({label,value,sub,icon,accent='#5e4dbb',index=0,onClick}) {
  const [display, setDisplay] = useState(0);
  const [entered, setEntered] = useState(false);
  useEffect(() => {
    const delay = index * 80;
    const t = setTimeout(() => {
      setEntered(true);
      if (typeof value !== 'number') return;
      const steps = 18, dur = 520;
      let i = 0;
      const tick = setInterval(() => {
        i++;
        const ease = 1 - Math.pow(1 - i/steps, 3);
        setDisplay(Math.round(ease * value));
        if (i >= steps) { setDisplay(value); clearInterval(tick); }
      }, dur / steps);
      return () => clearInterval(tick);
    }, delay);
    return () => clearTimeout(t);
  }, [value, index]);

  return (
    <div onClick={onClick} style={{
      background:'var(--sc-card)', border:'0.5px solid var(--sc-border)',
      borderRadius:18, padding:'14px 14px 12px',
      display:'flex', flexDirection:'column', gap:7,
      animation: `springUp 380ms cubic-bezier(0.34,1.2,0.64,1) ${index*70}ms both`,
      transition: 'transform 200ms cubic-bezier(0.34,1.56,0.64,1), box-shadow 200ms ease',
      willChange: 'transform', cursor: onClick ? 'pointer' : 'default',
    }}
      onMouseEnter={e=>{ e.currentTarget.style.transform='translateY(-2px)'; e.currentTarget.style.boxShadow=`0 8px 24px ${accent}1a`; }}
      onMouseLeave={e=>{ e.currentTarget.style.transform='translateY(0)'; e.currentTarget.style.boxShadow='none'; }}
    >
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'flex-start'}}>
        <div style={{width:34,height:34,borderRadius:11,background:`${accent}18`,
          display:'flex',alignItems:'center',justifyContent:'center',
          animation:`springScale 400ms cubic-bezier(0.34,1.56,0.64,1) ${index*70+120}ms both`}}>
          <SFSymbol name={icon} size={17} color={accent} fill/>
        </div>
        <span style={{fontSize:9.5,fontWeight:700,color:accent,background:`${accent}14`,
          borderRadius:9999,padding:'2px 8px',textTransform:'uppercase',letterSpacing:'0.05em'}}>{sub}</span>
      </div>
      <div className="sc-mono" style={{fontSize:30,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.03em',lineHeight:1}}>
        {typeof value === 'number' ? display : value}
      </div>
      <div style={{fontSize:12,fontWeight:500,color:'var(--sc-text-3)'}}>{label}</div>
    </div>
  );
}

// ─── Card ─────────────────────────────────────────────────────
function Card({children,style:sty={}}) {
  return (
    <div style={{margin:'0 18px',background:'var(--sc-card)',border:'0.5px solid var(--sc-border)',
      borderRadius:'var(--sc-r)',overflow:'hidden',...sty}}>{children}</div>
  );
}

// ─── SectionHeader ────────────────────────────────────────────
function SectionHeader({title,right,inSheet=false}) {
  return (
    <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',
      padding:`${inSheet?'14px':'18px'} ${inSheet?'22px':'26px'} 6px`}}>
      <span style={{fontSize:10,fontWeight:700,letterSpacing:'0.09em',
        color:'var(--sc-text-4)',textTransform:'uppercase'}}>{title}</span>
      {right}
    </div>
  );
}

// ─── Field ────────────────────────────────────────────────────
function Field({label,children}) {
  return (
    <div>
      <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-3)',
        letterSpacing:'0.07em',textTransform:'uppercase',marginBottom:7}}>{label}</div>
      {children}
    </div>
  );
}

// ─── EmptyRow ─────────────────────────────────────────────────
function EmptyRow({text}) {
  return (
    <div style={{padding:'22px 16px',textAlign:'center',fontSize:13,
      color:'var(--sc-text-4)',fontStyle:'italic'}}>{text}</div>
  );
}

// ─── Badge ────────────────────────────────────────────────────
function Badge({label}) {
  const C={Work:{bg:'#fff5d6',fg:'#6e5e0d'},Personal:{bg:'#F5F3FF',fg:'#5e4dbb'},Urgent:{bg:'#ffdad6',fg:'#ba1a1a'},Tip:{bg:'#eff6ff',fg:'#1D4ED8'}};
  const c=C[label]||{bg:'#f1ecf6',fg:'#787584'};
  return <span style={{fontSize:11,fontWeight:600,background:c.bg,color:c.fg,borderRadius:9999,padding:'2px 9px'}}>{label}</span>;
}

// ─── FileBadge ────────────────────────────────────────────────
function FileBadge({mime,size=44}) {
  const lbl = mime.includes('pdf')?'PDF':mime.includes('image')?'IMG':mime.includes('video')?'VID':mime.includes('zip')?'ZIP':mime.includes('word')||mime.includes('doc')?'DOC':'FILE';
  const col = mime.includes('pdf')?'#dc2626':mime.includes('image')?'#2563eb':mime.includes('video')?'#7c3aed':mime.includes('zip')?'#d97706':'#5e4dbb';
  return (
    <div style={{width:size,height:size,borderRadius:12,background:'#f8f7ff',
      border:'0.5px solid var(--sc-border)',display:'flex',flexDirection:'column',
      alignItems:'center',justifyContent:'center',flexShrink:0,overflow:'hidden',position:'relative'}}>
      <SFSymbol name="description" size={size*0.48} color="#d1d5db"/>
      <div style={{position:'absolute',bottom:3,left:'50%',transform:'translateX(-50%)',
        background:col,color:'#fff',fontSize:7,fontWeight:800,
        letterSpacing:'0.04em',padding:'1px 4px',borderRadius:3,whiteSpace:'nowrap'}}>{lbl}</div>
    </div>
  );
}

// ─── StorageBar ───────────────────────────────────────────────
function StorageBar({used,total,isAdmin=false}) {
  const fmt=b=>b>=1e9?`${(b/1e9).toFixed(1)} GB`:b>=1e6?`${(b/1e6).toFixed(0)} MB`:`${Math.round(b/1e3)} KB`;
  const pct=isAdmin?0:Math.min(100,Math.round((used/total)*100));
  const bar=pct>=90?'#ba1a1a':pct>=70?'#d97706':'#5e4dbb';
  return (
    <div>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:8}}>
        <span style={{fontSize:13,color:'var(--sc-text-2)',fontWeight:500}}>{fmt(used)} used</span>
        {isAdmin
          ? <span style={{fontSize:18,color:'var(--sc-primary)',fontWeight:700,lineHeight:1}}>∞</span>
          : <span style={{fontSize:12,color:'var(--sc-text-4)'}}>of {fmt(total)}</span>}
      </div>
      {!isAdmin && (
        <div style={{height:7,background:'#ebe6f0',borderRadius:9999,overflow:'hidden'}}>
          <div style={{width:`${pct}%`,height:'100%',background:bar,borderRadius:9999,transition:'width 500ms'}}/>
        </div>
      )}
    </div>
  );
}

// ─── FloatingTabBar (iOS 26 Liquid Glass) ─────────────────────
function FloatingTabBar() {
  const app = window.useApp();
  if (!app) return null;
  const connected = app.profile.mode === 'server';

  const leftTabs = [
    {id:'dashboard', screen:'dashboard', icon:'home',           label:'Home'},
    {id:'scheduled', screen:'scheduled', icon:'calendar_month', label:'Calendar'},
  ];
  const rightTabs = [
    ...(connected ? [{id:'files', screen:'files', icon:'cloud', label:'Files'}] : []),
    {id:'lists', screen:'lists', icon:'list_alt', label:'Lists'},
  ];
  const allTabs = [...leftTabs, ...rightTabs];

  const isActive = t => {
    if (t.screen === 'lists') return ['lists','list','folder'].includes(app.screen);
    return app.screen === t.screen;
  };

  const pillStyle = {
    pointerEvents:'all', display:'flex', alignItems:'center',
    padding:'6px 8px', borderRadius:9999,
    background:'rgba(245,242,255,0.55)',
    backdropFilter:'blur(40px) saturate(180%)',
    WebkitBackdropFilter:'blur(40px) saturate(180%)',
    border:'1px solid rgba(255,255,255,0.55)',
    boxShadow:[
      '0 0 0 0.5px rgba(94,77,187,0.18)',
      '0 8px 32px rgba(28,27,34,0.18)',
      '0 2px 8px rgba(28,27,34,0.10)',
      'inset 0 1px 0 rgba(255,255,255,0.80)',
      'inset 0 -1px 0 rgba(94,77,187,0.08)',
    ].join(','),
    gap:2,
  };

  const TabBtn = ({tab}) => {
    const active = isActive(tab);
    return (
      <button onClick={() => { app.setScreen(tab.screen); app.setModal(null); }}
        style={{
          width: 68, flexShrink: 0,
          display:'flex', flexDirection:'column',
          alignItems:'center', justifyContent:'center',
          gap:2, padding: '7px 0',
          borderRadius:9999, border:'none', cursor:'pointer',
          transition:'background 240ms cubic-bezier(0.34,1.2,0.64,1), box-shadow 240ms ease',
          background: active
            ? 'linear-gradient(180deg, rgba(255,255,255,0.72) 0%, rgba(240,235,255,0.60) 100%)'
            : 'transparent',
          boxShadow: active ? [
            'inset 0 1px 0 rgba(255,255,255,0.90)',
            'inset 0 -1px 0 rgba(94,77,187,0.12)',
            '0 2px 10px rgba(94,77,187,0.22)',
            '0 1px 3px rgba(28,27,34,0.10)',
          ].join(',') : 'none',
        }}
        onMouseEnter={e=>{ if(!active) e.currentTarget.style.background='rgba(255,255,255,0.30)'; }}
        onMouseLeave={e=>{ if(!active) e.currentTarget.style.background='transparent'; }}
      >
        <div key={active ? app.screen : undefined}
          style={{animation: active ? 'springScale 320ms cubic-bezier(0.34,1.56,0.64,1) both' : 'none'}}>
          <SFSymbol name={tab.icon} size={active ? 23 : 22} fill={active}
            color={active ? '#5e4dbb' : 'rgba(120,117,132,0.85)'}
            style={{transition:'color 200ms ease, filter 200ms ease',
              filter: active ? 'drop-shadow(0 1px 3px rgba(94,77,187,0.35))' : 'none'}}/>
        </div>
        <span key={active ? `label-${app.screen}` : undefined}
          style={{
          fontSize: active ? 9.5 : 0, maxHeight: active ? 14 : 0,
          overflow:'hidden', fontWeight:700, color:'#5e4dbb',
          letterSpacing:'0.01em', lineHeight:1.2,
          transition:'font-size 200ms ease, max-height 200ms ease, opacity 180ms ease',
          whiteSpace:'nowrap', opacity: active ? 1 : 0,
          animation: active ? 'fadeUp 200ms ease 80ms both' : 'none',
        }}>{tab.label}</span>
      </button>
    );
  };

  /* Center AI tab — inline within the single pill */
  const AiTab = () => (
    <button onClick={() => app.setModal('ai-chat')}
      style={{
        width:44, height:44, borderRadius:'50%', flexShrink:0,
        background:'linear-gradient(145deg, #b59cff 0%, #5e4dbb 55%, #3d2d99 100%)',
        border:'2px solid rgba(255,255,255,0.60)',
        boxShadow:[
          '0 0 0 1px rgba(94,77,187,0.22)',
          '0 4px 18px rgba(94,77,187,0.52)',
          'inset 0 1.5px 0 rgba(255,255,255,0.40)',
        ].join(','),
        cursor:'pointer', margin:'0 4px',
        display:'flex', alignItems:'center', justifyContent:'center',
        transition:'transform 200ms cubic-bezier(0.34,1.56,0.64,1)',
        animation:'aiBubbleFloat 3s ease-in-out infinite',
      }}
      onMouseEnter={e=>{ e.currentTarget.style.transform='scale(1.10)'; e.currentTarget.style.animationPlayState='paused'; }}
      onMouseLeave={e=>{ e.currentTarget.style.transform='scale(1)'; e.currentTarget.style.animationPlayState='running'; }}
    >
      <SFSymbol name="auto_awesome" size={20} color="#fff" fill
        style={{filter:'drop-shadow(0 1px 3px rgba(0,0,0,0.25))'}}/>
    </button>
  );

  return (
    <div style={{
      position:'absolute', bottom:16, left:0, right:0, zIndex:50,
      display:'flex', justifyContent:'center', alignItems:'center', pointerEvents:'none',
    }}>
      {/* Glow bloom */}
      <div style={{
        position:'absolute', bottom:-8, left:'50%', transform:'translateX(-50%)',
        width:'70%', height:40,
        background:'radial-gradient(ellipse, rgba(157,141,255,0.26) 0%, transparent 70%)',
        filter:'blur(12px)', pointerEvents:'none',
      }}/>

      {/* Single unified pill */}
      <div style={pillStyle}>
        {connected ? (
          <>
            {leftTabs.map(tab => <TabBtn key={tab.id} tab={tab}/>)}
            <AiTab />
            {rightTabs.map(tab => <TabBtn key={tab.id} tab={tab}/>)}
          </>
        ) : (
          allTabs.map(tab => <TabBtn key={tab.id} tab={tab}/>)
        )}
      </div>
    </div>
  );
}

// ─── AddFloatBtn (top-left, matches ProfileBtn) ───────────────
function AddFloatBtn() {
  const app = window.useApp();
  if (!app) return null;
  if (['files', 'list', 'folder'].includes(app.screen)) return null;
  const isLists = ['lists','folder'].includes(app.screen);
  const action = () => app.setModal(isLists ? 'add-choice' : 'add-task');
  return (
    <button onClick={action}
      style={{
        position:'absolute', left:20, top:14, zIndex:70,
        width:28, height:28, borderRadius:'50%',
        background:'linear-gradient(135deg,#b59cff 0%,#5e4dbb 100%)',
        border:'none', cursor:'pointer',
        display:'flex', alignItems:'center', justifyContent:'center',
        boxShadow:'0 2px 10px rgba(94,77,187,0.40)',
        transition:'transform 200ms cubic-bezier(0.34,1.56,0.64,1)',
      }}>
      <SFSymbol name="add" size={15} color="#fff" weight={700}/>
    </button>
  );
}

// ─── ProfileBtn (top-right persistent) ───────────────────────
function ProfileBtn() {
  const app = window.useApp();
  if (!app) return null;
  const initials = ((app.profile.fullName || app.profile.username || 'U')
    .split(' ').map(w => w[0]).join('').toUpperCase().slice(0,2));
  return (
    <button onClick={() => app.setModal('settings')}
      style={{
        position:'absolute', top:14, right:20, zIndex:70,
        width:28, height:28, borderRadius:'50%',
        overflow:'hidden', border:'none', cursor:'pointer', padding:0,
        boxShadow:'0 2px 10px rgba(94,77,187,0.28), inset 0 1px 0 rgba(255,255,255,0.6)',
        transition:'transform 200ms cubic-bezier(0.34,1.56,0.64,1)',
        flexShrink:0,
      }}>
      {app.profile.profileImage
        ? <img src={app.profile.profileImage} style={{width:'100%',height:'100%',objectFit:'cover',display:'block'}}/>
        : <div style={{width:'100%',height:'100%',
            background:'linear-gradient(135deg,#b59cff,#5e4dbb)',
            display:'flex',alignItems:'center',justifyContent:'center'}}>
            <span style={{fontSize:10,fontWeight:700,color:'#fff',letterSpacing:'-0.01em'}}>{initials}</span>
          </div>}
    </button>
  );
}

// ─── SolFloatBtn (bottom-right, server only) ───────────────────
function SolFloatBtn() {
  // AI button now lives inside FloatingTabBar when connected
  return null;
}

// ─── SideRail ─────────────────────────────────────────────────
function SideRail() {
  const app = window.useApp();
  if (!app) return null;
  const items = [
    {label:'Welcome',icon:'waving_hand',fn:()=>{app.setModal(null);app.setScreen('welcome');}},
    {label:'Login',icon:'login',fn:()=>{app.setModal(null);app.setScreen('login');}},
    {label:'Dashboard',icon:'home',fn:()=>{app.setModal(null);app.setScreen('dashboard');}},
    {label:'Calendar',icon:'calendar_month',fn:()=>{app.setModal(null);app.setScreen('scheduled');}},
    {label:'Files',icon:'cloud',fn:()=>{app.setModal(null);app.setScreen('files');}},
    {label:'List View',icon:'list_alt',fn:()=>{app.setCurrentListId('backyard-2026');app.setModal(null);app.setScreen('list');}},
    {label:'Folder View',icon:'folder',fn:()=>{app.setCurrentFolderId('f-personal');app.setModal(null);app.setScreen('folder');}},
    {label:'Timelines',icon:'timeline',fn:()=>{app.setModal(null);app.setScreen('timelines');}},
    {label:'Timeline View',icon:'route',fn:()=>{app.setSelectedTimelineId('tl-launch');app.setModal(null);app.setScreen('timeline');}},
    null,
    {label:'Lists',icon:'list_alt',fn:()=>{app.setModal(null);app.setScreen('lists');}},
    {label:'Workspaces',icon:'workspaces',fn:()=>app.setModal('workspace-switcher')},
    {label:'Sol Chat',icon:'auto_awesome',fn:()=>app.setModal('ai-chat')},
    {label:'Add List',icon:'add_circle',fn:()=>app.setModal('add-list')},
    {label:'Add Timeline',icon:'add_road',fn:()=>app.setModal('add-timeline')},
    {label:'2FA Setup',icon:'shield_lock',fn:()=>app.setModal('two-fa')},
    {label:'Trash',icon:'delete',fn:()=>app.setModal('trash')},
    {label:'Settings',icon:'person',fn:()=>app.setModal('settings')},
  ];
  return (
    <div style={{position:'fixed',left:20,top:'50%',transform:'translateY(-50%)',
      display:'flex',flexDirection:'column',gap:1,padding:8,
      background:'rgba(255,255,255,0.05)',border:'0.5px solid rgba(255,255,255,0.10)',
      borderRadius:14,backdropFilter:'blur(20px)',WebkitBackdropFilter:'blur(20px)',
      maxHeight:'90vh',overflowY:'auto'}}>
      <div style={{fontSize:9,fontWeight:700,letterSpacing:'0.09em',
        color:'rgba(255,255,255,0.35)',textTransform:'uppercase',marginBottom:4,paddingLeft:8}}>Navigate</div>
      {items.map((item,i)=>
        !item
          ? <div key={i} style={{height:1,background:'rgba(255,255,255,0.10)',margin:'3px 0'}}/>
          : (
            <button key={i} onClick={item.fn}
              style={{display:'flex',alignItems:'center',gap:7,padding:'6px 10px',borderRadius:7,
                background:'transparent',border:'none',cursor:'pointer',whiteSpace:'nowrap',
                color:'rgba(255,255,255,0.80)',fontFamily:'var(--sc-font)',fontSize:12,textAlign:'left'}}
              onMouseEnter={e=>e.currentTarget.style.background='rgba(157,141,255,0.18)'}
              onMouseLeave={e=>e.currentTarget.style.background='transparent'}>
              <SFSymbol name={item.icon} size={13} color="rgba(200,180,255,0.9)"/>
              {item.label}
            </button>
          )
      )}
    </div>
  );
}

// ─── Exports ──────────────────────────────────────────────────
Object.assign(window, {
  SFSymbol, PhoneFrame, NavHeader, TaskRow, QuickAdd, StatCard,
  Card, SectionHeader, Field, EmptyRow, Badge, FileBadge, StorageBar,
  FloatingTabBar, AddFloatBtn, ProfileBtn, SolFloatBtn, SideRail,
});
