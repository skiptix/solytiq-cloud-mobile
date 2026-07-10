// Solytiq Cloud · iOS v2 — Sheets & Modals
// Exports: TaskDetailSheet, EditTaskSheet, AddListSheet, ListsDrawerSheet,
//          SettingsSheet, AIAssistantSheet, TrashSheet

const { useState, useEffect, useRef } = React;

// ─── TaskDetailSheet ──────────────────────────────────────────
function TaskDetailSheet() {
  const app = window.useApp();
  const { SFSymbol, Badge } = window;
  const found = app.findTaskById(app.selectedTaskId);
  if (!found) return <div style={{padding:24,color:'var(--sc-text-3)'}}>Task not found.</div>;
  const { task, source, listName } = found;
  const PC = { High:'#ea580c', Medium:'#f59e0b', Low:'#787584' };
  const priColor = PC[task.priority] || 'var(--sc-primary)';

  return (
    <div>
      <div style={{height:4,background:task.priority?priColor:'var(--sc-primary-bg-2)'}}/>
      <div style={{padding:'18px 20px 20px'}}>
        <div style={{display:'flex',alignItems:'flex-start',justifyContent:'space-between',gap:12,marginBottom:16}}>
          <div style={{flex:1,fontSize:18,fontWeight:700,lineHeight:1.3,color:'var(--sc-text)'}}>{task.title}</div>
          <button onClick={()=>app.setModal(null)}
            style={{width:30,height:30,borderRadius:'50%',background:'var(--sc-hover)',border:'none',
              display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer',flexShrink:0}}>
            <SFSymbol name="close" size={16} color="var(--sc-text-3)"/>
          </button>
        </div>
        <div style={{display:'flex',flexDirection:'column',gap:10,marginBottom:16}}>
          {task.deadline && (
            <div style={{display:'flex',alignItems:'center',gap:10,fontSize:13}}>
              <SFSymbol name="calendar_today" size={15} color="var(--sc-text-3)"/>
              <span style={{color:'var(--sc-text-2)'}}>
                {window.friendlyDate(task.deadline)}{task.time ? ` · ${task.time}` : ''}
              </span>
            </div>
          )}
          {task.priority && (
            <div style={{display:'flex',alignItems:'center',gap:10,fontSize:13}}>
              <SFSymbol name="flag" size={15} color={priColor} fill/>
              <span style={{color:priColor,fontWeight:600}}>{task.priority} priority</span>
            </div>
          )}
          <div style={{display:'flex',alignItems:'center',gap:10,fontSize:13}}>
            <SFSymbol name="list_alt" size={15} color="var(--sc-text-3)"/>
            <span style={{color:'var(--sc-text-2)'}}>{source==='list' ? listName : 'Dashboard'}</span>
          </div>
          {task.badge && (
            <div style={{display:'flex',alignItems:'center',gap:10}}>
              <SFSymbol name="label" size={15} color="var(--sc-text-3)"/>
              <Badge label={task.badge}/>
            </div>
          )}
        </div>
        {task.note && (
          <div style={{background:'var(--sc-tinted)',borderRadius:12,padding:'12px 14px',
            fontSize:13,color:'var(--sc-text-2)',lineHeight:1.55,marginBottom:16}}>{task.note}</div>
        )}
        <div style={{display:'flex',gap:8}}>
          <button onClick={()=>{app.toggleTask(task.id);app.setModal(null);}}
            style={{flex:1,padding:'12px 0',background:task.checked?'var(--sc-card)':'#ecfdf5',
              color:task.checked?'var(--sc-text-2)':'#10B981',
              border:task.checked?'0.5px solid var(--sc-border)':'1px solid #a7f3d0',
              borderRadius:12,fontSize:14,fontWeight:600,cursor:'pointer',
              display:'flex',alignItems:'center',justifyContent:'center',gap:6}}>
            <SFSymbol name={task.checked?'undo':'check_circle'} size={16} color={task.checked?'var(--sc-text-2)':'#10B981'}/>
            {task.checked?'Reopen':'Complete'}
          </button>
          <button onClick={()=>app.setModal('edit-task')}
            style={{flex:1,padding:'12px 0',background:'var(--sc-primary)',color:'#fff',
              border:'none',borderRadius:12,fontSize:14,fontWeight:600,cursor:'pointer',
              display:'flex',alignItems:'center',justifyContent:'center',gap:6,
              boxShadow:'0 4px 14px rgba(94,77,187,0.30)'}}>
            <SFSymbol name="edit" size={16} color="#fff"/>Edit
          </button>
          <button onClick={()=>{app.deleteTask(task.id);app.setModal(null);}}
            style={{width:48,padding:'12px 0',background:'#fff5f5',color:'var(--sc-danger)',
              border:'0.5px solid #ffdad6',borderRadius:12,cursor:'pointer',
              display:'flex',alignItems:'center',justifyContent:'center'}}>
            <SFSymbol name="delete" size={18} color="var(--sc-danger)"/>
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── EditTaskSheet ────────────────────────────────────────────
function EditTaskSheet({ creating = false }) {
  const app = window.useApp();
  const { SFSymbol } = window;
  const existing = !creating && app.selectedTaskId ? app.findTaskById(app.selectedTaskId) : null;
  const start = existing?.task || {};

  const [title,setTitle] = useState(start.title||'');
  const [note,setNote] = useState(start.note||'');
  const [deadline,setDeadline] = useState(start.deadline || (creating && app.modalData?.presetDeadline) || '');
  const [priority,setPriority] = useState(start.priority||'');
  const [tag,setTag] = useState(start.badge||'');
  const [subItems,setSubItems] = useState(start.subItems||[]);
  const [newSub,setNewSub] = useState('');
  const [noteFocus,setNoteFocus] = useState(false);
  const [showCal,setShowCal] = useState(false);
  const [calOffset,setCalOffset] = useState(0);
  const [confirmDelete,setConfirmDelete] = useState(false);
  const titleRef = useRef(null);
  useEffect(() => {
    const t = setTimeout(() => titleRef.current?.focus({ preventScroll: true }), 360);
    return () => clearTimeout(t);
  }, []);

  const canSave = title.trim().length > 0;
  const save = ()=>{
    if(!canSave) return;
    const cleanSubs = subItems.filter(s=>s.title.trim());
    const p = {title:title.trim(),note:note.trim()||undefined,deadline:deadline||undefined,priority:priority||undefined,badge:tag||undefined,subItems:cleanSubs.length?cleanSubs:undefined};
    if(creating) app.addTask({...p,deadline:deadline||window.todayIso()});
    else app.updateTask(app.selectedTaskId,p);
    app.setModal(null);
  };
  const toggleSub = id => setSubItems(prev=>prev.map(s=>s.id===id?{...s,checked:!s.checked}:s));
  const addSub = ()=>{ const t=newSub.trim(); if(!t)return; setSubItems(prev=>[...prev,{id:Date.now()+Math.floor(Math.random()*999),title:t,checked:false}]); setNewSub(''); };
  const removeSub = id => setSubItems(prev=>prev.filter(s=>s.id!==id));
  const subDone = subItems.filter(s=>s.checked).length;

  // Sublist (linked nested list)
  const sublist = start.linkedListId ? (app.lists||[]).find(l=>l.id===start.linkedListId) : null;
  const sublistTasks = sublist ? sublist.sections.flatMap(s=>s.tasks) : [];
  const sublistDone = sublistTasks.filter(t=>t.checked).length;
  const openSublist = ()=>{ if(sublist){ app.setCurrentListId(sublist.id); app.setModal(null); app.setScreen('list'); } };
  const createSublist = ()=>{ const id=app.addSublist(app.selectedTaskId, title.trim()||'Sublist'); app.setCurrentListId(id); app.setModal(null); app.setScreen('list'); };
  const addDays = n=>{const d=new Date();d.setDate(d.getDate()+n);return d.toISOString().slice(0,10);};

  const PRIS = [
    {key:'High',   color:'#ea580c', bg:'#fff4ee', icon:'flag'},
    {key:'Medium', color:'#d97706', bg:'#fffbeb', icon:'flag'},
    {key:'Low',    color:'#787584', bg:'#f4f2f8', icon:'flag'},
  ];
  const TAGS = [
    {key:'Work',     bg:'#fff5d6', fg:'#6e5e0d'},
    {key:'Personal', bg:'#F5F3FF', fg:'#5e4dbb'},
    {key:'Urgent',   bg:'#ffdad6', fg:'#ba1a1a'},
    {key:'Tip',      bg:'#eff6ff', fg:'#1D4ED8'},
  ];

  const Row = ({icon, iconColor, label, children, last=false}) => (
    <div style={{display:'flex',alignItems:'center',gap:13,padding:'13px 16px',
      borderBottom:last?'none':'0.5px solid var(--sc-separator)'}}>
      <div style={{width:32,height:32,borderRadius:9,background:`${iconColor}18`,
        display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
        <SFSymbol name={icon} size={16} color={iconColor} fill/>
      </div>
      <div style={{flex:1,minWidth:0}}>{children}</div>
    </div>
  );

  const deadlineLabel = deadline
    ? new Date(deadline+'T12:00:00').toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'})
    : 'No deadline';

  return (
    <div style={{display:'flex',flexDirection:'column',gap:0,paddingBottom:32}}>

      {/* ── Header ── */}
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'4px 20px 16px'}}>
        <button onClick={()=>app.setModal(null)}
          style={{fontSize:15,color:'var(--sc-text-3)',background:'transparent',border:'none',cursor:'pointer',padding:'6px 0',fontFamily:'var(--sc-font)'}}>
          Cancel
        </button>
        <span style={{fontSize:16,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.01em'}}>
          {creating ? 'New Task' : 'Edit Task'}
        </span>
        <button onClick={save} disabled={!canSave}
          style={{fontSize:15,fontWeight:700,color:canSave?'var(--sc-primary)':'var(--sc-text-4)',
            background:'transparent',border:'none',cursor:canSave?'pointer':'default',padding:'6px 0',fontFamily:'var(--sc-font)',
            transition:'opacity 150ms'}}>
          Save
        </button>
      </div>

      {/* ── Title ── */}
      <div style={{padding:'0 20px 16px'}}>
        <input ref={titleRef} value={title} onChange={e=>setTitle(e.target.value)}
          placeholder="What needs to be done?"
          style={{
            width:'100%',fontFamily:'var(--sc-font)',fontSize:20,fontWeight:700,
            color:'var(--sc-text)',background:'var(--sc-tinted)',border:'none',
            borderRadius:14,padding:'14px 16px',outline:'none',boxSizing:'border-box',
            letterSpacing:'-0.015em',lineHeight:1.3,
          }}/>
      </div>

      {/* ── Details card ── */}
      <div style={{margin:'0 20px 14px',background:'var(--sc-card)',border:'0.5px solid var(--sc-border)',borderRadius:16,overflow:'hidden'}}>

        {/* Deadline */}
        <Row icon="calendar_today" iconColor="#ea580c" label="Deadline">
          <div style={{fontSize:13,fontWeight:500,color:deadline?'var(--sc-text)':'var(--sc-text-4)',marginBottom:8}}>{deadlineLabel}</div>
          <div style={{display:'flex',gap:6,flexWrap:'wrap'}}>
            {[['Today',0],['Tomorrow',1],['Next Week',7],['Clear',-1]].map(([l,n])=>{
              const v = n>=0 ? addDays(n) : '';
              const a = n>=0 ? deadline===v : deadline==='';
              const isClear = n===-1;
              return (
                <button key={l} onClick={()=>{setDeadline(isClear?'':v);setShowCal(false);}}
                  style={{fontSize:10.5,fontWeight:700,padding:'5px 9px',borderRadius:9999,
                    background:a&&!isClear?'#ea580c':isClear?'var(--sc-hover)':'var(--sc-primary-bg)',
                    color:a&&!isClear?'#fff':isClear?'var(--sc-text-4)':'var(--sc-primary)',
                    border:'none',cursor:'pointer',transition:'all 150ms',whiteSpace:'nowrap'}}>
                  {l}
                </button>
              );
            })}
            <button onClick={()=>setShowCal(s=>!s)}
              style={{fontSize:10.5,fontWeight:700,padding:'5px 9px',borderRadius:9999,
                background:showCal?'var(--sc-primary)':'var(--sc-primary-bg)',
                color:showCal?'#fff':'var(--sc-primary)',
                border:'none',cursor:'pointer',transition:'all 150ms',
                display:'flex',alignItems:'center',gap:4,whiteSpace:'nowrap'}}>
              <SFSymbol name="calendar_month" size={11} color={showCal?'#fff':'var(--sc-primary)'}/>
              Pick date
            </button>
          </div>

          {/* Inline calendar */}
          {showCal && (()=>{
            const now = new Date();
            const view = new Date(now.getFullYear(), now.getMonth() + calOffset, 1);
            const monthName = view.toLocaleDateString('en-US',{month:'long',year:'numeric'});
            const daysInMonth = new Date(view.getFullYear(),view.getMonth()+1,0).getDate();
            const firstDay = view.getDay();
            const cells = [];
            for(let i=0;i<firstDay;i++) cells.push(null);
            for(let d=1;d<=daysInMonth;d++) cells.push(d);
            const isToday = (d) => calOffset===0 && d===now.getDate();
            const isSel = (d) => {
              if(!deadline||!d) return false;
              const dd = new Date(deadline+'T12:00:00');
              return dd.getFullYear()===view.getFullYear() && dd.getMonth()===view.getMonth() && dd.getDate()===d;
            };
            return (
              <div style={{marginTop:12,background:'var(--sc-tinted)',borderRadius:14,padding:'12px 10px',
                animation:'springUp 220ms cubic-bezier(0.34,1.2,0.64,1) both'}}>
                {/* Month nav */}
                <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',marginBottom:8,padding:'0 2px'}}>
                  <button onClick={()=>setCalOffset(o=>o-1)}
                    style={{width:28,height:28,borderRadius:8,background:'var(--sc-card)',border:'0.5px solid var(--sc-border)',
                      display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
                    <SFSymbol name="chevron_left" size={15} color="var(--sc-text-2)"/>
                  </button>
                  <span style={{fontSize:13,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.01em'}}>{monthName}</span>
                  <button onClick={()=>setCalOffset(o=>o+1)}
                    style={{width:28,height:28,borderRadius:8,background:'var(--sc-card)',border:'0.5px solid var(--sc-border)',
                      display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
                    <SFSymbol name="chevron_right" size={15} color="var(--sc-text-2)"/>
                  </button>
                </div>
                {/* Day labels */}
                <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:2,marginBottom:2}}>
                  {['S','M','T','W','T','F','S'].map((d,i)=>(
                    <div key={i} style={{textAlign:'center',fontSize:9.5,fontWeight:700,
                      color:'var(--sc-text-4)',letterSpacing:'0.06em',padding:'3px 0'}}>{d}</div>
                  ))}
                </div>
                {/* Day cells */}
                <div style={{display:'grid',gridTemplateColumns:'repeat(7,1fr)',gap:2}}>
                  {cells.map((d,i)=>{
                    if(!d) return <div key={i}/>;
                    const sel = isSel(d);
                    const tod = isToday(d);
                    const isPast = calOffset<0 || (calOffset===0 && d<now.getDate());
                    return (
                      <button key={i} onClick={()=>{
                        const y=view.getFullYear(),m=String(view.getMonth()+1).padStart(2,'0'),day=String(d).padStart(2,'0');
                        setDeadline(`${y}-${m}-${day}`);
                        setShowCal(false);
                      }} style={{
                        aspectRatio:'1/1',borderRadius:9,border:'none',cursor:isPast?'default':'pointer',
                        background:sel?'#ea580c':tod?'#fff0e8':'transparent',
                        color:sel?'#fff':tod?'#ea580c':isPast?'var(--sc-text-4)':'var(--sc-text)',
                        fontSize:12,fontWeight:sel||tod?700:400,
                        opacity:isPast&&!sel?0.4:1,
                        transition:'background 120ms',
                        display:'flex',alignItems:'center',justifyContent:'center',
                      }}
                        onMouseEnter={e=>{ if(!isPast&&!sel) e.currentTarget.style.background='rgba(234,88,12,0.12)'; }}
                        onMouseLeave={e=>{ if(!sel&&!tod) e.currentTarget.style.background='transparent'; else if(tod) e.currentTarget.style.background='#fff0e8'; }}
                      >{d}</button>
                    );
                  })}
                </div>
              </div>
            );
          })()}
        </Row>

        {/* Priority */}
        <Row icon="flag" iconColor={priority?(PRIS.find(p=>p.key===priority)?.color||'var(--sc-text-3)'):'var(--sc-text-3)'} label="Priority">
          <div style={{fontSize:12,color:'var(--sc-text-4)',marginBottom:8,fontWeight:500}}>
            {priority||'None'}
          </div>
          <div style={{display:'flex',gap:6}}>
            {PRIS.map(p=>{
              const a=priority===p.key;
              return (
                <button key={p.key} onClick={()=>setPriority(a?'':p.key)}
                  style={{flex:1,padding:'8px 0',borderRadius:10,
                    border:`1.5px solid ${a?p.color:'var(--sc-border)'}`,
                    background:a?p.bg:'transparent',
                    fontSize:12,fontWeight:700,color:a?p.color:'var(--sc-text-3)',
                    cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',gap:4,
                    transition:'all 150ms'}}>
                  <span style={{width:6,height:6,borderRadius:'50%',background:a?p.color:'var(--sc-border)',flexShrink:0,display:'block'}}/>
                  {p.key}
                </button>
              );
            })}
          </div>
        </Row>

        {/* Tag */}
        <Row icon="label" iconColor="var(--sc-primary)" label="Tag" last>
          <div style={{fontSize:12,color:'var(--sc-text-4)',marginBottom:8,fontWeight:500}}>
            {tag||'None'}
          </div>
          <div style={{display:'flex',gap:6,flexWrap:'wrap'}}>
            {TAGS.map(t=>{
              const a=tag===t.key;
              return (
                <button key={t.key} onClick={()=>setTag(a?'':t.key)}
                  style={{borderRadius:9999,padding:'6px 14px',
                    border:`1.5px solid ${a?t.fg:' var(--sc-border)'}`,
                    background:a?t.bg:'transparent',
                    fontSize:12,fontWeight:700,color:a?t.fg:'var(--sc-text-3)',
                    cursor:'pointer',transition:'all 150ms'}}>
                  {t.key}
                </button>
              );
            })}
          </div>
        </Row>
      </div>

      {/* ── Notes ── */}
      <div style={{margin:'0 20px 14px',background:'var(--sc-card)',border:`0.5px solid ${noteFocus?'var(--sc-primary)':'var(--sc-border)'}`,borderRadius:16,overflow:'hidden',transition:'border-color 180ms'}}>
        <div style={{display:'flex',gap:13,padding:'13px 16px'}}>
          <div style={{width:32,height:32,borderRadius:9,background:'rgba(94,77,187,0.10)',
            display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:1}}>
            <SFSymbol name="edit_note" size={16} color="var(--sc-primary)" fill/>
          </div>
          <textarea value={note} onChange={e=>setNote(e.target.value)} rows={3}
            placeholder="Add a note…"
            onFocus={()=>setNoteFocus(true)} onBlur={()=>setNoteFocus(false)}
            style={{flex:1,fontFamily:'var(--sc-font)',fontSize:14,color:'var(--sc-text)',
              background:'transparent',border:'none',outline:'none',resize:'none',
              lineHeight:1.6,boxSizing:'border-box',paddingTop:4,
              placeholderColor:'var(--sc-text-4)'}}/>
        </div>
      </div>

      {/* ── Subitems ── */}
      <div style={{margin:'0 20px 14px',background:'var(--sc-card)',border:'0.5px solid var(--sc-border)',borderRadius:16,overflow:'hidden'}}>
        <div style={{display:'flex',alignItems:'center',gap:10,padding:'13px 16px',borderBottom:subItems.length?'0.5px solid var(--sc-separator)':'none'}}>
          <div style={{width:32,height:32,borderRadius:9,background:'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
            <SFSymbol name="checklist" size={16} color="var(--sc-primary)" fill/>
          </div>
          <span style={{flex:1,fontSize:13.5,fontWeight:600,color:'var(--sc-text)'}}>Subitems</span>
          {subItems.length>0 && (
            <span className="sc-mono" style={{fontSize:12,fontWeight:600,color:'var(--sc-text-3)'}}>{subDone}/{subItems.length}</span>
          )}
        </div>
        {subItems.length>0 && (
          <div style={{height:4,background:'#ebe6f0'}}>
            <div style={{height:'100%',width:`${subItems.length?Math.round(subDone/subItems.length*100):0}%`,background:'var(--sc-primary)',transition:'width 300ms'}}/>
          </div>
        )}
        {subItems.map((s,i)=>(
          <div key={s.id} style={{display:'flex',alignItems:'center',gap:11,padding:'11px 16px',borderBottom:i<subItems.length-1?'0.5px solid var(--sc-separator)':'none'}}>
            <button onClick={()=>toggleSub(s.id)} style={{width:22,height:22,borderRadius:7,flexShrink:0,cursor:'pointer',
              border:`1.5px solid ${s.checked?'var(--sc-primary)':'var(--sc-border)'}`,background:s.checked?'var(--sc-primary)':'transparent',
              display:'flex',alignItems:'center',justifyContent:'center',transition:'all 200ms'}}>
              {s.checked && <svg width="10" height="8" viewBox="0 0 12 10" fill="none" style={{animation:'checkPop 320ms cubic-bezier(0.34,1.56,0.64,1) both'}}><path d="M1 5l3 3.5 7-7.5" stroke="white" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round"/></svg>}
            </button>
            <span style={{flex:1,fontSize:14,color:s.checked?'var(--sc-text-4)':'var(--sc-text)',textDecoration:s.checked?'line-through':'none',transition:'color 200ms'}}>{s.title}</span>
            <button onClick={()=>removeSub(s.id)} style={{width:26,height:26,borderRadius:'50%',background:'transparent',border:'none',cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}
              onMouseEnter={e=>e.currentTarget.style.background='var(--sc-hover)'} onMouseLeave={e=>e.currentTarget.style.background='transparent'}>
              <SFSymbol name="close" size={13} color="var(--sc-text-4)"/>
            </button>
          </div>
        ))}
        <div style={{display:'flex',alignItems:'center',gap:10,padding:'11px 16px'}}>
          <SFSymbol name="add" size={16} color="var(--sc-text-4)" style={{flexShrink:0}}/>
          <input value={newSub} onChange={e=>setNewSub(e.target.value)} onKeyDown={e=>e.key==='Enter'&&addSub()}
            placeholder="Add a subitem…"
            style={{flex:1,background:'transparent',border:'none',outline:'none',fontFamily:'var(--sc-font)',fontSize:14,color:'var(--sc-text)'}}/>
          {newSub.trim() && <button onClick={addSub} style={{background:'var(--sc-primary)',border:'none',borderRadius:8,padding:'5px 12px',color:'#fff',fontSize:12.5,fontWeight:600,cursor:'pointer',flexShrink:0}}>Add</button>}
        </div>
      </div>

      {/* ── Sublist ── */}
      {!creating && (
        <div style={{margin:'0 20px 14px'}}>
          {sublist ? (
            <button onClick={openSublist} style={{width:'100%',display:'flex',alignItems:'center',gap:13,padding:'14px 16px',
              background:'var(--sc-card)',border:'0.5px solid var(--sc-border)',borderRadius:16,cursor:'pointer',textAlign:'left'}}
              onMouseEnter={e=>e.currentTarget.style.background='var(--sc-hover)'} onMouseLeave={e=>e.currentTarget.style.background='var(--sc-card)'}>
              <div style={{width:38,height:38,borderRadius:11,background:'rgba(13,148,136,0.10)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                <SFSymbol name="account_tree" size={18} color="#0d9488" fill/>
              </div>
              <div style={{flex:1,minWidth:0}}>
                <div style={{fontSize:14,fontWeight:600,color:'var(--sc-text)'}}>{sublist.name}</div>
                <div style={{fontSize:12,color:'var(--sc-text-3)',marginTop:2}}>Sublist · {sublistDone}/{sublistTasks.length} done</div>
              </div>
              <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
            </button>
          ) : (
            <button onClick={createSublist} style={{width:'100%',padding:'13px 0',background:'transparent',color:'#0d9488',
              border:'1.5px dashed rgba(13,148,136,0.45)',borderRadius:14,fontSize:14,fontWeight:600,cursor:'pointer',
              display:'flex',alignItems:'center',justifyContent:'center',gap:7,fontFamily:'var(--sc-font)'}}>
              <SFSymbol name="account_tree" size={16} color="#0d9488"/>Add a sublist
            </button>
          )}
        </div>
      )}

      {/* ── Save button ── */}
      <div style={{padding:'0 20px'}}>
        <button onClick={save} disabled={!canSave}
          style={{width:'100%',padding:'14px 0',
            background:canSave?'var(--sc-primary)':'var(--sc-hover)',
            color:canSave?'#fff':'var(--sc-text-4)',border:'none',borderRadius:14,
            fontSize:15,fontWeight:700,cursor:canSave?'pointer':'default',
            boxShadow:canSave?'0 6px 20px rgba(94,77,187,0.35)':'none',
            transition:'all 200ms',display:'flex',alignItems:'center',justifyContent:'center',gap:7,fontFamily:'var(--sc-font)'}}>
          <SFSymbol name="check" size={16} color={canSave?'#fff':'var(--sc-text-4)'} weight={700}/>
          {creating?'Add Task':'Save Changes'}
        </button>
      </div>

      {/* ── Delete ── */}
      {!creating && (
        <div style={{padding:'10px 20px 0'}}>
          <button onClick={()=>setConfirmDelete(true)}
            style={{width:'100%',padding:'13px 0',background:'transparent',color:'var(--sc-danger)',
              border:'0.5px solid #ffdad6',borderRadius:14,fontSize:14,fontWeight:600,cursor:'pointer',
              display:'flex',alignItems:'center',justifyContent:'center',gap:6,fontFamily:'var(--sc-font)',
              transition:'background 150ms'}}
            onMouseEnter={e=>e.currentTarget.style.background='#fff5f5'}
            onMouseLeave={e=>e.currentTarget.style.background='transparent'}>
            <SFSymbol name="delete" size={15} color="var(--sc-danger)"/>Delete Task
          </button>
        </div>
      )}

      {/* ── Delete confirmation overlay ── */}
      {confirmDelete && (
        <div style={{position:'fixed',inset:0,zIndex:500,
          display:'flex',alignItems:'center',justifyContent:'center',padding:24}}>
          {/* Backdrop */}
          <div onClick={()=>setConfirmDelete(false)}
            style={{position:'absolute',inset:0,
              background:'rgba(0,0,0,0.45)',
              backdropFilter:'blur(8px)',WebkitBackdropFilter:'blur(8px)'}}/>
          {/* Dialog */}
          <div style={{position:'relative',width:'100%',maxWidth:300,
            background:'var(--sc-card)',borderRadius:22,overflow:'hidden',
            boxShadow:'0 32px 80px rgba(0,0,0,0.36)',
            animation:'springScale 320ms cubic-bezier(0.34,1.56,0.64,1) both'}}>
            {/* Icon + text */}
            <div style={{padding:'28px 24px 20px',textAlign:'center'}}>
              <div style={{width:52,height:52,borderRadius:16,background:'#ffdad6',
                display:'flex',alignItems:'center',justifyContent:'center',margin:'0 auto 16px'}}>
                <SFSymbol name="delete" size={26} color="var(--sc-danger)" fill/>
              </div>
              <div style={{fontSize:17,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.015em',marginBottom:8}}>
                Delete Task?
              </div>
              <div style={{fontSize:13.5,color:'var(--sc-text-3)',lineHeight:1.55}}>
                "<span style={{fontWeight:600,color:'var(--sc-text)'}}>{start.title}</span>" will be permanently removed. This cannot be undone.
              </div>
            </div>
            {/* Buttons */}
            <div style={{display:'flex',borderTop:'0.5px solid var(--sc-separator)'}}>
              <button onClick={()=>setConfirmDelete(false)}
                style={{flex:1,padding:'16px 0',background:'transparent',color:'var(--sc-text-2)',
                  border:'none',borderRight:'0.5px solid var(--sc-separator)',
                  fontSize:15,fontWeight:500,cursor:'pointer',fontFamily:'var(--sc-font)'}}>
                Cancel
              </button>
              <button onClick={()=>{app.deleteTask(app.selectedTaskId);app.setModal(null);}}
                style={{flex:1,padding:'16px 0',background:'transparent',color:'var(--sc-danger)',
                  border:'none',fontSize:15,fontWeight:700,cursor:'pointer',fontFamily:'var(--sc-font)'}}>
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── AddChoiceSheet ───────────────────────────────────────────
function AddChoiceSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const opts = [
    { icon:'list_alt', label:'New List', sub:'A focused collection of tasks', color:'var(--sc-primary)', bg:'var(--sc-primary-bg)', modal:'add-list' },
    { icon:'timeline', label:'New Timeline', sub:'Plan milestones chronologically', color:'#1D4ED8', bg:'#eff6ff', modal:'add-timeline' },
    { icon:'folder',   label:'New Folder', sub:'Group multiple lists together', color:'#10B981', bg:'#ecfdf5', modal:'add-folder' },
  ];
  return (
    <div style={{padding:'0 20px 28px',display:'flex',flexDirection:'column',gap:12}}>
      <div style={{padding:'4px 0 14px',textAlign:'center'}}>
        <div style={{fontSize:18,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.015em'}}>What would you like to create?</div>
      </div>
      {opts.map(o => (
        <button key={o.modal} onClick={() => app.setModal(o.modal)}
          style={{width:'100%',display:'flex',alignItems:'center',gap:16,padding:'16px 18px',
            borderRadius:18,border:`1.5px solid ${o.color}30`,background:o.bg,
            cursor:'pointer',textAlign:'left',transition:'all 180ms',
            boxShadow:`0 4px 16px ${o.color}18`}}
          onMouseEnter={e=>{e.currentTarget.style.transform='translateY(-2px)';e.currentTarget.style.boxShadow=`0 8px 24px ${o.color}28`;}}
          onMouseLeave={e=>{e.currentTarget.style.transform='translateY(0)';e.currentTarget.style.boxShadow=`0 4px 16px ${o.color}18`;}}>
          <div style={{width:52,height:52,borderRadius:15,background:o.color,
            display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,
            boxShadow:`0 6px 18px ${o.color}44`}}>
            <SFSymbol name={o.icon} size={25} color="#fff" fill/>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:16,fontWeight:700,color:'var(--sc-text)',marginBottom:3}}>{o.label}</div>
            <div style={{fontSize:13,color:'var(--sc-text-3)',lineHeight:1.4}}>{o.sub}</div>
          </div>
          <SFSymbol name="chevron_right" size={16} color={o.color}/>
        </button>
      ))}
    </div>
  );
}

// ─── AddFolderSheet ───────────────────────────────────────────
function AddFolderSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [name,  setName]  = useState('');
  const [emoji, setEmoji] = useState('🌿');
  const [color, setColor] = useState('#10B981');

  const EMOJIS = ['🌿','📁','💼','🏠','🎯','⚡','🔬','📚','🎨','🚀','💡','📊'];
  const COLORS  = ['#10B981','#5e4dbb','#1D4ED8','#ea580c','#db2777','#7c3aed','#0d9488'];

  const create = () => {
    if (!name.trim()) return;
    const newFolder = { id:`f-${Date.now()}`, name:name.trim(), emoji, color, collapsed:false };
    app.setFolders(prev => [...prev, newFolder]);
    app.setModal(null);
  };

  const canCreate = name.trim().length > 0;

  return (
    <div style={{padding:'0 20px 32px',display:'flex',flexDirection:'column',gap:18}}>
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'4px 0 4px'}}>
        <button onClick={()=>app.setModal('add-choice')}
          style={{fontSize:15,color:'var(--sc-text-3)',background:'transparent',border:'none',cursor:'pointer',fontFamily:'var(--sc-font)'}}>← Back</button>
        <span style={{fontSize:16,fontWeight:700,color:'var(--sc-text)'}}>New Folder</span>
        <button onClick={create} disabled={!canCreate}
          style={{fontSize:15,fontWeight:700,color:canCreate?'#10B981':'var(--sc-text-4)',background:'transparent',border:'none',cursor:canCreate?'pointer':'default',fontFamily:'var(--sc-font)'}}>Create</button>
      </div>

      {/* Live preview */}
      <div style={{display:'flex',alignItems:'center',gap:14,padding:'14px 16px',
        background:`linear-gradient(135deg,${color}18 0%,#fff 80%)`,
        border:`1px solid ${color}30`,borderRadius:18}}>
        <div style={{width:52,height:52,borderRadius:15,background:color,
          display:'flex',alignItems:'center',justifyContent:'center',fontSize:26,flexShrink:0,
          boxShadow:`0 6px 18px ${color}44`}}>{emoji}</div>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontSize:name?17:14,fontWeight:700,color:name?'var(--sc-text)':'var(--sc-text-4)',
            overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',transition:'font-size 150ms'}}>
            {name||'Folder name…'}
          </div>
          <div style={{fontSize:11,color:'var(--sc-text-4)',marginTop:3}}>Preview</div>
        </div>
      </div>

      {/* Name */}
      <div style={{background:'var(--sc-tinted)',borderRadius:14,padding:'12px 16px'}}>
        <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-4)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:8}}>Folder name *</div>
        <input value={name} onChange={e=>setName(e.target.value)} autoFocus
          placeholder="e.g. Personal Life, Work…"
          style={{width:'100%',fontFamily:'var(--sc-font)',fontSize:17,fontWeight:600,color:'var(--sc-text)',
            background:'transparent',border:'none',outline:'none',boxSizing:'border-box'}}/>
      </div>

      {/* Emoji */}
      <div>
        <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-4)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:10}}>Icon</div>
        <div style={{display:'flex',flexWrap:'wrap',gap:8}}>
          {EMOJIS.map(e=>(
            <button key={e} onClick={()=>setEmoji(e)}
              style={{width:42,height:42,borderRadius:12,border:`2px solid ${e===emoji?color:'var(--sc-border)'}`,
                background:e===emoji?`${color}18`:'transparent',fontSize:20,cursor:'pointer',transition:'all 150ms',
                transform:e===emoji?'scale(1.12)':'scale(1)'}}>{e}</button>
          ))}
        </div>
      </div>

      {/* Color */}
      <div>
        <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-4)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:10}}>Color</div>
        <div style={{display:'flex',gap:10}}>
          {COLORS.map(c=>(
            <button key={c} onClick={()=>setColor(c)}
              style={{width:32,height:32,borderRadius:'50%',background:c,cursor:'pointer',flexShrink:0,
                border:c===color?`3px solid ${c}`:'2px solid transparent',
                outline:c===color?'2px solid #fff':'none',outlineOffset:1,
                boxShadow:c===color?`0 3px 10px ${c}55`:'none',
                transform:c===color?'scale(1.15)':'scale(1)',transition:'all 150ms'}}/>
          ))}
        </div>
      </div>

      <button onClick={create} disabled={!canCreate}
        style={{padding:'15px 0',background:canCreate?color:'var(--sc-hover)',color:canCreate?'#fff':'var(--sc-text-4)',
          border:'none',borderRadius:14,fontSize:15,fontWeight:700,cursor:canCreate?'pointer':'default',
          fontFamily:'var(--sc-font)',boxShadow:canCreate?`0 8px 24px ${color}44`:'none',transition:'all 200ms',
          display:'flex',alignItems:'center',justifyContent:'center',gap:8}}>
        <SFSymbol name="create_new_folder" size={18} color={canCreate?'#fff':'var(--sc-text-4)'} fill/>Create Folder
      </button>
    </div>
  );
}

// ─── AddListSheet ─────────────────────────────────────────────
function AddListSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const connected = app.profile.mode === 'server';
  const [step, setStep] = useState(0);
  const [name, setName] = useState('');
  const [emoji, setEmoji] = useState('📋');
  const [color, setColor] = useState('#5e4dbb');
  const [sections, setSections] = useState([{ label: 'Tasks', emoji: '📌' }]);
  const [newSec, setNewSec] = useState('');
  const [isPublic, setIsPublic] = useState(false);

  const COLORS = ['#5e4dbb','#1D4ED8','#10B981','#ea580c','#db2777','#7c3aed','#0d9488'];
  const EMOJIS = ['📋','🚀','💼','📚','🏡','🌱','⚡','🎯','🔬','💡','🎨','📊'];

  const STEPS = connected ? [
    { label: 'Name & Look',  icon: 'edit',         desc: 'Give your list a name, icon and color.' },
    { label: 'Sections',     icon: 'view_list',     desc: 'Group tasks into sections — like columns in a project.' },
    { label: 'Visibility',   icon: 'lock',          desc: 'Choose who can see this list.' },
  ] : [
    { label: 'Name & Look',  icon: 'edit',         desc: 'Give your list a name, icon and color.' },
    { label: 'Sections',     icon: 'view_list',     desc: 'Group tasks into sections — like columns in a project.' },
  ];

  const create = () => {
    const newList = {
      id: `list-${Date.now()}`, name: name.trim() || 'New List', emoji, color, colorBg: `${color}18`,
      subtitle: '', isPublic,
      sections: sections.map((s, i) => ({ id: `sec-${Date.now()}-${i}`, label: s.label, emoji: s.emoji, tasks: [] })),
    };
    app.setLists(prev => [...prev, newList]);
    app.setCurrentListId(newList.id);
    app.setScreen('list');
    app.setModal(null);
  };

  const canNext = step === 0 ? name.trim().length > 0 : true;

  return (
    <div style={{ padding: '0 20px 32px', display: 'flex', flexDirection: 'column', gap: 0 }}>

      {/* ── Header ── */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '4px 0 18px' }}>
        <button onClick={() => step > 0 ? setStep(s => s - 1) : app.setModal(null)}
          style={{ fontSize: 15, color: 'var(--sc-text-3)', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'var(--sc-font)', padding: '4px 0' }}>
          {step === 0 ? 'Cancel' : '← Back'}
        </button>
        {/* Step dots */}
        <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
          {STEPS.map((_, i) => (
            <div key={i} style={{
              height: 6, borderRadius: 9999, transition: 'all 280ms cubic-bezier(0.34,1.2,0.64,1)',
              width: i === step ? 22 : 6,
              background: i < step ? 'var(--sc-primary)' : i === step ? 'var(--sc-primary)' : 'var(--sc-border)',
              opacity: i > step ? 0.4 : 1,
            }} />
          ))}
        </div>
        <button onClick={step < STEPS.length - 1 ? () => setStep(s => s + 1) : create} disabled={!canNext}
          style={{ fontSize: 15, fontWeight: 700, fontFamily: 'var(--sc-font)',
            color: canNext ? 'var(--sc-primary)' : 'var(--sc-text-4)',
            background: 'transparent', border: 'none', cursor: canNext ? 'pointer' : 'default', padding: '4px 0' }}>
          {step === STEPS.length - 1 ? 'Create ✓' : 'Next →'}
        </button>
      </div>

      {/* ── Step title + desc ── */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, marginBottom: 5 }}>
          <div style={{ width: 28, height: 28, borderRadius: 8, background: 'var(--sc-primary-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <SFSymbol name={STEPS[step].icon} size={14} color="var(--sc-primary)" fill />
          </div>
          <span style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-primary)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>
            Step {step + 1} of {STEPS.length}
          </span>
        </div>
        <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.02em', color: 'var(--sc-text)', marginBottom: 4 }}>{STEPS[step].label}</div>
        <div style={{ fontSize: 13, color: 'var(--sc-text-3)', lineHeight: 1.5 }}>{STEPS[step].desc}</div>
      </div>

      {/* ── Step 0: Name & Look ── */}
      {step === 0 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          {/* Live preview tile */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px',
            background: `linear-gradient(135deg, ${color}18 0%, #fff 80%)`,
            border: `1px solid ${color}30`, borderRadius: 18 }}>
            <div style={{ width: 52, height: 52, borderRadius: 15, background: `${color}22`,
              display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 26, flexShrink: 0,
              border: `1.5px solid ${color}40` }}>{emoji}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: name ? 17 : 14, fontWeight: 700, color: name ? 'var(--sc-text)' : 'var(--sc-text-4)',
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', transition: 'font-size 150ms' }}>
                {name || 'Your list name…'}
              </div>
              <div style={{ fontSize: 11, color: 'var(--sc-text-4)', marginTop: 3 }}>Preview</div>
            </div>
          </div>

          {/* Name input */}
          <div style={{ background: 'var(--sc-tinted)', borderRadius: 14, padding: '12px 16px' }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 8 }}>List name *</div>
            <input value={name} onChange={e => setName(e.target.value)} autoFocus placeholder="e.g. Work Projects, Reading Queue…"
              style={{ width: '100%', fontFamily: 'var(--sc-font)', fontSize: 17, fontWeight: 600, color: 'var(--sc-text)',
                background: 'transparent', border: 'none', outline: 'none', boxSizing: 'border-box' }} />
          </div>

          {/* Icon picker */}
          <div>
            <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Pick an icon</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {EMOJIS.map(e => (
                <button key={e} onClick={() => setEmoji(e)}
                  style={{ width: 42, height: 42, borderRadius: 12,
                    border: `2px solid ${e === emoji ? color : 'var(--sc-border)'}`,
                    background: e === emoji ? `${color}18` : 'transparent',
                    fontSize: 20, cursor: 'pointer', transition: 'all 150ms',
                    transform: e === emoji ? 'scale(1.12)' : 'scale(1)' }}>{e}</button>
              ))}
            </div>
          </div>

          {/* Color picker */}
          <div>
            <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Color</div>
            <div style={{ display: 'flex', gap: 10 }}>
              {COLORS.map(c => (
                <button key={c} onClick={() => setColor(c)}
                  style={{ width: 32, height: 32, borderRadius: '50%', background: c, cursor: 'pointer', flexShrink: 0,
                    border: c === color ? `3px solid ${c}` : '2px solid transparent',
                    outline: c === color ? '2px solid #fff' : 'none', outlineOffset: 1,
                    boxShadow: c === color ? `0 3px 10px ${c}55` : 'none',
                    transform: c === color ? 'scale(1.15)' : 'scale(1)', transition: 'all 150ms' }} />
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ── Step 1: Sections ── */}
      {step === 1 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {/* Existing sections */}
          <div style={{ background: 'var(--sc-card)', border: '0.5px solid var(--sc-border)', borderRadius: 16, overflow: 'hidden' }}>
            {sections.map((s, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px',
                borderBottom: i < sections.length - 1 ? '0.5px solid var(--sc-separator)' : 'none' }}>
                <div style={{ width: 34, height: 34, borderRadius: 10, background: 'var(--sc-primary-bg)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 18, flexShrink: 0 }}>{s.emoji}</div>
                <span style={{ flex: 1, fontSize: 14.5, fontWeight: 600, color: 'var(--sc-text)' }}>{s.label}</span>
                {sections.length > 1 && (
                  <button onClick={() => setSections(prev => prev.filter((_, j) => j !== i))}
                    style={{ width: 28, height: 28, borderRadius: '50%', background: 'var(--sc-hover)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <SFSymbol name="close" size={13} color="var(--sc-text-4)" />
                  </button>
                )}
              </div>
            ))}
          </div>

          {/* Add new section */}
          <div style={{ display: 'flex', gap: 8 }}>
            <input value={newSec} onChange={e => setNewSec(e.target.value)}
              placeholder={'Add a section, e.g. "In Progress"…'}
              onKeyDown={e => { if (e.key === 'Enter' && newSec.trim()) { setSections(p => [...p, { label: newSec.trim(), emoji: '📌' }]); setNewSec(''); } }}
              style={{ flex: 1, fontFamily: 'var(--sc-font)', fontSize: 14, color: 'var(--sc-text)',
                background: 'var(--sc-tinted)', border: '0.5px solid var(--sc-border)', borderRadius: 12,
                padding: '11px 14px', outline: 'none' }} />
            <button onClick={() => { if (!newSec.trim()) return; setSections(p => [...p, { label: newSec.trim(), emoji: '📌' }]); setNewSec(''); }}
              style={{ padding: '11px 16px', background: 'var(--sc-primary)', color: '#fff',
                border: 'none', borderRadius: 12, fontWeight: 700, fontSize: 18, cursor: 'pointer', lineHeight: 1 }}>+</button>
          </div>
          <div style={{ fontSize: 12, color: 'var(--sc-text-4)', textAlign: 'center' }}>You can always add or rename sections later.</div>
        </div>
      )}

      {/* ── Step 2: Visibility ── */}
      {step === 2 && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {[
            { val: false, icon: 'lock', title: 'Private', sub: 'Just you', desc: 'Only you can see and edit this list.', color: '#5e4dbb', bg: '#F5F3FF' },
            { val: true,  icon: 'public', title: 'Public', sub: 'Anyone with link', desc: 'Anyone with the link can view this list (read-only).', color: '#10B981', bg: '#ecfdf5' },
          ].map(opt => {
            const sel = isPublic === opt.val;
            return (
              <button key={String(opt.val)} onClick={() => setIsPublic(opt.val)}
                style={{ width: '100%', display: 'flex', alignItems: 'flex-start', gap: 14, padding: '16px',
                  borderRadius: 18, border: `1.5px solid ${sel ? opt.color : 'var(--sc-border)'}`,
                  background: sel ? opt.bg : 'var(--sc-card)', cursor: 'pointer', textAlign: 'left',
                  boxShadow: sel ? `0 4px 16px ${opt.color}22` : 'none', transition: 'all 180ms' }}>
                <div style={{ width: 44, height: 44, borderRadius: 13, flexShrink: 0, transition: 'all 180ms',
                  background: sel ? opt.color : 'var(--sc-hover)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <SFSymbol name={opt.icon} size={21} color={sel ? '#fff' : 'var(--sc-text-3)'} fill />
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--sc-text)' }}>{opt.title}</span>
                    <span style={{ fontSize: 10, fontWeight: 700, color: opt.color, background: `${opt.color}18`, borderRadius: 9999, padding: '2px 8px' }}>{opt.sub}</span>
                  </div>
                  <div style={{ fontSize: 13, color: 'var(--sc-text-3)', lineHeight: 1.45 }}>{opt.desc}</div>
                </div>
                <div style={{ width: 22, height: 22, borderRadius: '50%', flexShrink: 0, marginTop: 2,
                  border: `1.5px solid ${sel ? opt.color : 'var(--sc-border)'}`,
                  background: sel ? opt.color : 'transparent',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', transition: 'all 180ms' }}>
                  {sel && <svg width="10" height="8" viewBox="0 0 12 10"><path d="M1 5l3 3 7-7" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/></svg>}
                </div>
              </button>
            );
          })}

          {/* Summary card */}
          <div style={{ marginTop: 8, padding: '14px 16px', background: 'var(--sc-tinted)', border: '0.5px solid var(--sc-border)', borderRadius: 14 }}>
            <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 10 }}>Ready to create</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 40, height: 40, borderRadius: 12, background: `${color}22`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22, flexShrink: 0 }}>{emoji}</div>
              <div>
                <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--sc-text)' }}>{name || 'Untitled List'}</div>
                <div style={{ fontSize: 12, color: 'var(--sc-text-3)', marginTop: 2 }}>{sections.length} section{sections.length !== 1 ? 's' : ''} · {isPublic ? 'Public' : 'Private'}</div>
              </div>
            </div>
          </div>

          <button onClick={create}
            style={{ width: '100%', padding: '15px 0', background: color, color: '#fff', border: 'none', borderRadius: 14,
              fontSize: 15, fontWeight: 700, cursor: 'pointer', fontFamily: 'var(--sc-font)',
              boxShadow: `0 8px 24px ${color}44`, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
            <SFSymbol name="add_circle" size={18} color="#fff" fill /> Create List
          </button>
        </div>
      )}
    </div>
  );
}

// ─── ListsDrawerSheet ─────────────────────────────────────────
function ListsDrawerSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const connected = app.profile.mode === 'server';
  const ws = (app.workspaces||[]).find(w=>w.id===app.currentWorkspaceId);
  const [collapsedFolders,setCollapsedFolders] = useState({});

  const goToList = (id)=>{ app.setCurrentListId(id); app.setScreen('list'); app.setModal(null); };
  const goToFolder = (id)=>{ app.setCurrentFolderId(id); app.setScreen('folder'); app.setModal(null); };

  const ListRow = ({list})=>{
    const done=list.sections.flatMap(s=>s.tasks).filter(t=>t.checked).length;
    const total=list.sections.flatMap(s=>s.tasks).length;
    const pct=total?Math.round((done/total)*100):0;
    return (
      <button onClick={()=>goToList(list.id)}
        style={{width:'100%',display:'flex',alignItems:'center',gap:12,padding:'13px 16px',
          background:'transparent',border:'none',borderBottom:'0.5px solid var(--sc-separator)',
          cursor:'pointer',textAlign:'left'}}>
        <div style={{width:38,height:38,borderRadius:11,background:list.colorBg||'var(--sc-primary-bg)',
          display:'flex',alignItems:'center',justifyContent:'center',fontSize:19,flexShrink:0}}>{list.emoji}</div>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontSize:15,fontWeight:600,color:'var(--sc-text)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{list.name}</div>
          <div style={{fontSize:11.5,color:'var(--sc-text-3)',marginTop:2}}>{list.subtitle||`${total-done} remaining`}</div>
        </div>
        <div style={{display:'flex',flexDirection:'column',alignItems:'flex-end',gap:4}}>
          <span className="sc-mono" style={{fontSize:11.5,fontWeight:600,color:'var(--sc-text-3)'}}>{done}/{total}</span>
          <div style={{width:44,height:4,borderRadius:9999,background:'#ebe6f0',overflow:'hidden'}}>
            <div style={{width:`${pct}%`,height:'100%',background:list.color||'var(--sc-primary)',borderRadius:9999}}/>
          </div>
        </div>
        <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
      </button>
    );
  };

  const folders = app.folders||[];
  const allLists = app.lists||[];
  const standalone = allLists.filter(l=>!l.folderId);

  return (
    <div style={{paddingBottom:24}}>
      {/* Workspace header */}
      <div style={{padding:'4px 22px 12px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
        <div>
          <div style={{fontSize:22,fontWeight:700,letterSpacing:'-0.02em',color:'var(--sc-text)'}}>Your Lists</div>
          <div style={{fontSize:13,color:'var(--sc-text-3)',marginTop:2}}>
            {allLists.length} list{allLists.length!==1?'s':''}{connected ? ` · ${ws?.name||'Personal'}` : ' · On This Phone'}
          </div>
        </div>
        {connected && (app.workspaces||[]).length>1 && (
          <button style={{display:'flex',alignItems:'center',gap:6,padding:'7px 12px',
            background:'var(--sc-primary-bg)',borderRadius:10,border:'none',cursor:'pointer',
            fontSize:13,fontWeight:600,color:'var(--sc-primary)'}}>
            <SFSymbol name="swap_horiz" size={14} color="var(--sc-primary)"/>Switch
          </button>
        )}
      </div>

      {/* Folders */}
      {folders.map(folder=>{
        const folderLists = allLists.filter(l=>l.folderId===folder.id);
        const col = collapsedFolders[folder.id];
        return (
          <div key={folder.id}>
            <div style={{display:'flex',alignItems:'center',gap:8,padding:'8px 22px 4px'}}>
              <button onClick={()=>setCollapsedFolders(p=>({...p,[folder.id]:!p[folder.id]}))}
                style={{background:'transparent',border:'none',cursor:'pointer',padding:0,display:'flex'}}>
                <SFSymbol name={col?'chevron_right':'expand_more'} size={16} color={folder.color||'var(--sc-text-3)'}/>
              </button>
              <button onClick={()=>goToFolder(folder.id)}
                style={{display:'flex',alignItems:'center',gap:7,background:'transparent',border:'none',cursor:'pointer'}}>
                <span style={{fontSize:16}}>{folder.emoji}</span>
                <span style={{fontSize:13,fontWeight:700,color:folder.color||'var(--sc-text-2)',letterSpacing:'0.02em'}}>{folder.name.toUpperCase()}</span>
              </button>
              <span style={{fontSize:10,color:'var(--sc-text-4)',background:'var(--sc-hover)',borderRadius:9999,padding:'1px 7px'}}>{folderLists.length}</span>
            </div>
            {!col && (
              <window.Card style={{margin:'0 18px 8px'}}>
                {folderLists.length===0
                  ? <window.EmptyRow text="No lists in this folder"/>
                  : folderLists.map((l,i)=><ListRow key={l.id} list={l}/>)}
              </window.Card>
            )}
          </div>
        );
      })}

      {/* Standalone lists */}
      {standalone.length > 0 && (
        <div>
          <window.SectionHeader title="Lists" inSheet/>
          <window.Card style={{margin:'0 18px 8px'}}>
            {standalone.map(l=><ListRow key={l.id} list={l}/>)}
          </window.Card>
        </div>
      )}

      <div style={{padding:'8px 18px 0'}}>
        <button onClick={()=>app.setModal('add-list')}
          style={{width:'100%',padding:'13px 0',background:'var(--sc-primary)',color:'#fff',
            border:'none',borderRadius:14,fontSize:15,fontWeight:600,cursor:'pointer',
            display:'flex',alignItems:'center',justifyContent:'center',gap:7,
            boxShadow:'0 6px 20px rgba(94,77,187,0.35)'}}>
          <SFSymbol name="add" size={18} color="#fff" weight={600}/>New List
        </button>
      </div>
    </div>
  );
}

// ─── SettingsSheet ────────────────────────────────────────────
function SettingsSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const connected = app.profile.mode === 'server';
  const [tab,setTab] = useState('ai');
  const [aiEnabled,setAiEnabled] = useState(true);
  const [aiModel,setAiModel] = useState('openai/gpt-4o-mini');
  const [twoFA,setTwoFA] = useState(true);
  const [quotaGb,setQuotaGb] = useState('15');
  const [saved,setSaved] = useState(false);
  const fileRef = useRef(null);

  const initials = ((app.profile.fullName||app.profile.username||'U').split(' ').map(w=>w[0]).join('').toUpperCase().slice(0,2));
  const TABS = [
    {id:'ai',      label:'Sol',     icon:'auto_awesome'},
    {id:'privacy', label:'Privacy', icon:'shield_person'},
  ];
  const MODELS = [{v:'openai/gpt-4o-mini',l:'GPT-4o Mini'},{v:'openai/gpt-4o',l:'GPT-4o'},{v:'anthropic/claude-3-5-haiku',l:'Claude Haiku'},{v:'anthropic/claude-3-5-sonnet',l:'Claude Sonnet'},{v:'google/gemini-flash-1.5',l:'Gemini Flash'}];

  const [pwStep,setPwStep] = useState(0);
  const [currentPw,setCurrentPw] = useState('');
  const [newPw,setNewPw] = useState('');
  const [confirmPw,setConfirmPw] = useState('');
  const [showPwField,setShowPwField] = useState(false);
  const [pwDone,setPwDone] = useState(false);

  const [showSyncWarning, setShowSyncWarning] = useState(false);
  const [showNameDlg, setShowNameDlg] = useState(false);
  const [nameDraft, setNameDraft] = useState('');
  const nameInputRef = useRef(null);
  const openNameDlg = ()=>{ setNameDraft(app.profile.username||''); setShowNameDlg(true); setTimeout(()=>nameInputRef.current?.focus(),340); };
  const saveName = ()=>{ const v=nameDraft.trim(); if(v) app.setProfile(p=>({...p,username:v})); setShowNameDlg(false); };

  const save = ()=>{ setSaved(true); setTimeout(()=>setSaved(false),2000); };

  return (
    <div style={{paddingBottom:32}}>
      {showNameDlg && (
        <div style={{position:'fixed',inset:0,zIndex:600,display:'flex',alignItems:'center',justifyContent:'center',padding:26}}>
          <div onClick={()=>setShowNameDlg(false)} style={{position:'absolute',inset:0,background:'rgba(0,0,0,0.42)',backdropFilter:'blur(8px)',WebkitBackdropFilter:'blur(8px)',animation:'overlayIn 200ms ease both'}}/>
          <div style={{position:'relative',width:'100%',maxWidth:300,background:'var(--sc-card)',borderRadius:22,overflow:'hidden',boxShadow:'0 32px 80px rgba(0,0,0,0.36)',animation:'springScale 340ms cubic-bezier(0.34,1.56,0.64,1) both'}}>
            <div style={{padding:'24px 22px 18px'}}>
              <div style={{width:48,height:48,borderRadius:14,background:'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',margin:'0 auto 14px'}}>
                <SFSymbol name="badge" size={24} color="var(--sc-primary)" fill/>
              </div>
              <div style={{fontSize:17,fontWeight:700,color:'var(--sc-text)',textAlign:'center',marginBottom:5}}>Edit name</div>
              <div style={{fontSize:13,color:'var(--sc-text-3)',textAlign:'center',lineHeight:1.5,marginBottom:18}}>This name appears across your local tasks.</div>
              <input ref={nameInputRef} value={nameDraft} onChange={e=>setNameDraft(e.target.value)} onKeyDown={e=>{if(e.key==='Enter')saveName();if(e.key==='Escape')setShowNameDlg(false);}}
                placeholder="Your name" maxLength={40}
                style={{width:'100%',fontFamily:'var(--sc-font)',fontSize:16,fontWeight:600,color:'var(--sc-text)',background:'var(--sc-tinted)',border:'1.5px solid var(--sc-primary)',borderRadius:12,padding:'12px 14px',outline:'none',boxSizing:'border-box',textAlign:'center'}}/>
            </div>
            <div style={{display:'flex',borderTop:'0.5px solid var(--sc-separator)'}}>
              <button onClick={()=>setShowNameDlg(false)} style={{flex:1,padding:'15px 0',background:'transparent',color:'var(--sc-text-2)',border:'none',borderRight:'0.5px solid var(--sc-separator)',fontSize:15,fontWeight:500,cursor:'pointer',fontFamily:'var(--sc-font)'}}>Cancel</button>
              <button onClick={saveName} disabled={!nameDraft.trim()} style={{flex:1,padding:'15px 0',background:'transparent',color:nameDraft.trim()?'var(--sc-primary)':'var(--sc-text-4)',border:'none',fontSize:15,fontWeight:700,cursor:nameDraft.trim()?'pointer':'default',fontFamily:'var(--sc-font)'}}>Save</button>
            </div>
          </div>
        </div>
      )}
      {/* Profile card */}
      <div style={{padding:'6px 20px 16px'}}>
        <div style={{fontSize:24,fontWeight:700,letterSpacing:'-0.02em',marginBottom:16,color:'var(--sc-text)'}}>Settings</div>
        <div style={{background:'var(--sc-tinted)',borderRadius:18,padding:16,display:'flex',alignItems:'center',gap:14,
          border:'0.5px solid var(--sc-border)'}}>
          <div style={{position:'relative',flexShrink:0,cursor:'pointer'}} onClick={()=>fileRef.current?.click()}>
            <input ref={fileRef} type="file" accept="image/*" onChange={e=>{
              const f=e.target.files?.[0]; if(!f)return;
              const r=new FileReader(); r.onload=ev=>app.setProfile(p=>({...p,profileImage:ev.target.result}));
              r.readAsDataURL(f); e.target.value='';}} style={{display:'none'}}/>
            {app.profile.profileImage
              ? <img src={app.profile.profileImage} style={{width:56,height:56,borderRadius:'50%',objectFit:'cover',display:'block',boxShadow:'0 4px 14px rgba(94,77,187,0.3)'}}/>
              : <div style={{width:56,height:56,borderRadius:'50%',background:'linear-gradient(135deg,#9d8dff,#5e4dbb)',
                  display:'flex',alignItems:'center',justifyContent:'center',boxShadow:'0 4px 14px rgba(94,77,187,0.3)'}}>
                  <span style={{fontSize:19,fontWeight:700,color:'#fff'}}>{initials}</span>
                </div>}
            <div style={{position:'absolute',bottom:0,right:0,width:20,height:20,borderRadius:'50%',
              background:'var(--sc-primary)',border:'2px solid #fff',display:'flex',alignItems:'center',justifyContent:'center'}}>
              <SFSymbol name="photo_camera" size={10} color="#fff" fill/>
            </div>
          </div>
          <div style={{flex:1,minWidth:0}}>
            {connected ? (
              <>
                <div style={{display:'flex',alignItems:'center',gap:8}}>
                  <span style={{fontSize:16,fontWeight:700,color:'var(--sc-text)'}}>{app.profile.fullName||app.profile.username}</span>
                  {app.profile.isAdmin && <span style={{fontSize:9,fontWeight:700,color:'var(--sc-primary)',background:'var(--sc-primary-bg)',borderRadius:9999,padding:'2px 8px',textTransform:'uppercase',letterSpacing:'0.04em'}}>Admin</span>}
                </div>
                <div style={{fontSize:12,color:'var(--sc-text-3)',marginTop:2}}>@{app.profile.username}</div>
                <div style={{fontSize:11.5,color:'var(--sc-text-4)',marginTop:1,overflow:'hidden',textOverflow:'ellipsis'}}>{app.profile.email}</div>
              </>
            ) : (
              <>
                <div style={{fontSize:16,fontWeight:700,color:'var(--sc-text)',marginBottom:6}}>
                  {app.profile.username||'My Tasks'}
                </div>
                <button onClick={openNameDlg} style={{fontSize:12,color:'var(--sc-primary)',background:'transparent',border:'none',cursor:'pointer',padding:0,fontFamily:'var(--sc-font)',display:'flex',alignItems:'center',gap:4}}>
                  <SFSymbol name="edit" size={12} color="var(--sc-primary)"/>Tap to edit name
                </button>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Admin tabs (server + admin only) */}
      {connected && app.profile.isAdmin && (
        <div style={{padding:'0 20px 16px'}}>
          <div style={{display:'flex',gap:3,background:'var(--sc-primary-bg)',borderRadius:14,padding:4,marginBottom:16}}>
            {TABS.map(t=>{
              const a=tab===t.id; const isDanger=t.id==='danger';
              return (
                <button key={t.id} onClick={()=>setTab(t.id)}
                  style={{flex:1,display:'flex',alignItems:'center',justifyContent:'center',gap:4,
                    fontFamily:'var(--sc-font)',fontSize:11.5,fontWeight:600,
                    color:a?'#fff':(isDanger?'var(--sc-danger)':'var(--sc-primary)'),
                    background:a?(isDanger?'var(--sc-danger)':'var(--sc-primary)'):'transparent',
                    border:'none',borderRadius:10,padding:'7px 4px',cursor:'pointer',transition:'all 150ms',whiteSpace:'nowrap'}}>
                  <SFSymbol name={t.icon} size={13} color={a?'#fff':(isDanger?'var(--sc-danger)':'var(--sc-primary)')}/>
                  {t.label}
                </button>
              );
            })}
          </div>

          {/* Sol */}
          {tab==='ai' && (
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              <div style={{background:'var(--sc-card)',borderRadius:16,padding:16,border:'0.5px solid var(--sc-border)',display:'flex',alignItems:'center',justifyContent:'space-between',gap:12}}>
                <div>
                  <div style={{fontSize:13,fontWeight:600,color:'var(--sc-text)'}}>Enable Sol</div>
                  <div style={{fontSize:12,color:'var(--sc-text-3)',marginTop:2}}>Show the AI bubble for all users.</div>
                </div>
                <button onClick={()=>setAiEnabled(v=>!v)}
                  style={{width:44,height:24,borderRadius:12,background:aiEnabled?'var(--sc-primary)':'#e8e4f0',border:'none',cursor:'pointer',position:'relative',flexShrink:0,transition:'background 200ms'}}>
                  <span style={{position:'absolute',top:3,left:aiEnabled?23:3,width:18,height:18,borderRadius:'50%',background:'#fff',boxShadow:'0 1px 4px rgba(0,0,0,0.2)',transition:'left 200ms'}}/>
                </button>
              </div>
              <div style={{background:'var(--sc-card)',borderRadius:16,padding:16,border:'0.5px solid var(--sc-border)'}}>
                <div style={{fontSize:12,fontWeight:600,color:'var(--sc-text-3)',textTransform:'uppercase',letterSpacing:'0.07em',marginBottom:10}}>AI Model</div>
                <div style={{display:'flex',flexDirection:'column',gap:6}}>
                  {MODELS.map(m=>(
                    <button key={m.v} onClick={()=>setAiModel(m.v)}
                      style={{display:'flex',alignItems:'center',gap:10,padding:'10px 12px',borderRadius:10,
                        border:`1px solid ${aiModel===m.v?'var(--sc-primary)':'var(--sc-border)'}`,
                        background:aiModel===m.v?'var(--sc-primary-bg)':'transparent',cursor:'pointer',textAlign:'left'}}>
                      <div style={{width:8,height:8,borderRadius:'50%',background:aiModel===m.v?'var(--sc-primary)':'#d6d0e0',flexShrink:0}}/>
                      <span style={{fontSize:13,fontWeight:aiModel===m.v?600:400,color:aiModel===m.v?'var(--sc-primary)':'var(--sc-text)'}}>{m.l}</span>
                    </button>
                  ))}
                </div>
              </div>
              <button onClick={save} style={{width:'100%',padding:'13px',background:saved?'#ecfdf5':'var(--sc-primary)',color:saved?'#10B981':'#fff',border:saved?'1px solid #a7f3d0':'none',borderRadius:12,fontSize:14,fontWeight:600,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',gap:6}}>
                <SFSymbol name={saved?'check':'save'} size={15} color={saved?'#10B981':'#fff'}/>{saved?'Saved!':'Save'}
              </button>
            </div>
          )}

          {/* Privacy — change password wizard */}
          {tab==='privacy' && (
            <div style={{display:'flex',flexDirection:'column',gap:14}}>
              {!pwDone ? (
                <div style={{background:'var(--sc-card)',borderRadius:16,border:'0.5px solid var(--sc-border)',overflow:'hidden'}}>
                  {/* Step indicator */}
                  <div style={{padding:'16px 16px 12px',borderBottom:'0.5px solid var(--sc-separator)',display:'flex',alignItems:'center',gap:12}}>
                    <div style={{width:36,height:36,borderRadius:10,background:'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                      <SFSymbol name="lock_reset" size={18} color="var(--sc-primary)" fill/>
                    </div>
                    <div style={{flex:1}}>
                      <div style={{fontSize:14,fontWeight:700,color:'var(--sc-text)'}}>Change Password</div>
                      <div style={{fontSize:11.5,color:'var(--sc-text-4)',marginTop:2}}>Step {pwStep+1} of 3</div>
                    </div>
                    <div style={{display:'flex',gap:4}}>
                      {[0,1,2].map(i=>(
                        <div key={i} style={{height:4,borderRadius:9999,transition:'all 240ms',
                          width:i===pwStep?18:6,
                          background:i<=pwStep?'var(--sc-primary)':'var(--sc-border)'}}/>
                      ))}
                    </div>
                  </div>

                  {/* Step 0 — current password */}
                  {pwStep===0 && (
                    <div style={{padding:'18px 16px 16px',display:'flex',flexDirection:'column',gap:14}}>
                      <div style={{fontSize:13,color:'var(--sc-text-3)',lineHeight:1.5}}>Enter your current password to continue.</div>
                      <div style={{background:'var(--sc-tinted)',borderRadius:12,padding:'12px 14px'}}>
                        <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-4)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:8}}>Current password</div>
                        <div style={{display:'flex',alignItems:'center',gap:8}}>
                          <input type={showPwField?'text':'password'} value={currentPw} onChange={e=>setCurrentPw(e.target.value)}
                            placeholder="••••••••" autoFocus
                            style={{flex:1,fontFamily:'var(--sc-font)',fontSize:15,color:'var(--sc-text)',background:'transparent',border:'none',outline:'none',letterSpacing:showPwField?0:'0.1em'}}/>
                          <button onClick={()=>setShowPwField(s=>!s)} style={{fontSize:11,fontWeight:700,color:'var(--sc-primary)',background:'transparent',border:'none',cursor:'pointer',fontFamily:'var(--sc-font)',flexShrink:0,padding:0}}>
                            {showPwField?'Hide':'Show'}
                          </button>
                        </div>
                      </div>
                      <button onClick={()=>{if(currentPw.trim())setPwStep(1);}}
                        style={{padding:'13px',background:currentPw.trim()?'var(--sc-primary)':'var(--sc-hover)',color:currentPw.trim()?'#fff':'var(--sc-text-4)',border:'none',borderRadius:12,fontSize:14,fontWeight:700,cursor:currentPw.trim()?'pointer':'default',fontFamily:'var(--sc-font)',transition:'all 180ms',display:'flex',alignItems:'center',justifyContent:'center',gap:7}}>
                        Continue <SFSymbol name="arrow_forward" size={15} color={currentPw.trim()?'#fff':'var(--sc-text-4)'}/>
                      </button>
                    </div>
                  )}

                  {/* Step 1 — new password */}
                  {pwStep===1 && (
                    <div style={{padding:'18px 16px 16px',display:'flex',flexDirection:'column',gap:14}}>
                      <div style={{fontSize:13,color:'var(--sc-text-3)',lineHeight:1.5}}>Choose a strong new password.</div>
                      <div style={{background:'var(--sc-tinted)',borderRadius:12,padding:'12px 14px'}}>
                        <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-4)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:8}}>New password</div>
                        <input type="password" value={newPw} onChange={e=>setNewPw(e.target.value)} placeholder="Min. 8 characters" autoFocus
                          style={{width:'100%',fontFamily:'var(--sc-font)',fontSize:15,color:'var(--sc-text)',background:'transparent',border:'none',outline:'none',letterSpacing:'0.1em',boxSizing:'border-box'}}/>
                      </div>
                      {newPw.length > 0 && (
                        <div style={{display:'flex',gap:4}}>
                          {['Length','Uppercase','Number'].map((label,i)=>{
                            const ok = [newPw.length>=8, /[A-Z]/.test(newPw), /[0-9]/.test(newPw)][i];
                            return <div key={label} style={{flex:1,textAlign:'center',padding:'5px 0',borderRadius:8,fontSize:10,fontWeight:700,background:ok?'#ecfdf5':'var(--sc-hover)',color:ok?'#10B981':'var(--sc-text-4)',transition:'all 180ms'}}>{ok?'✓ ':''}{label}</div>;
                          })}
                        </div>
                      )}
                      <div style={{display:'flex',gap:8}}>
                        <button onClick={()=>setPwStep(0)} style={{flex:1,padding:'13px',background:'var(--sc-hover)',color:'var(--sc-text-3)',border:'none',borderRadius:12,fontSize:14,fontWeight:600,cursor:'pointer',fontFamily:'var(--sc-font)'}}>Back</button>
                        <button onClick={()=>{if(newPw.length>=8)setPwStep(2);}}
                          style={{flex:2,padding:'13px',background:newPw.length>=8?'var(--sc-primary)':'var(--sc-hover)',color:newPw.length>=8?'#fff':'var(--sc-text-4)',border:'none',borderRadius:12,fontSize:14,fontWeight:700,cursor:newPw.length>=8?'pointer':'default',fontFamily:'var(--sc-font)',transition:'all 180ms',display:'flex',alignItems:'center',justifyContent:'center',gap:7}}>
                          Continue <SFSymbol name="arrow_forward" size={15} color={newPw.length>=8?'#fff':'var(--sc-text-4)'}/>
                        </button>
                      </div>
                    </div>
                  )}

                  {/* Step 2 — confirm */}
                  {pwStep===2 && (
                    <div style={{padding:'18px 16px 16px',display:'flex',flexDirection:'column',gap:14}}>
                      <div style={{fontSize:13,color:'var(--sc-text-3)',lineHeight:1.5}}>Re-enter your new password to confirm.</div>
                      <div style={{background:'var(--sc-tinted)',borderRadius:12,padding:'12px 14px',border:`1px solid ${confirmPw&&confirmPw!==newPw?'#ffdad6':confirmPw===newPw&&confirmPw?'#a7f3d0':'var(--sc-border)'}`,transition:'border-color 180ms'}}>
                        <div style={{fontSize:10,fontWeight:700,color:'var(--sc-text-4)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:8}}>Confirm new password</div>
                        <input type="password" value={confirmPw} onChange={e=>setConfirmPw(e.target.value)} placeholder="••••••••" autoFocus
                          style={{width:'100%',fontFamily:'var(--sc-font)',fontSize:15,color:'var(--sc-text)',background:'transparent',border:'none',outline:'none',letterSpacing:'0.1em',boxSizing:'border-box'}}/>
                      </div>
                      {confirmPw && confirmPw!==newPw && <div style={{fontSize:12,color:'var(--sc-danger)',fontWeight:500}}>Passwords don't match.</div>}
                      <div style={{display:'flex',gap:8}}>
                        <button onClick={()=>setPwStep(1)} style={{flex:1,padding:'13px',background:'var(--sc-hover)',color:'var(--sc-text-3)',border:'none',borderRadius:12,fontSize:14,fontWeight:600,cursor:'pointer',fontFamily:'var(--sc-font)'}}>Back</button>
                        <button onClick={()=>{if(confirmPw===newPw&&confirmPw){setPwDone(true);setCurrentPw('');setNewPw('');setConfirmPw('');setShowPwField(false);}}}
                          style={{flex:2,padding:'13px',background:confirmPw===newPw&&confirmPw?'var(--sc-primary)':'var(--sc-hover)',color:confirmPw===newPw&&confirmPw?'#fff':'var(--sc-text-4)',border:'none',borderRadius:12,fontSize:14,fontWeight:700,cursor:confirmPw===newPw&&confirmPw?'pointer':'default',fontFamily:'var(--sc-font)',transition:'all 180ms',display:'flex',alignItems:'center',justifyContent:'center',gap:7}}>
                          <SFSymbol name="check" size={15} color={confirmPw===newPw&&confirmPw?'#fff':'var(--sc-text-4)'} weight={700}/>Save Password
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ) : (
                /* Success state */
                <div style={{background:'#ecfdf5',border:'1px solid #a7f3d0',borderRadius:16,padding:'22px 18px',display:'flex',flexDirection:'column',alignItems:'center',gap:12,animation:'springUp 300ms cubic-bezier(0.34,1.2,0.64,1) both'}}>
                  <div style={{width:48,height:48,borderRadius:'50%',background:'#10B981',display:'flex',alignItems:'center',justifyContent:'center',boxShadow:'0 6px 20px rgba(16,185,129,0.35)',animation:'springScale 350ms cubic-bezier(0.34,1.56,0.64,1) 100ms both'}}>
                    <SFSymbol name="check" size={24} color="#fff" weight={700}/>
                  </div>
                  <div style={{textAlign:'center'}}>
                    <div style={{fontSize:15,fontWeight:700,color:'#065f46',marginBottom:4}}>Password updated!</div>
                    <div style={{fontSize:13,color:'#6b7280',lineHeight:1.5}}>Your password has been changed successfully.</div>
                  </div>
                  <button onClick={()=>{setPwDone(false);setPwStep(0);}}
                    style={{padding:'10px 22px',background:'#10B981',color:'#fff',border:'none',borderRadius:12,fontSize:13,fontWeight:700,cursor:'pointer',fontFamily:'var(--sc-font)'}}>
                    Done
                  </button>
                </div>
              )}
            </div>
          )}

          {/* Web interface note */}
          <div style={{margin:'14px 0 0',padding:'12px 14px',background:'var(--sc-tinted)',borderRadius:14,border:'0.5px solid var(--sc-border)',display:'flex',alignItems:'flex-start',gap:10}}>
            <SFSymbol name="open_in_browser" size={16} color="var(--sc-primary)" style={{marginTop:1,flexShrink:0}}/>
            <div style={{fontSize:12,color:'var(--sc-text-3)',lineHeight:1.55}}>
              <span style={{fontWeight:600,color:'var(--sc-text-2)'}}>More settings available </span>
              in the web interface of your self-hosted instance — including storage quotas, server config, SMTP, backups and danger zone.
            </div>
          </div>
        </div>
      )}

      {/* Storage mode + sign out */}
      <div style={{padding:'0 20px'}}>
        {connected && (
          <>
            <window.SectionHeader title="Security" inSheet/>
            <window.Card style={{margin:'0 0 14px'}}>
              <button onClick={()=>{ if(app.profile.totpEnabled){ app.setProfile(p=>({...p,totpEnabled:false})); } else { app.setModal('two-fa'); } }}
                style={{width:'100%',display:'flex',alignItems:'center',gap:12,padding:'14px 16px',background:'transparent',border:'none',borderBottom:'0.5px solid var(--sc-separator)',cursor:'pointer',textAlign:'left'}}>
                <div style={{width:38,height:38,borderRadius:11,background:app.profile.totpEnabled?'#ecfdf5':'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                  <SFSymbol name="shield_lock" size={18} color={app.profile.totpEnabled?'#10B981':'var(--sc-primary)'} fill/>
                </div>
                <div style={{flex:1}}>
                  <div style={{fontSize:14.5,fontWeight:600,color:'var(--sc-text)'}}>Two-Factor Authentication</div>
                  <div style={{fontSize:12,color:app.profile.totpEnabled?'#10B981':'var(--sc-text-3)',marginTop:2,fontWeight:app.profile.totpEnabled?600:400}}>{app.profile.totpEnabled?'● Enabled · TOTP active':'Add an extra layer of security'}</div>
                </div>
                <span style={{fontSize:12.5,fontWeight:700,color:app.profile.totpEnabled?'var(--sc-danger)':'var(--sc-primary)'}}>{app.profile.totpEnabled?'Disable':'Enable'}</span>
              </button>
              <button onClick={()=>setTab('privacy')}
                style={{width:'100%',display:'flex',alignItems:'center',gap:12,padding:'14px 16px',background:'transparent',border:'none',cursor:'pointer',textAlign:'left'}}>
                <div style={{width:38,height:38,borderRadius:11,background:'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                  <SFSymbol name="lock_reset" size={18} color="var(--sc-primary)" fill/>
                </div>
                <div style={{flex:1}}>
                  <div style={{fontSize:14.5,fontWeight:600,color:'var(--sc-text)'}}>Change Password</div>
                  <div style={{fontSize:12,color:'var(--sc-text-3)',marginTop:2}}>Update your account password</div>
                </div>
                <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
              </button>
            </window.Card>
          </>
        )}
        {connected ? (
          <>
            <window.SectionHeader title="Storage Mode" inSheet/>
            <window.Card style={{margin:'0 0 14px'}}>
              {[{icon:'smartphone',title:'On This Phone',desc:'Private · No internet required',val:'local'},{icon:'cloud',title:'Connected to Server',desc:app.profile.serverUrl||'Sync to your self-hosted instance',val:'server'}].map((opt,i)=>(
                <button key={opt.val} onClick={()=>{if(opt.val==='server'){app.setModal(null);app.setScreen('login');}else app.setProfile(p=>({...p,mode:'local'}));}}
                  style={{width:'100%',display:'flex',alignItems:'center',gap:12,padding:'14px 16px',background:'transparent',border:'none',borderBottom:i===0?'0.5px solid var(--sc-separator)':'none',cursor:'pointer',textAlign:'left'}}>
                  <div style={{width:38,height:38,borderRadius:11,background:app.profile.mode===opt.val?'var(--sc-primary)':'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'background 200ms'}}>
                    <SFSymbol name={opt.icon} size={18} color={app.profile.mode===opt.val?'#fff':'var(--sc-primary)'} fill/>
                  </div>
                  <div style={{flex:1}}>
                    <div style={{fontSize:14.5,fontWeight:600,color:'var(--sc-text)'}}>{opt.title}</div>
                    <div style={{fontSize:12,color:'var(--sc-text-3)',marginTop:2}}>{opt.desc}</div>
                  </div>
                  {app.profile.mode===opt.val && <SFSymbol name="check_circle" size={18} color="var(--sc-primary)" fill/>}
                </button>
              ))}
            </window.Card>
          </>
        ) : (
          <>
            <window.SectionHeader title="Sync & Backup" inSheet/>
            <window.Card style={{margin:'0 0 14px'}}>
              <div style={{padding:'16px'}}>
                <div style={{display:'flex',alignItems:'center',gap:12,marginBottom:14}}>
                  <div style={{width:40,height:40,borderRadius:12,background:'var(--sc-primary-bg)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
                    <SFSymbol name="smartphone" size={20} color="var(--sc-primary)" fill/>
                  </div>
                  <div>
                    <div style={{fontSize:15,fontWeight:600,color:'var(--sc-text)'}}>On This Phone</div>
                    <div style={{fontSize:12.5,color:'var(--sc-text-3)',marginTop:2}}>Tasks stored locally · No account needed</div>
                  </div>
                </div>
                <div style={{height:1,background:'var(--sc-border)',marginBottom:14}}/>
                <div style={{fontSize:12,fontWeight:600,color:'var(--sc-text-3)',textTransform:'uppercase',letterSpacing:'0.07em',marginBottom:8}}>Unlock with a server</div>
                {[
                  {icon:'auto_awesome',label:'AI task assistant'},
                  {icon:'cloud_upload',label:'File sharing & storage'},
                  {icon:'group',label:'Team workspaces'},
                  {icon:'sync',label:'Sync across devices'},
                ].map(f=>(
                  <div key={f.label} style={{display:'flex',alignItems:'center',gap:9,marginBottom:7}}>
                    <SFSymbol name={f.icon} size={14} color="var(--sc-primary)"/>
                    <span style={{fontSize:13,color:'var(--sc-text-2)'}}>{f.label}</span>
                  </div>
                ))}
                <button onClick={()=>setShowSyncWarning(true)}
                  style={{width:'100%',marginTop:14,padding:'12px 0',background:'var(--sc-primary)',color:'#fff',border:'none',borderRadius:12,fontSize:14,fontWeight:600,cursor:'pointer',display:'flex',alignItems:'center',justifyContent:'center',gap:7,boxShadow:'0 6px 20px rgba(94,77,187,0.35)'}}>
                  <SFSymbol name="cloud" size={16} color="#fff" fill/>
                  Connect to Self-Hosted Server
                </button>
              </div>
            </window.Card>

            {/* Sync warning overlay */}
            {showSyncWarning && (
              <div style={{position:'fixed',inset:0,zIndex:500,display:'flex',alignItems:'flex-end',justifyContent:'center',padding:'0 0 32px'}}>
                <div onClick={()=>setShowSyncWarning(false)} style={{position:'absolute',inset:0,background:'rgba(0,0,0,0.45)',backdropFilter:'blur(6px)',WebkitBackdropFilter:'blur(6px)'}}/>
                <div style={{position:'relative',width:'100%',maxWidth:360,background:'var(--sc-card)',borderRadius:24,padding:'24px 22px 20px',
                  boxShadow:'0 24px 60px rgba(0,0,0,0.30)',animation:'springUp 340ms cubic-bezier(0.34,1.2,0.64,1) both',margin:'0 16px'}}>
                  <div style={{width:44,height:44,borderRadius:14,background:'#fff5d6',display:'flex',alignItems:'center',justifyContent:'center',marginBottom:14}}>
                    <SFSymbol name="warning" size={22} color="#d97706" fill/>
                  </div>
                  <div style={{fontSize:17,fontWeight:700,color:'var(--sc-text)',marginBottom:8,letterSpacing:'-0.015em'}}>
                    Local data will not sync
                  </div>
                  <div style={{fontSize:13.5,color:'var(--sc-text-3)',lineHeight:1.55,marginBottom:20}}>
                    Tasks saved on this phone are <span style={{fontWeight:600,color:'var(--sc-text-2)'}}>not automatically transferred</span> to your server. 
                    Once connected, your app will show data from the server only. 
                    Local tasks will remain on this device but won't be visible until you export them manually.
                  </div>
                  <div style={{display:'flex',gap:10}}>
                    <button onClick={()=>setShowSyncWarning(false)}
                      style={{flex:1,padding:'13px 0',background:'var(--sc-hover)',color:'var(--sc-text-2)',border:'none',borderRadius:14,fontSize:14,fontWeight:600,cursor:'pointer'}}>
                      Cancel
                    </button>
                    <button onClick={()=>{setShowSyncWarning(false);app.setModal(null);app.setScreen('login');}}
                      style={{flex:1,padding:'13px 0',background:'var(--sc-primary)',color:'#fff',border:'none',borderRadius:14,fontSize:14,fontWeight:600,cursor:'pointer',
                        boxShadow:'0 4px 14px rgba(94,77,187,0.35)'}}>
                      Continue
                    </button>
                  </div>
                </div>
              </div>
            )}
          </>
        )}
        <button onClick={()=>{app.setModal(null);app.setScreen('welcome');}}
          style={{width:'100%',background:'#fff5f5',border:'0.5px solid #ffdad6',borderRadius:14,padding:'14px 0',color:'var(--sc-danger)',fontSize:15,fontWeight:600,cursor:'pointer'}}>
          {connected?'Sign Out':'Reset & Start Over'}
        </button>
      </div>
    </div>
  );
}

// ─── AIAssistantSheet ─────────────────────────────────────────
function AIAssistantSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [input,setInput] = useState('');
  const [typing,setTyping] = useState(false);
  const msgs = app.aiMessages || [];
  const scrollRef = useRef(null);

  useEffect(()=>{ if(scrollRef.current) scrollRef.current.scrollTop=scrollRef.current.scrollHeight; },[msgs]);

  const send = ()=>{
    const t=input.trim(); if(!t)return;
    app.addAIMessage({id:Date.now(),role:'user',content:t});
    setInput('');
    setTyping(true);
    setTimeout(()=>{
      setTyping(false);
      app.addAIMessage({id:Date.now()+1,role:'assistant',content:"I'm processing your request. Based on your current tasks, I'd suggest focusing on high-priority items first. Would you like me to help you organize your schedule?"});
    },1400);
  };

  return (
    <div style={{display:'flex',flexDirection:'column',height:520}}>
      {/* Header */}
      <div style={{padding:'6px 20px 12px',borderBottom:'0.5px solid var(--sc-border)',flexShrink:0}}>
        <div style={{display:'flex',alignItems:'center',gap:12,justifyContent:'space-between'}}>
          <div style={{display:'flex',alignItems:'center',gap:10}}>
            <div style={{width:38,height:38,borderRadius:12,background:'linear-gradient(135deg,#b59cff,#5e4dbb)',display:'flex',alignItems:'center',justifyContent:'center'}}>
              <SFSymbol name="auto_awesome" size={19} color="#fff" fill/>
            </div>
            <div>
              <div style={{fontSize:16,fontWeight:700,color:'var(--sc-text)'}}>Sol</div>
              <div style={{fontSize:11,color:'var(--sc-success)',fontWeight:600}}>● Online</div>
            </div>
          </div>
          <button onClick={()=>app.setModal(null)} style={{width:30,height:30,borderRadius:'50%',background:'var(--sc-hover)',border:'none',display:'flex',alignItems:'center',justifyContent:'center',cursor:'pointer'}}>
            <SFSymbol name="close" size={16} color="var(--sc-text-3)"/>
          </button>
        </div>
      </div>
      {/* Messages */}
      <div ref={scrollRef} className="sc-scroll" style={{flex:1,overflowY:'auto',padding:'14px 18px',display:'flex',flexDirection:'column',gap:12}}>
        {msgs.map(msg=>(
          <div key={msg.id} style={{display:'flex',alignItems:'flex-start',gap:8,flexDirection:msg.role==='user'?'row-reverse':'row'}}>
            {msg.role==='assistant' && (
              <div style={{width:28,height:28,borderRadius:9,background:'linear-gradient(135deg,#b59cff,#5e4dbb)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,marginTop:2}}>
                <SFSymbol name="auto_awesome" size={13} color="#fff" fill/>
              </div>
            )}
            <div style={{maxWidth:'78%',padding:'10px 14px',borderRadius:msg.role==='user'?'16px 16px 4px 16px':'16px 16px 16px 4px',
              background:msg.role==='user'?'var(--sc-primary)':'var(--sc-tinted)',
              color:msg.role==='user'?'#fff':'var(--sc-text)',
              fontSize:13.5,lineHeight:1.5}}>
              {msg.content}
            </div>
          </div>
        ))}
        {typing && (
          <div style={{display:'flex',alignItems:'flex-start',gap:8}}>
            <div style={{width:28,height:28,borderRadius:9,background:'linear-gradient(135deg,#b59cff,#5e4dbb)',display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <SFSymbol name="auto_awesome" size={13} color="#fff" fill/>
            </div>
            <div style={{padding:'12px 16px',borderRadius:'16px 16px 16px 4px',background:'var(--sc-tinted)',display:'flex',gap:4,alignItems:'center'}}>
              {[0,1,2].map(i=>(
                <div key={i} style={{width:6,height:6,borderRadius:'50%',background:'var(--sc-text-4)',
                  animation:`aiDotBounce 1.2s ease-in-out ${i*0.2}s infinite`}}/>
              ))}
            </div>
          </div>
        )}
      </div>
      {/* Input */}
      <div style={{padding:'10px 14px 20px',borderTop:'0.5px solid var(--sc-border)',flexShrink:0}}>
        <div style={{display:'flex',gap:8,background:'var(--sc-tinted)',borderRadius:16,padding:'8px 8px 8px 14px',border:'0.5px solid var(--sc-border)'}}>
          <input value={input} onChange={e=>setInput(e.target.value)}
            onKeyDown={e=>e.key==='Enter'&&send()}
            placeholder="Ask Sol anything…"
            style={{flex:1,background:'transparent',border:'none',outline:'none',
              fontFamily:'var(--sc-font)',fontSize:14,color:'var(--sc-text)'}}/>
          <button onClick={send} disabled={!input.trim()}
            style={{width:36,height:36,borderRadius:12,
              background:input.trim()?'var(--sc-primary)':'var(--sc-border)',
              border:'none',cursor:input.trim()?'pointer':'default',
              display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,transition:'background 150ms'}}>
            <SFSymbol name="send" size={16} color="#fff" fill/>
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── FileDetailSheet ─────────────────────────────────────────
function FileDetailSheet() {
  const app = window.useApp();
  const { SFSymbol, FileBadge } = window;
  const [copied, setCopied] = useState(false);
  const file = (app.files||[]).find(f=>f.id===app.currentFileId);
  if (!file) return <div style={{padding:24,color:'var(--sc-text-3)'}}>File not found.</div>;
  const fmtSize = b => b>=1e6?`${(b/1e6).toFixed(1)} MB`:`${Math.round(b/1e3)} KB`;
  const fmtDate = iso => new Date(iso).toLocaleDateString('en-US',{month:'long',day:'numeric',year:'numeric'});
  const isImage = file.mimeType?.includes('image');
  const isPdf   = file.mimeType?.includes('pdf');
  const copyLink = ()=>{ setCopied(true); setTimeout(()=>setCopied(false),1800); };
  return (
    <div style={{paddingBottom:32}}>
      {/* Preview */}
      <div style={{margin:'6px 20px 16px',background:'var(--sc-tinted)',borderRadius:20,
        minHeight:140,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',
        border:'0.5px solid var(--sc-border)',overflow:'hidden',position:'relative'}}>
        {isImage ? (
          <div style={{width:'100%',height:180,background:'linear-gradient(135deg,#ede9ff,#fdf2f8)',
            display:'flex',alignItems:'center',justifyContent:'center'}}>
            <SFSymbol name="image" size={64} color="var(--sc-border)"/>
          </div>
        ) : isPdf ? (
          <div style={{width:'100%',height:180,background:'linear-gradient(135deg,#fff5f5,#fff)',
            display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:8}}>
            <SFSymbol name="picture_as_pdf" size={56} color="#dc2626"/>
            <span style={{fontSize:12,color:'var(--sc-text-4)',fontWeight:500}}>PDF Document</span>
          </div>
        ) : (
          <div style={{width:'100%',height:140,display:'flex',flexDirection:'column',
            alignItems:'center',justifyContent:'center',gap:10}}>
            <FileBadge mime={file.mimeType||''} size={64}/>
            <span style={{fontSize:12,color:'var(--sc-text-4)'}}>No preview available</span>
          </div>
        )}
      </div>
      {/* Info */}
      <div style={{padding:'0 20px 16px'}}>
        <div style={{fontSize:18,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.01em',
          wordBreak:'break-all',lineHeight:1.3,marginBottom:6}}>{file.name}</div>
        <div style={{display:'flex',alignItems:'center',gap:8,flexWrap:'wrap',marginBottom:8}}>
          <span style={{fontSize:12,color:'var(--sc-text-4)'}}>{fmtSize(file.size)}</span>
          <span style={{color:'var(--sc-separator)'}}>·</span>
          <span style={{fontSize:12,color:'var(--sc-text-4)'}}>{fmtDate(file.createdAt)}</span>
          {file.hasPassword && <span style={{display:'flex',alignItems:'center',gap:3,fontSize:11,
            color:'var(--sc-text-4)',background:'var(--sc-hover)',borderRadius:9999,padding:'2px 8px'}}>
            <SFSymbol name="lock" size={10} color="var(--sc-text-4)"/>Password
          </span>}
        </div>
        <span style={{fontSize:11,fontWeight:700,color:file.isPublic?'var(--sc-primary)':'var(--sc-text-3)',
          background:file.isPublic?'var(--sc-primary-bg)':'var(--sc-hover)',
          borderRadius:9999,padding:'3px 10px',textTransform:'uppercase',letterSpacing:'0.04em'}}>
          {file.isPublic?'Public':'Private'}
        </span>
      </div>
      {/* Actions */}
      <div style={{padding:'0 20px',display:'flex',flexDirection:'column',gap:10}}>
        <button style={{width:'100%',padding:'14px 0',background:'var(--sc-primary)',color:'#fff',
          border:'none',borderRadius:16,fontSize:15,fontWeight:600,cursor:'pointer',
          display:'flex',alignItems:'center',justifyContent:'center',gap:8,
          boxShadow:'0 6px 20px rgba(94,77,187,0.35)'}}>
          <SFSymbol name="download" size={18} color="#fff"/>Download
        </button>
        {file.isPublic && (
          <button onClick={copyLink} style={{width:'100%',padding:'13px 0',
            background:copied?'#ecfdf5':'var(--sc-primary-bg)',
            color:copied?'#10B981':'var(--sc-primary)',
            border:copied?'1px solid #a7f3d0':'none',
            borderRadius:16,fontSize:14,fontWeight:600,cursor:'pointer',
            display:'flex',alignItems:'center',justifyContent:'center',gap:7,transition:'all 200ms'}}>
            <SFSymbol name={copied?'check':'link'} size={16} color={copied?'#10B981':'var(--sc-primary)'}/>
            {copied?'Link Copied!':'Copy Share Link'}
          </button>
        )}
        <button onClick={()=>{app.setFiles(prev=>prev.filter(f=>f.id!==file.id));app.setModal(null);}}
          style={{width:'100%',padding:'13px 0',background:'#fff5f5',color:'var(--sc-danger)',
            border:'0.5px solid #ffdad6',borderRadius:16,fontSize:14,fontWeight:600,cursor:'pointer',
            display:'flex',alignItems:'center',justifyContent:'center',gap:7}}>
          <SFSymbol name="delete" size={16} color="var(--sc-danger)"/>Delete File
        </button>
      </div>
    </div>
  );
}

// ─── TaskFilterSheet ────────────────────────────────────────
function TaskFilterSheet() {
  const app = window.useApp();
  const { SFSymbol, TaskRow } = window;
  const filter = app.taskFilter || 'open';
  const today = window.todayIso();
  const weekEnd = (()=>{ const x=new Date(); x.setDate(x.getDate()+7); return x.toISOString().slice(0,10); })();
  const allTasks = [
    ...app.tasks,
    ...app.lists.flatMap(l => l.sections.flatMap(s => s.tasks.map(t => ({...t,_listName:l.name})))),
  ];
  const FILTERS = {
    overdue:   { label:'Overdue',    color:'#ba1a1a', icon:'warning',         tasks: allTasks.filter(t => !t.checked && t.deadline && t.deadline < today) },
    today:     { label:'Due Today',  color:'#ea580c', icon:'today',           tasks: allTasks.filter(t => !t.checked && t.deadline === today) },
    open:      { label:'Open Tasks', color:'#5e4dbb', icon:'inventory_2',     tasks: allTasks.filter(t => !t.checked) },
    completed: { label:'Completed',  color:'#10B981', icon:'check_circle',    tasks: allTasks.filter(t => t.checked) },
    week:      { label:'This Week',  color:'#1D4ED8', icon:'calendar_month',  tasks: allTasks.filter(t => !t.checked && t.deadline && t.deadline > today && t.deadline <= weekEnd) },
  };
  const f = FILTERS[filter] || FILTERS.open;
  const openTask = t => { app.setSelectedTaskId(t.id); app.setModal('edit-task'); };
  return (
    <div style={{paddingBottom:32}}>
      <div style={{padding:'6px 22px 16px'}}>
        <div style={{display:'flex',alignItems:'center',gap:12,marginBottom:4}}>
          <div style={{width:42,height:42,borderRadius:13,background:`${f.color}14`,
            display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
            <SFSymbol name={f.icon} size={20} color={f.color} fill/>
          </div>
          <div>
            <div style={{fontSize:22,fontWeight:700,letterSpacing:'-0.02em',color:'var(--sc-text)'}}>{f.label}</div>
            <div style={{fontSize:13,color:'var(--sc-text-3)',marginTop:2}}>
              {f.tasks.length} task{f.tasks.length!==1?'s':''}
            </div>
          </div>
        </div>
      </div>
      <window.Card style={{margin:'0 18px'}}>
        {f.tasks.length===0
          ? <window.EmptyRow text={`No ${f.label.toLowerCase()} tasks 🎉`}/>
          : f.tasks.map((t,i)=><TaskRow key={`${t._listId||'d'}-${t.id}`} task={t}
              divider={i<f.tasks.length-1} onClick={()=>openTask(t)}
              listBadge={t._listName} index={i}/>)
        }
      </window.Card>
    </div>
  );
}

// ─── FilePreviewSheet ─────────────────────────────────────────
function FilePreviewSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const f = app.currentPreviewFile;
  const [copied, setCopied] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const [renameVal, setRenameVal] = useState('');

  if (!f) return null;

  const submitRename = () => {
    const trimmed = renameVal.trim();
    if (!trimmed) return;
    app.setFiles(prev => prev.map(x => x.id === f.id ? {...x, name: trimmed} : x));
    app.setCurrentPreviewFile({...f, name: trimmed});
    setRenaming(false);
  };

  const fmtSize = b => b >= 1e6 ? `${(b/1e6).toFixed(1)} MB` : `${Math.round(b/1e3)} KB`;
  const fmtDate = iso => new Date(iso).toLocaleDateString('en-US',{month:'short',day:'numeric'});

  const copyLink = () => { setCopied(true); setTimeout(()=>setCopied(false), 1800); };

  const toggleVisibility = () => {
    app.setFiles(prev => prev.map(x => x.id === f.id ? {...x, isPublic: !x.isPublic} : x));
    app.setCurrentPreviewFile({...f, isPublic: !f.isPublic});
  };

  const deleteFile = () => {
    app.setFiles(prev => prev.filter(x => x.id !== f.id));
    app.setModal(null);
  };

  return (
    <>
    {/* Rename dialog overlay */}
    {renaming && (
      <div style={{position:'absolute',inset:0,zIndex:10,display:'flex',alignItems:'center',justifyContent:'center',padding:'0 24px',
        background:'rgba(0,0,0,0.30)',backdropFilter:'blur(6px)',WebkitBackdropFilter:'blur(6px)',
        animation:'overlayIn 180ms ease both'}}>
        <div style={{width:'100%',background:'var(--sc-card)',borderRadius:22,overflow:'hidden',
          boxShadow:'0 16px 48px rgba(0,0,0,0.24)',animation:'springUp 280ms cubic-bezier(0.34,1.2,0.64,1) both'}}>
          {/* Dialog header */}
          <div style={{padding:'18px 20px 14px',borderBottom:'0.5px solid var(--sc-separator)'}}>
            <div style={{fontSize:16,fontWeight:700,color:'var(--sc-text)',marginBottom:4}}>Rename File</div>
            <div style={{fontSize:12,color:'var(--sc-text-4)'}}>Enter a new name for this file.</div>
          </div>
          {/* Input */}
          <div style={{padding:'16px 20px'}}>
            <div style={{background:'var(--sc-tinted)',borderRadius:14,padding:'12px 16px',
              border:'1.5px solid var(--sc-primary)',boxShadow:'0 0 0 3px rgba(94,77,187,0.12)'}}>
              <div style={{fontSize:10,fontWeight:700,color:'var(--sc-primary)',letterSpacing:'0.08em',textTransform:'uppercase',marginBottom:6}}>File name</div>
              <input autoFocus value={renameVal} onChange={e=>setRenameVal(e.target.value)}
                onKeyDown={e=>{if(e.key==='Enter')submitRename();if(e.key==='Escape')setRenaming(false);}}
                style={{width:'100%',fontFamily:'var(--sc-font)',fontSize:15,fontWeight:600,color:'var(--sc-text)',
                  background:'transparent',border:'none',outline:'none',boxSizing:'border-box'}}/>
            </div>
          </div>
          {/* Actions */}
          <div style={{display:'flex',gap:10,padding:'0 20px 20px'}}>
            <button onClick={()=>setRenaming(false)}
              style={{flex:1,padding:'13px 0',background:'var(--sc-hover)',color:'var(--sc-text-3)',border:'none',
                borderRadius:13,fontSize:14,fontWeight:600,cursor:'pointer',fontFamily:'var(--sc-font)'}}>Cancel</button>
            <button onClick={submitRename} disabled={!renameVal.trim()}
              style={{flex:2,padding:'13px 0',
                background:renameVal.trim()?'var(--sc-primary)':'var(--sc-hover)',
                color:renameVal.trim()?'#fff':'var(--sc-text-4)',
                border:'none',borderRadius:13,fontSize:14,fontWeight:700,
                cursor:renameVal.trim()?'pointer':'default',fontFamily:'var(--sc-font)',
                boxShadow:renameVal.trim()?'0 6px 18px rgba(94,77,187,0.32)':'none',
                transition:'all 180ms',display:'flex',alignItems:'center',justifyContent:'center',gap:7}}>
              <SFSymbol name="check" size={15} color={renameVal.trim()?'#fff':'var(--sc-text-4)'}/>Rename
            </button>
          </div>
        </div>
      </div>
    )}
    <div style={{paddingBottom: 24}}>
      {/* File header */}
      <div style={{display:'flex',alignItems:'center',gap:14,padding:'6px 20px 16px',borderBottom:'0.5px solid var(--sc-separator)'}}>
        <window.FileBadge mime={f.mimeType} size={48}/>
        <div style={{flex:1,minWidth:0}}>
          <div style={{fontSize:15,fontWeight:700,color:'var(--sc-text)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{f.name}</div>
          <div style={{display:'flex',alignItems:'center',gap:8,marginTop:4}}>
            <span style={{fontSize:12,color:'var(--sc-text-4)'}}>{fmtSize(f.size)}</span>
            <span style={{color:'var(--sc-separator)'}}>·</span>
            <span style={{fontSize:12,color:'var(--sc-text-4)'}}>{fmtDate(f.createdAt)}</span>
            <span style={{fontSize:9.5,fontWeight:700,
              color:f.isPublic?'var(--sc-primary)':'var(--sc-text-4)',
              background:f.isPublic?'var(--sc-primary-bg)':'var(--sc-hover)',
              borderRadius:9999,padding:'2px 8px',textTransform:'uppercase'}}>
              {f.isPublic?'Public':'Private'}
            </span>
          </div>
        </div>
      </div>

      {/* Quick actions */}
      <div style={{display:'flex',gap:10,padding:'16px 20px',borderBottom:'0.5px solid var(--sc-separator)'}}>
        {[
          {icon:'download', label:'Download', color:'var(--sc-primary)', bg:'var(--sc-primary-bg)', fn:()=>{}},
          {icon:'link', label:copied?'Copied!':'Copy Link', color:copied?'#10B981':'var(--sc-primary)', bg:copied?'#ecfdf5':'var(--sc-primary-bg)', fn:copyLink},
        ].map((a,i)=>(
          <button key={i} onClick={a.fn}
            style={{flex:1,padding:'12px 0',background:a.bg,color:a.color,border:'none',borderRadius:14,
              fontSize:13,fontWeight:700,cursor:'pointer',fontFamily:'var(--sc-font)',
              display:'flex',alignItems:'center',justifyContent:'center',gap:7,transition:'all 150ms'}}>
            <SFSymbol name={a.icon} size={15} color={a.color}/>{a.label}
          </button>
        ))}
      </div>

      {/* Settings rows */}
      <div style={{padding:'6px 0'}}>
        {[
          {icon:f.isPublic?'lock':'public', label:f.isPublic?'Make Private':'Make Public',
            sub:f.isPublic?'Only you can access':'Anyone with the link',
            color:f.isPublic?'var(--sc-text-2)':'#10B981', fn:toggleVisibility},
          {icon:'edit', label:'Rename', sub:'Change the file name', color:'var(--sc-text-2)', fn:()=>{setRenameVal(f.name); setRenaming(true);}},

        ].map((row,i)=>(
          <button key={i} onClick={row.fn}
            style={{width:'100%',display:'flex',alignItems:'center',gap:13,padding:'13px 20px',
              background:'transparent',border:'none',borderBottom:'0.5px solid var(--sc-separator)',
              cursor:'pointer',fontFamily:'var(--sc-font)',textAlign:'left'}}>
            <div style={{width:36,height:36,borderRadius:10,background:'var(--sc-tinted)',
              display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <SFSymbol name={row.icon} size={18} color={row.color}/>
            </div>
            <div style={{flex:1}}>
              <div style={{fontSize:14,fontWeight:600,color:'var(--sc-text)'}}>{row.label}</div>
              <div style={{fontSize:12,color:'var(--sc-text-4)',marginTop:2}}>{row.sub}</div>
            </div>
            <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
          </button>
        ))}
        {/* Delete */}
        <button onClick={deleteFile}
          style={{width:'100%',display:'flex',alignItems:'center',gap:13,padding:'13px 20px',
            background:'transparent',border:'none',cursor:'pointer',fontFamily:'var(--sc-font)',textAlign:'left'}}>
          <div style={{width:36,height:36,borderRadius:10,background:'#ffdad6',
            display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
            <SFSymbol name="delete" size={18} color="var(--sc-danger)"/>
          </div>
          <div style={{flex:1}}>
            <div style={{fontSize:14,fontWeight:600,color:'var(--sc-danger)'}}>Delete File</div>
            <div style={{fontSize:12,color:'var(--sc-text-4)',marginTop:2}}>Permanently remove this file</div>
          </div>
        </button>
      </div>
    </div>
    </>
  );
}

// ─── TrashSheet ───────────────────────────────────────────────
function TrashSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [items,setItems] = useState(app.trash||[]);

  const restore = id=>{
    const item=items.find(i=>i.id===id);
    if(item){ app.addTask&&app.addTask({...item.task}); }
    setItems(prev=>prev.filter(i=>i.id!==id));
  };
  const remove = id=>setItems(prev=>prev.filter(i=>i.id!==id));

  return (
    <div style={{paddingBottom:32}}>
      <div style={{padding:'6px 22px 12px'}}>
        <div style={{fontSize:22,fontWeight:700,color:'var(--sc-text)',letterSpacing:'-0.02em'}}>Trash</div>
        <div style={{fontSize:13,color:'var(--sc-text-3)',marginTop:2}}>Items are deleted permanently after 30 days.</div>
      </div>
      {items.length===0
        ? <div style={{padding:'40px 22px',textAlign:'center'}}>
            <div style={{fontSize:40,marginBottom:12}}>🗑️</div>
            <div style={{fontSize:15,fontWeight:600,color:'var(--sc-text-3)'}}>Trash is empty</div>
          </div>
        : (
          <window.Card style={{margin:'0 18px'}}>
            {items.map((item,i)=>(
              <div key={item.id} style={{display:'flex',alignItems:'center',gap:12,padding:'13px 16px',
                borderBottom:i<items.length-1?'0.5px solid var(--sc-separator)':'none'}}>
                <div style={{flex:1,minWidth:0}}>
                  <div style={{fontSize:14,color:'var(--sc-text)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{item.task.title}</div>
                  <div style={{fontSize:11.5,color:'var(--sc-text-4)',marginTop:2}}>Deleted {item.deletedAt}</div>
                </div>
                <div style={{display:'flex',gap:6,flexShrink:0}}>
                  <button onClick={()=>restore(item.id)}
                    style={{padding:'6px 12px',background:'var(--sc-primary-bg)',color:'var(--sc-primary)',
                      border:'none',borderRadius:8,fontSize:12,fontWeight:600,cursor:'pointer'}}>Restore</button>
                  <button onClick={()=>remove(item.id)}
                    style={{width:32,height:32,borderRadius:8,background:'#fff5f5',border:'none',cursor:'pointer',
                      display:'flex',alignItems:'center',justifyContent:'center'}}>
                    <SFSymbol name="delete" size={15} color="var(--sc-danger)"/>
                  </button>
                </div>
              </div>
            ))}
          </window.Card>
        )}
    </div>
  );
}

// ─── Exports ──────────────────────────────────────────────────
Object.assign(window, {
  TaskDetailSheet, EditTaskSheet, AddChoiceSheet, AddFolderSheet, AddListSheet, ListsDrawerSheet,
  SettingsSheet, AIAssistantSheet, TrashSheet, TaskFilterSheet, FileDetailSheet, FilePreviewSheet,
});
