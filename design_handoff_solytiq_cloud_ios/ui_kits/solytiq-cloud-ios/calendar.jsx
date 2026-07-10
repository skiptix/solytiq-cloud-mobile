// Solytiq Cloud · iOS v2 — Calendar (tasks + meetings + milestones), workspace filter
// Exports: CalendarScreen, MeetingSheet, DayAddChooserSheet

const { useState: useStateC, useRef: useRefC, useMemo: useMemoC, useEffect: useEffectC } = React;

const CAL_MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const CAL_DOW = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
const PRIO_C = { High:'#ea580c', Medium:'#f59e0b', Low:'#787584' };
const MEETING_COLORS = ['#5e4dbb','#3b82f6','#0ea5e9','#10b981','#f59e0b','#ef4444','#ec4899','#8b5cf6'];

function isoOf(d){ const x=new Date(d); x.setHours(0,0,0,0); const y=x.getFullYear(),m=String(x.getMonth()+1).padStart(2,'0'),day=String(x.getDate()).padStart(2,'0'); return `${y}-${m}-${day}`; }
function parseMinC(t){ if(!t) return null; const m=/^(\d{1,2}):(\d{2})/.exec(t); if(!m) return null; return (+m[1])*60+(+m[2]); }
function tintC(hex,a=0.14){ if(!hex) return 'rgba(94,77,187,0.12)'; const h=hex.replace('#',''); const r=parseInt(h.slice(0,2),16),g=parseInt(h.slice(2,4),16),b=parseInt(h.slice(4,6),16); return `rgba(${r},${g},${b},${a})`; }
function to12h(t){ if(!t) return ''; const m=parseMinC(t); if(m==null) return t; let h=Math.floor(m/60), mm=m%60; const ap=h>=12?'PM':'AM'; h=h%12||12; return `${h}:${String(mm).padStart(2,'0')} ${ap}`; }

// ════════════════════════════════════════════════════════════
//  CalendarScreen
// ════════════════════════════════════════════════════════════
function CalendarScreen() {
  const app = window.useApp();
  const { NavHeader, TaskRow, Card, SectionHeader, EmptyRow, SFSymbol } = window;
  const connected = app.profile.mode === 'server';
  const [scrollY, setScrollY] = useStateC(0);
  const [view, setView] = useStateC('month'); // month | week
  const [monthOffset, setMonthOffset] = useStateC(0);
  const [weekOffset, setWeekOffset] = useStateC(0);
  const [showFilter, setShowFilter] = useStateC(false);
  const [hiddenWs, setHiddenWs] = useStateC(()=>new Set());
  const [kinds, setKinds] = useStateC({ task:true, meeting:true, milestone:true });
  const [dragId, setDragId] = useStateC(null);
  const dragRef = useRefC(null);
  const [dragOver, setDragOver] = useStateC(null);
  const [flash, setFlash] = useStateC(null);

  const now = new Date(); now.setHours(0,0,0,0);
  const todayIso = isoOf(now);
  const [selDay, setSelDay] = useStateC(todayIso);

  const workspaces = app.workspaces || [];
  const wsVisible = wsId => !wsId || !hiddenWs.has(wsId);
  const toggleWs = id => setHiddenWs(prev => { const n=new Set(prev); n.has(id)?n.delete(id):n.add(id); return n; });

  // ── unified chips per date ──
  const allTasks = useMemoC(() => [
    ...app.tasks.map(t=>({...t, _listName:'Dashboard'})),
    ...app.lists.flatMap(l => l.sections.flatMap(s => s.tasks.map(t => ({...t, _listId:l.id, _listName:l.name, workspaceId:l.workspaceId})))),
  ], [app.tasks, app.lists]);

  const chipsByDate = useMemoC(() => {
    const map = {};
    const push = (d,c) => { (map[d]=map[d]||[]).push(c); };
    if (kinds.task) for (const t of allTasks) {
      if (!t.deadline || t.checked || !wsVisible(t.workspaceId)) continue;
      push(t.deadline, { key:`t-${t._listId||'d'}-${t.id}`, kind:'task', time:t.time||null, label:t.title,
        accent:'#5e4dbb', bg:'#F5F3FF', priorityColor:t.priority?PRIO_C[t.priority]:null,
        subtitle:t._listName&&t._listName!=='Dashboard'?t._listName:null, drag:String(t.id),
        onClick:()=>{ app.setSelectedTaskId(t.id); app.setModal('edit-task'); } });
    }
    if (kinds.milestone) for (const tl of (app.timelines||[])) {
      if (!wsVisible(tl.workspaceId)) continue;
      const accent = tl.color||'#0ea5e9';
      for (const m of tl.milestones) {
        if (!m.date || m.status==='done') continue;
        push(m.date, { key:`m-${m.id}`, kind:'milestone', time:m.time||null, label:m.title, accent, bg:tintC(accent),
          emoji:m.emoji||tl.emoji||null, subtitle:tl.name,
          onClick:()=>{ app.setSelectedTimelineId(tl.id); app.setScreen('timeline'); } });
      }
    }
    if (kinds.meeting) for (const mt of (app.meetings||[])) {
      if (!wsVisible(mt.workspaceId)) continue;
      const accent = mt.color||'#3b82f6';
      push(mt.date, { key:`e-${mt.id}`, kind:'meeting', time:mt.allDay?null:(mt.startTime||null), label:mt.title,
        accent, bg:tintC(accent), allDay:mt.allDay, subtitle:mt.location||null, drag:`meeting:${mt.id}`,
        onClick:()=>{ app.setModalData({ meeting:mt }); app.setModal('meeting'); } });
    }
    for (const k in map) map[k].sort((a,b)=>{ const ta=a.time||'',tb=b.time||''; if(ta===tb) return 0; if(!ta) return -1; if(!tb) return 1; return ta<tb?-1:1; });
    return map;
  }, [allTasks, app.timelines, app.meetings, kinds, hiddenWs]);

  const unscheduled = useMemoC(()=>allTasks.filter(t=>!t.deadline && !t.checked && wsVisible(t.workspaceId)), [allTasks, hiddenWs]);

  // ── reschedule via drop ──
  const dropOnDay = isoDate => {
    const data = dragRef.current; if(!data) return;
    if (data.startsWith('meeting:')) app.updateMeeting(data.slice(8), { date:isoDate });
    else { const id=parseInt(data,10); if(id) app.updateTask(id, { deadline:isoDate }); }
    setFlash(isoDate); setTimeout(()=>setFlash(null),600);
    setSelDay(isoDate); dragRef.current=null; setDragId(null); setDragOver(null);
  };

  // ── month grid ──
  const mv = new Date(now.getFullYear(), now.getMonth()+monthOffset, 1);
  const monthName = `${CAL_MONTHS[mv.getMonth()]} ${mv.getFullYear()}`;
  const daysInMonth = new Date(mv.getFullYear(), mv.getMonth()+1, 0).getDate();
  const firstDow = mv.getDay();
  const monthCells = [];
  for (let i=0;i<firstDow;i++) monthCells.push(null);
  for (let d=1;d<=daysInMonth;d++) monthCells.push(new Date(mv.getFullYear(), mv.getMonth(), d));

  // ── week ──
  const wStart = new Date(now); wStart.setDate(now.getDate()-now.getDay()+weekOffset*7);
  const weekDays = Array.from({length:7},(_,i)=>{ const d=new Date(wStart); d.setDate(wStart.getDate()+i); return d; });
  const weekLabel = (()=>{ const e=new Date(wStart); e.setDate(wStart.getDate()+6); const sm=wStart.getMonth()===e.getMonth();
    return sm ? `${CAL_MONTHS[wStart.getMonth()].slice(0,3)} ${wStart.getDate()}–${e.getDate()}` : `${CAL_MONTHS[wStart.getMonth()].slice(0,3)} ${wStart.getDate()} – ${CAL_MONTHS[e.getMonth()].slice(0,3)} ${e.getDate()}`; })();

  const goToday = () => { setMonthOffset(0); setWeekOffset(0); setSelDay(todayIso); };
  const activeFilters = hiddenWs.size + (kinds.task?0:1) + (kinds.meeting?0:1) + (kinds.milestone?0:1);

  const selChips = chipsByDate[selDay] || [];
  const selDate = new Date(selDay+'T12:00:00');

  // ── Chip component ──
  const Chip = ({ c, compact=false }) => (
    <div onClick={e=>{ e.stopPropagation(); c.onClick(); }} title={c.label}
      draggable={!!c.drag}
      onDragStart={c.drag ? e=>{ dragRef.current=c.drag; setDragId(c.drag); e.dataTransfer.setData('text/plain',c.drag); e.dataTransfer.effectAllowed='move'; e.stopPropagation(); } : undefined}
      onDragEnd={()=>{ dragRef.current=null; setDragId(null); setDragOver(null); }}
      style={{ display:'flex', alignItems:'center', gap:5, background:c.bg, borderRadius:compact?4:8,
        padding:compact?'1px 4px':'6px 9px', cursor:c.drag?'grab':'pointer', borderLeft:compact?'none':`3px solid ${c.accent}`, minWidth:0 }}>
      {c.priorityColor ? <div style={{ width:compact?5:6, height:compact?5:6, borderRadius:'50%', background:c.priorityColor, flexShrink:0 }}/>
        : c.emoji ? <span style={{ fontSize:compact?9:12, lineHeight:1, flexShrink:0 }}>{c.emoji}</span>
        : <div style={{ width:compact?5:6, height:compact?5:6, borderRadius:'50%', background:c.accent, flexShrink:0 }}/>}
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ fontSize:compact?10:12.5, fontWeight:600, color:c.accent, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{c.label}</div>
        {!compact && (c.allDay||c.time||c.subtitle) && (
          <div style={{ fontSize:10.5, color:'var(--sc-text-3)', marginTop:1, overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>
            {c.allDay?'All day':c.time?to12h(c.time):''}{c.subtitle?`${(c.allDay||c.time)?' · ':''}${c.subtitle}`:''}
          </div>
        )}
      </div>
      {!compact && <span style={{ fontSize:8.5, fontWeight:700, color:c.accent, opacity:0.75, textTransform:'uppercase', letterSpacing:'0.04em', flexShrink:0 }}>{c.kind==='meeting'?'Meet':c.kind==='milestone'?'Mile':''}</span>}
    </div>
  );

  return (
    <div style={{ display:'flex', flexDirection:'column', height:'100%', background:'var(--sc-page)', position:'relative', overflow:'hidden' }}>
      {showFilter && <div onClick={()=>setShowFilter(false)} style={{ position:'absolute', inset:0, zIndex:18 }}/>}
      <div className="sc-scroll" onScroll={e=>setScrollY(e.currentTarget.scrollTop)} style={{ flex:1, minHeight:0, overflowY:'auto', paddingBottom:96 }}>
        <NavHeader title="Calendar" subtitle="Tasks, meetings and milestones in one place." scrollY={scrollY}
          trailing={
            <div style={{ display:'flex', alignItems:'center', gap:8, marginRight:36 }}>
              <div style={{ position:'relative' }}>
                <button onClick={()=>setShowFilter(f=>!f)} style={{ width:32, height:32, borderRadius:'50%', background:(showFilter||activeFilters)?'var(--sc-primary)':'var(--sc-primary-bg)', border:'none', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer', position:'relative' }}>
                  <SFSymbol name="tune" size={16} color={(showFilter||activeFilters)?'#fff':'var(--sc-primary)'}/>
                  {activeFilters>0 && <span style={{ position:'absolute', top:-2, right:-2, minWidth:15, height:15, padding:'0 4px', borderRadius:9999, background:'#ea580c', color:'#fff', fontSize:9, fontWeight:700, display:'flex', alignItems:'center', justifyContent:'center', border:'1.5px solid var(--sc-page)' }}>{activeFilters}</span>}
                </button>
                {showFilter && <FilterPop {...{connected, workspaces, hiddenWs, toggleWs, kinds, setKinds, close:()=>setShowFilter(false), SFSymbol}}/>}
              </div>
              <button onClick={goToday} style={{ fontSize:13, fontWeight:600, color:'var(--sc-primary)', background:'var(--sc-primary-bg)', border:'none', borderRadius:9999, padding:'6px 13px', cursor:'pointer' }}>Today</button>
            </div>
          }/>

        {/* View toggle */}
        <div style={{ padding:'0 22px 14px' }}>
          <div style={{ display:'flex', gap:3, background:'var(--sc-primary-bg)', borderRadius:12, padding:3 }}>
            {[['month','Month','calendar_month'],['week','Week','view_week']].map(([k,l,ic])=>{ const a=view===k;
              return <button key={k} onClick={()=>setView(k)} style={{ flex:1, display:'flex', alignItems:'center', justifyContent:'center', gap:6, padding:'9px 0', borderRadius:9, border:'none', background:a?'var(--sc-primary)':'transparent', color:a?'#fff':'var(--sc-primary)', fontSize:13, fontWeight:600, cursor:'pointer', fontFamily:'var(--sc-font)', transition:'all 150ms' }}>
                <SFSymbol name={ic} size={15} color={a?'#fff':'var(--sc-primary)'}/>{l}</button>;
            })}
          </div>
        </div>

        {/* Period nav */}
        <div style={{ padding:'0 18px 10px', display:'flex', alignItems:'center', justifyContent:'center', gap:14 }}>
          <button onClick={()=>view==='month'?setMonthOffset(m=>m-1):setWeekOffset(w=>w-1)} style={{ width:34, height:34, borderRadius:11, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}>
            <SFSymbol name="chevron_left" size={18} color="var(--sc-text-2)"/>
          </button>
          <div style={{ fontSize:18, fontWeight:700, minWidth:160, textAlign:'center', color:'var(--sc-text)' }}>{view==='month'?monthName:weekLabel}</div>
          <button onClick={()=>view==='month'?setMonthOffset(m=>m+1):setWeekOffset(w=>w+1)} style={{ width:34, height:34, borderRadius:11, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}>
            <SFSymbol name="chevron_right" size={18} color="var(--sc-text-2)"/>
          </button>
        </div>

        {view==='month' ? (
          <>
            {/* Month grid */}
            <div style={{ padding:'0 14px 12px', animation:'fadeBlur 300ms cubic-bezier(0.34,1.2,0.64,1) both' }}>
              <div style={{ display:'grid', gridTemplateColumns:'repeat(7,1fr)', gap:3, marginBottom:4 }}>
                {['S','M','T','W','T','F','S'].map((d,i)=><div key={i} style={{ textAlign:'center', fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.06em', padding:'4px 0' }}>{d}</div>)}
              </div>
              <div style={{ display:'grid', gridTemplateColumns:'repeat(7,1fr)', gap:3 }}>
                {monthCells.map((d,i)=>{
                  if(!d) return <div key={i}/>;
                  const di = isoOf(d);
                  const isToday = di===todayIso;
                  const isSel = di===selDay;
                  const isOver = dragOver===di;
                  const isFlash = flash===di;
                  const chips = chipsByDate[di]||[];
                  const dots = chips.slice(0,4);
                  return (
                    <div key={i} onClick={()=>setSelDay(di)}
                      onDragOver={e=>{ e.preventDefault(); e.dataTransfer.dropEffect='move'; setDragOver(di); }}
                      onDragLeave={e=>{ e.preventDefault(); setDragOver(null); }}
                      onDrop={e=>{ e.preventDefault(); if(!dragRef.current){ const d2=e.dataTransfer.getData('text/plain'); if(d2)dragRef.current=d2; } dropOnDay(di); }}
                      style={{ aspectRatio:'1/1', display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:3, borderRadius:12, cursor:dragId?'copy':'pointer',
                        background: isFlash?'#10B981':isOver?'var(--sc-primary)':isSel?'var(--sc-primary)':isToday?'var(--sc-primary-bg-2)':'transparent',
                        color: isOver||isSel||isFlash?'#fff':isToday?'var(--sc-primary)':'var(--sc-text)',
                        border: isOver?'2px dashed rgba(255,255,255,0.6)':'2px solid transparent',
                        transform: isOver?'scale(1.08)':'scale(1)', transition:'all 140ms' }}>
                      <span className="sc-mono" style={{ fontSize:13, fontWeight:isToday||isSel||isOver?700:500 }}>{d.getDate()}</span>
                      <div style={{ display:'flex', gap:2, height:5 }}>
                        {dots.map((c,j)=><div key={j} style={{ width:4, height:4, borderRadius:'50%', background:isSel||isOver?'rgba(255,255,255,0.8)':c.accent }}/>)}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {dragId && (
              <div style={{ margin:'0 18px 12px', padding:'9px 14px', background:'var(--sc-primary-bg)', border:'1px dashed var(--sc-primary)', borderRadius:12, display:'flex', alignItems:'center', gap:8, animation:'pulse 1s ease-in-out infinite' }}>
                <SFSymbol name="event_available" size={14} color="var(--sc-primary)"/>
                <span style={{ fontSize:12.5, fontWeight:600, color:'var(--sc-primary)' }}>Drop on a date to reschedule</span>
              </div>
            )}

            {/* Selected day agenda */}
            <SectionHeader title={`${selDay===todayIso?'Today · ':''}${selDate.toLocaleDateString('en-US',{weekday:'long',month:'long'}).toUpperCase()} ${selDate.getDate()}`}
              right={<button onClick={()=>{ app.setModalData({date:selDay}); app.setModal('day-add'); }} style={{ display:'flex', alignItems:'center', gap:3, fontSize:12, fontWeight:600, color:'var(--sc-primary)', background:'transparent', border:'none', cursor:'pointer' }}><SFSymbol name="add" size={14} color="var(--sc-primary)"/>Add</button>}/>
            {selChips.length===0
              ? <Card><EmptyRow text="Nothing scheduled. Tap Add to plan this day."/></Card>
              : <div style={{ padding:'0 18px', display:'flex', flexDirection:'column', gap:7 }}>{selChips.map(c=><Chip key={c.key} c={c}/>)}</div>}
          </>
        ) : (
          /* Week agenda */
          <div style={{ padding:'0 18px', display:'flex', flexDirection:'column', gap:10, animation:'fadeBlur 300ms cubic-bezier(0.34,1.2,0.64,1) both' }}>
            {weekDays.map((d,i)=>{
              const di = isoOf(d);
              const isToday = di===todayIso;
              const chips = chipsByDate[di]||[];
              const isOver = dragOver===di;
              return (
                <div key={i}
                  onDragOver={e=>{ e.preventDefault(); e.dataTransfer.dropEffect='move'; setDragOver(di); }}
                  onDragLeave={e=>{ e.preventDefault(); setDragOver(null); }}
                  onDrop={e=>{ e.preventDefault(); if(!dragRef.current){ const d2=e.dataTransfer.getData('text/plain'); if(d2)dragRef.current=d2; } dropOnDay(di); }}
                  style={{ display:'flex', gap:12, padding:'12px 14px', background:isOver?'var(--sc-primary-bg)':'var(--sc-card)', border:isOver?'1.5px dashed var(--sc-primary)':'0.5px solid var(--sc-border)', borderRadius:16, transition:'all 140ms' }}>
                  <div onClick={()=>{ app.setModalData({date:di}); app.setModal('day-add'); }} style={{ width:46, flexShrink:0, textAlign:'center', cursor:'pointer' }}>
                    <div style={{ fontSize:10, fontWeight:700, color:isToday?'var(--sc-primary)':'var(--sc-text-4)', letterSpacing:'0.05em' }}>{CAL_DOW[d.getDay()].toUpperCase()}</div>
                    <div style={{ width:34, height:34, margin:'4px auto 0', borderRadius:11, display:'flex', alignItems:'center', justifyContent:'center', background:isToday?'var(--sc-primary)':'transparent' }}>
                      <span className="sc-mono" style={{ fontSize:16, fontWeight:700, color:isToday?'#fff':'var(--sc-text)' }}>{d.getDate()}</span>
                    </div>
                  </div>
                  <div style={{ flex:1, minWidth:0, display:'flex', flexDirection:'column', gap:5, justifyContent:'center' }}>
                    {chips.length===0
                      ? <button onClick={()=>{ app.setModalData({date:di}); app.setModal('day-add'); }} style={{ alignSelf:'flex-start', fontSize:12, color:'var(--sc-text-4)', background:'transparent', border:'none', cursor:'pointer', padding:'4px 0', fontFamily:'var(--sc-font)', display:'flex', alignItems:'center', gap:4 }}><SFSymbol name="add" size={13} color="var(--sc-text-4)"/>Add</button>
                      : chips.map(c=><Chip key={c.key} c={c}/>)}
                  </div>
                </div>
              );
            })}
          </div>
        )}

        {/* Unscheduled */}
        {unscheduled.length>0 && (
          <div style={{ marginTop:6 }}>
            <SectionHeader title="Unscheduled" right={<span style={{ fontSize:12, fontWeight:700, color:'var(--sc-text-4)', background:'var(--sc-hover)', borderRadius:9999, padding:'2px 9px' }}>{unscheduled.length}</span>}/>
            <div style={{ margin:'0 18px 8px', padding:'8px 12px', background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', borderRadius:10, display:'flex', alignItems:'center', gap:7 }}>
              <SFSymbol name="drag_indicator" size={13} color="var(--sc-text-4)"/>
              <span style={{ fontSize:11.5, color:'var(--sc-text-4)' }}>Drag a task onto a {view==='month'?'date':'day'} to schedule it</span>
            </div>
            <Card>
              {unscheduled.map((t,i)=>{
                const isDrag = dragId===String(t.id);
                return (
                  <div key={`u-${t.id}`} draggable
                    onDragStart={e=>{ dragRef.current=String(t.id); setDragId(String(t.id)); e.dataTransfer.setData('text/plain',String(t.id)); e.dataTransfer.effectAllowed='move'; }}
                    onDragEnd={()=>{ dragRef.current=null; setDragId(null); setDragOver(null); }}
                    onClick={()=>{ app.setSelectedTaskId(t.id); app.setModal('edit-task'); }}
                    style={{ display:'flex', alignItems:'center', gap:11, padding:'11px 16px', borderBottom:i<unscheduled.length-1?'0.5px solid var(--sc-separator)':'none', cursor:'grab', userSelect:'none', opacity:isDrag?0.4:1, background:isDrag?'var(--sc-primary-bg)':'transparent', transition:'opacity 150ms, background 150ms' }}>
                    <SFSymbol name="drag_indicator" size={16} color="var(--sc-text-4)" style={{ flexShrink:0 }}/>
                    <div style={{ width:22, height:22, borderRadius:7, border:'1.5px solid var(--sc-border)', flexShrink:0 }}/>
                    <div style={{ flex:1, minWidth:0 }}>
                      <div style={{ fontSize:14, color:'var(--sc-text)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{t.title}</div>
                      {t._listName && t._listName!=='Dashboard' && <div style={{ fontSize:10, color:'var(--sc-text-4)', marginTop:3 }}>{t._listName}</div>}
                    </div>
                    {t.priority && <div style={{ width:7, height:7, borderRadius:'50%', background:PRIO_C[t.priority]||'#ccc', flexShrink:0 }}/>}
                  </div>
                );
              })}
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Filter popover ──
function FilterPop({ connected, workspaces, hiddenWs, toggleWs, kinds, setKinds, close, SFSymbol }) {
  const KINDS = [['task','Tasks','#5e4dbb','task_alt'],['meeting','Meetings','#3b82f6','event'],['milestone','Milestones','#0ea5e9','flag']];
  return (
    <div style={{ position:'absolute', right:0, top:40, zIndex:60, width:230, background:'var(--sc-card)', borderRadius:16, border:'0.5px solid var(--sc-border)', boxShadow:'0 8px 32px rgba(28,27,34,0.16)', overflow:'hidden', animation:'popIn 180ms cubic-bezier(0.34,1.56,0.64,1) both' }}>
      <div style={{ padding:'12px 16px 8px', fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase' }}>Show</div>
      {KINDS.map(([k,l,c,ic])=>{ const on=kinds[k];
        return <button key={k} onClick={()=>setKinds(p=>({...p,[k]:!p[k]}))} style={{ width:'100%', display:'flex', alignItems:'center', gap:10, padding:'10px 16px', background:'transparent', border:'none', cursor:'pointer', fontFamily:'var(--sc-font)', textAlign:'left' }}>
          <div style={{ width:26, height:26, borderRadius:8, background:tintC(c,0.16), display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}><SFSymbol name={ic} size={14} color={c}/></div>
          <span style={{ flex:1, fontSize:13.5, fontWeight:500, color:'var(--sc-text)' }}>{l}</span>
          <div style={{ width:34, height:20, borderRadius:9999, background:on?c:'#d8d3e6', position:'relative', transition:'background 160ms', flexShrink:0 }}>
            <div style={{ position:'absolute', top:2, left:on?16:2, width:16, height:16, borderRadius:'50%', background:'#fff', transition:'left 160ms', boxShadow:'0 1px 2px rgba(0,0,0,0.2)' }}/>
          </div>
        </button>;
      })}
      {connected && workspaces.length>0 && (
        <>
          <div style={{ padding:'10px 16px 8px', borderTop:'0.5px solid var(--sc-separator)', fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase' }}>Workspaces</div>
          {workspaces.map(ws=>{ const on=!hiddenWs.has(ws.id);
            return <button key={ws.id} onClick={()=>toggleWs(ws.id)} style={{ width:'100%', display:'flex', alignItems:'center', gap:10, padding:'10px 16px', background:'transparent', border:'none', cursor:'pointer', fontFamily:'var(--sc-font)', textAlign:'left' }}>
              <span style={{ fontSize:16, flexShrink:0, opacity:on?1:0.4 }}>{ws.emoji}</span>
              <span style={{ flex:1, fontSize:13.5, fontWeight:500, color:on?'var(--sc-text)':'var(--sc-text-4)' }}>{ws.name}</span>
              <SFSymbol name={on?'visibility':'visibility_off'} size={16} color={on?'var(--sc-primary)':'var(--sc-text-4)'}/>
            </button>;
          })}
        </>
      )}
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  DayAddChooserSheet
// ════════════════════════════════════════════════════════════
function DayAddChooserSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const date = (app.modalData||{}).date || window.todayIso();
  const friendly = new Date(date+'T12:00:00').toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric'});
  const opt = (icon,color,bg,title,sub,fn) => (
    <button onClick={fn} style={{ width:'100%', display:'flex', alignItems:'center', gap:13, padding:'15px 16px', borderRadius:16, border:'1.5px solid var(--sc-border)', background:'var(--sc-card)', cursor:'pointer', textAlign:'left', transition:'all 150ms' }}
      onMouseEnter={e=>{ e.currentTarget.style.borderColor=color; e.currentTarget.style.background=bg; }}
      onMouseLeave={e=>{ e.currentTarget.style.borderColor='var(--sc-border)'; e.currentTarget.style.background='var(--sc-card)'; }}>
      <div style={{ width:42, height:42, borderRadius:12, background:bg, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}><SFSymbol name={icon} size={21} color={color} fill/></div>
      <div style={{ flex:1 }}>
        <div style={{ fontSize:15, fontWeight:700, color:'var(--sc-text)' }}>{title}</div>
        <div style={{ fontSize:12.5, color:'var(--sc-text-3)', marginTop:2 }}>{sub}</div>
      </div>
      <SFSymbol name="chevron_right" size={16} color="var(--sc-text-4)"/>
    </button>
  );
  return (
    <div style={{ padding:'6px 20px 30px' }}>
      <div style={{ marginBottom:16 }}>
        <div style={{ fontSize:20, fontWeight:700, letterSpacing:'-0.02em', color:'var(--sc-text)' }}>Add to calendar</div>
        <div style={{ fontSize:13, color:'var(--sc-text-3)', marginTop:2 }}>{friendly}</div>
      </div>
      <div style={{ display:'flex', flexDirection:'column', gap:10 }}>
        {opt('task_alt','#5e4dbb','var(--sc-primary-bg)','Task','A to-do with a deadline',()=>{ app.setModalData({ presetDeadline:date }); app.setModal('add-task'); })}
        {opt('event','#3b82f6','#eff6ff','Meeting','A standalone calendar event',()=>{ app.setModalData({ meeting:null, presetDate:date }); app.setModal('meeting'); })}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  MeetingSheet — create / edit a meeting
// ════════════════════════════════════════════════════════════
function MeetingSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const data = app.modalData || {};
  const initial = data.meeting;
  const editing = !!initial;
  const [title, setTitle] = useStateC(initial?.title||'');
  const [date, setDate] = useStateC(initial?.date || data.presetDate || window.todayIso());
  const [allDay, setAllDay] = useStateC(initial?.allDay||false);
  const [startTime, setStartTime] = useStateC(initial?.startTime||'');
  const [endTime, setEndTime] = useStateC(initial?.endTime||'');
  const [location, setLocation] = useStateC(initial?.location||'');
  const [desc, setDesc] = useStateC(initial?.description||'');
  const [color, setColor] = useStateC(initial?.color||'#3b82f6');
  const [showCal, setShowCal] = useStateC(false);
  const [calOffset, setCalOffset] = useStateC(0);
  const [confirmDelete, setConfirmDelete] = useStateC(false);
  const titleRef = useRefC(null);
  useEffectC(()=>{ const t=setTimeout(()=>titleRef.current?.focus({preventScroll:true}),340); return ()=>clearTimeout(t); },[]);

  const canSave = title.trim().length>0 && !!date;
  const save = () => {
    if(!canSave) return;
    const payload = { title:title.trim(), date, allDay, startTime:allDay?null:(startTime||null), endTime:allDay?null:(endTime||null), location:location.trim()||null, description:desc.trim()||null, color, workspaceId:initial?.workspaceId||app.currentWorkspaceId };
    if(editing) app.updateMeeting(initial.id, payload); else app.addMeeting(payload);
    app.setModal(null);
  };
  const dateLabel = new Date(date+'T12:00:00').toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric',year:'numeric'});
  const TIMES = useMemoC(()=>{ const out=['']; for(let h=6;h<=22;h++) for(const m of ['00','30']) out.push(`${String(h).padStart(2,'0')}:${m}`); return out; }, []);

  const Row = ({icon,iconColor,children,last=false}) => (
    <div style={{ display:'flex', alignItems:'flex-start', gap:13, padding:'13px 16px', borderBottom:last?'none':'0.5px solid var(--sc-separator)' }}>
      <div style={{ width:32, height:32, borderRadius:9, background:`${iconColor}18`, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0, marginTop:1 }}><SFSymbol name={icon} size={16} color={iconColor} fill/></div>
      <div style={{ flex:1, minWidth:0 }}>{children}</div>
    </div>
  );

  return (
    <div style={{ paddingBottom:32 }}>
      <div style={{ height:5, background:color, borderRadius:9999, margin:'0 20px 12px' }}/>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'0 20px 14px' }}>
        <button onClick={()=>app.setModal(null)} style={{ fontSize:15, color:'var(--sc-text-3)', background:'transparent', border:'none', cursor:'pointer', padding:'6px 0', fontFamily:'var(--sc-font)' }}>Cancel</button>
        <span style={{ fontSize:16, fontWeight:700, color:'var(--sc-text)' }}>{editing?'Edit Meeting':'New Meeting'}</span>
        <button onClick={save} disabled={!canSave} style={{ fontSize:15, fontWeight:700, color:canSave?color:'var(--sc-text-4)', background:'transparent', border:'none', cursor:canSave?'pointer':'default', padding:'6px 0', fontFamily:'var(--sc-font)' }}>Save</button>
      </div>

      <div style={{ padding:'0 20px 14px', display:'flex', gap:10, alignItems:'center' }}>
        <div style={{ width:52, height:52, borderRadius:14, background:tintC(color,0.16), display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}><SFSymbol name="event" size={26} color={color} fill/></div>
        <input ref={titleRef} value={title} onChange={e=>setTitle(e.target.value)} placeholder="Meeting title"
          style={{ flex:1, fontFamily:'var(--sc-font)', fontSize:18, fontWeight:700, color:'var(--sc-text)', background:'var(--sc-tinted)', border:'none', borderRadius:14, padding:'14px 16px', outline:'none', boxSizing:'border-box', letterSpacing:'-0.01em' }}/>
      </div>

      <div style={{ margin:'0 20px 14px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16, overflow:'hidden' }}>
        <Row icon="calendar_today" iconColor="#ea580c">
          <div style={{ fontSize:13, fontWeight:500, color:'var(--sc-text)', marginBottom:8 }}>{dateLabel}</div>
          <button onClick={()=>setShowCal(s=>!s)} style={{ fontSize:11, fontWeight:700, padding:'6px 12px', borderRadius:9999, background:showCal?'var(--sc-primary)':'var(--sc-primary-bg)', color:showCal?'#fff':'var(--sc-primary)', border:'none', cursor:'pointer', display:'inline-flex', alignItems:'center', gap:5 }}>
            <SFSymbol name="calendar_month" size={12} color={showCal?'#fff':'var(--sc-primary)'}/>{showCal?'Close':'Pick date'}
          </button>
          {showCal && (()=>{
            const nowD=new Date(); const vw=new Date(nowD.getFullYear(),nowD.getMonth()+calOffset,1);
            const mn=vw.toLocaleDateString('en-US',{month:'long',year:'numeric'});
            const dim=new Date(vw.getFullYear(),vw.getMonth()+1,0).getDate(); const fd=vw.getDay();
            const cells=[]; for(let i=0;i<fd;i++)cells.push(null); for(let d=1;d<=dim;d++)cells.push(d);
            const sel=d=>{ if(!d)return false; const dd=new Date(date+'T12:00:00'); return dd.getFullYear()===vw.getFullYear()&&dd.getMonth()===vw.getMonth()&&dd.getDate()===d; };
            return (
              <div style={{ marginTop:12, background:'var(--sc-tinted)', borderRadius:14, padding:'12px 10px', animation:'springUp 220ms cubic-bezier(0.34,1.2,0.64,1) both' }}>
                <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:8, padding:'0 2px' }}>
                  <button onClick={()=>setCalOffset(o=>o-1)} style={{ width:28, height:28, borderRadius:8, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}><SFSymbol name="chevron_left" size={15} color="var(--sc-text-2)"/></button>
                  <span style={{ fontSize:13, fontWeight:700, color:'var(--sc-text)' }}>{mn}</span>
                  <button onClick={()=>setCalOffset(o=>o+1)} style={{ width:28, height:28, borderRadius:8, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}><SFSymbol name="chevron_right" size={15} color="var(--sc-text-2)"/></button>
                </div>
                <div style={{ display:'grid', gridTemplateColumns:'repeat(7,1fr)', gap:2, marginBottom:2 }}>
                  {['S','M','T','W','T','F','S'].map((d,i)=><div key={i} style={{ textAlign:'center', fontSize:9.5, fontWeight:700, color:'var(--sc-text-4)', padding:'3px 0' }}>{d}</div>)}
                </div>
                <div style={{ display:'grid', gridTemplateColumns:'repeat(7,1fr)', gap:2 }}>
                  {cells.map((d,i)=>{ if(!d) return <div key={i}/>; const s=sel(d);
                    return <button key={i} onClick={()=>{ const y=vw.getFullYear(),m=String(vw.getMonth()+1).padStart(2,'0'),day=String(d).padStart(2,'0'); setDate(`${y}-${m}-${day}`); setShowCal(false); }} style={{ aspectRatio:'1/1', borderRadius:9, border:'none', cursor:'pointer', background:s?color:'transparent', color:s?'#fff':'var(--sc-text)', fontSize:12, fontWeight:s?700:400, display:'flex', alignItems:'center', justifyContent:'center' }}>{d}</button>;
                  })}
                </div>
              </div>
            );
          })()}
        </Row>

        <Row icon="schedule" iconColor="var(--sc-primary)">
          <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:allDay?0:10 }}>
            <span style={{ fontSize:13, fontWeight:600, color:'var(--sc-text)' }}>All-day</span>
            <button onClick={()=>setAllDay(a=>!a)} style={{ width:44, height:26, borderRadius:9999, background:allDay?color:'#d8d3e6', border:'none', position:'relative', cursor:'pointer', transition:'background 160ms', flexShrink:0 }}>
              <div style={{ position:'absolute', top:3, left:allDay?21:3, width:20, height:20, borderRadius:'50%', background:'#fff', transition:'left 160ms', boxShadow:'0 1px 3px rgba(0,0,0,0.2)' }}/>
            </button>
          </div>
          {!allDay && (
            <div style={{ display:'flex', gap:10 }}>
              {[['Starts',startTime,setStartTime],['Ends',endTime,setEndTime]].map(([l,val,set])=>(
                <div key={l} style={{ flex:1 }}>
                  <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.05em', textTransform:'uppercase', marginBottom:5 }}>{l}</div>
                  <select value={val} onChange={e=>set(e.target.value)} style={{ width:'100%', fontFamily:'var(--sc-font)', fontSize:13, fontWeight:600, color:val?'var(--sc-text)':'var(--sc-text-4)', background:'var(--sc-tinted)', border:'1.5px solid var(--sc-border)', borderRadius:10, padding:'9px 10px', outline:'none', cursor:'pointer', boxSizing:'border-box', WebkitAppearance:'none' }}>
                    {TIMES.map(t=><option key={t} value={t}>{t?to12h(t):'--:--'}</option>)}
                  </select>
                </div>
              ))}
            </div>
          )}
        </Row>

        <Row icon="location_on" iconColor="#10b981" last>
          <input value={location} onChange={e=>setLocation(e.target.value)} placeholder="Add a location"
            style={{ width:'100%', fontFamily:'var(--sc-font)', fontSize:14, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', boxSizing:'border-box' }}/>
        </Row>
      </div>

      {/* Color */}
      <div style={{ margin:'0 20px 14px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16, padding:'13px 16px' }}>
        <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Color</div>
        <div style={{ display:'flex', gap:9, flexWrap:'wrap' }}>
          {MEETING_COLORS.map(c=><button key={c} onClick={()=>setColor(c)} style={{ width:30, height:30, borderRadius:'50%', background:c, border:color===c?'2.5px solid var(--sc-text)':'2.5px solid transparent', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', padding:0, transition:'all 120ms' }}>{color===c && <SFSymbol name="check" size={14} color="#fff" weight={700}/>}</button>)}
        </div>
      </div>

      {/* Notes */}
      <div style={{ margin:'0 20px 14px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16, overflow:'hidden' }}>
        <div style={{ display:'flex', gap:13, padding:'13px 16px' }}>
          <div style={{ width:32, height:32, borderRadius:9, background:'rgba(94,77,187,0.10)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0, marginTop:1 }}><SFSymbol name="edit_note" size={16} color="var(--sc-primary)" fill/></div>
          <textarea value={desc} onChange={e=>setDesc(e.target.value)} rows={2} placeholder="Add notes…"
            style={{ flex:1, fontFamily:'var(--sc-font)', fontSize:14, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', resize:'none', lineHeight:1.6, boxSizing:'border-box', paddingTop:4 }}/>
        </div>
      </div>

      <div style={{ padding:'0 20px' }}>
        <button onClick={save} disabled={!canSave} style={{ width:'100%', padding:'14px 0', background:canSave?color:'var(--sc-hover)', color:canSave?'#fff':'var(--sc-text-4)', border:'none', borderRadius:14, fontSize:15, fontWeight:700, cursor:canSave?'pointer':'default', boxShadow:canSave?`0 6px 20px ${tintC(color,0.5)}`:'none', display:'flex', alignItems:'center', justifyContent:'center', gap:7 }}>
          <SFSymbol name="check" size={16} color={canSave?'#fff':'var(--sc-text-4)'} weight={700}/>{editing?'Save Meeting':'Add Meeting'}
        </button>
      </div>

      {editing && (
        <div style={{ padding:'10px 20px 0' }}>
          <button onClick={()=>setConfirmDelete(true)} style={{ width:'100%', padding:'13px 0', background:'transparent', color:'var(--sc-danger)', border:'0.5px solid #ffdad6', borderRadius:14, fontSize:14, fontWeight:600, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:6 }}>
            <SFSymbol name="delete" size={15} color="var(--sc-danger)"/>Delete Meeting
          </button>
        </div>
      )}

      {confirmDelete && (
        <div style={{ position:'fixed', inset:0, zIndex:500, display:'flex', alignItems:'center', justifyContent:'center', padding:24 }}>
          <div onClick={()=>setConfirmDelete(false)} style={{ position:'absolute', inset:0, background:'rgba(0,0,0,0.45)', backdropFilter:'blur(8px)', WebkitBackdropFilter:'blur(8px)' }}/>
          <div style={{ position:'relative', width:'100%', maxWidth:300, background:'var(--sc-card)', borderRadius:22, overflow:'hidden', boxShadow:'0 32px 80px rgba(0,0,0,0.36)', animation:'springScale 320ms cubic-bezier(0.34,1.56,0.64,1) both' }}>
            <div style={{ padding:'28px 24px 20px', textAlign:'center' }}>
              <div style={{ width:52, height:52, borderRadius:16, background:'#ffdad6', display:'flex', alignItems:'center', justifyContent:'center', margin:'0 auto 16px' }}><SFSymbol name="delete" size={26} color="var(--sc-danger)" fill/></div>
              <div style={{ fontSize:17, fontWeight:700, color:'var(--sc-text)', marginBottom:8 }}>Delete Meeting?</div>
              <div style={{ fontSize:13.5, color:'var(--sc-text-3)', lineHeight:1.55 }}>"<span style={{ fontWeight:600, color:'var(--sc-text)' }}>{initial.title}</span>" will be removed.</div>
            </div>
            <div style={{ display:'flex', borderTop:'0.5px solid var(--sc-separator)' }}>
              <button onClick={()=>setConfirmDelete(false)} style={{ flex:1, padding:'16px 0', background:'transparent', color:'var(--sc-text-2)', border:'none', borderRight:'0.5px solid var(--sc-separator)', fontSize:15, fontWeight:500, cursor:'pointer' }}>Cancel</button>
              <button onClick={()=>{ app.deleteMeeting(initial.id); app.setModal(null); }} style={{ flex:1, padding:'16px 0', background:'transparent', color:'var(--sc-danger)', border:'none', fontSize:15, fontWeight:700, cursor:'pointer' }}>Delete</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

Object.assign(window, { CalendarScreen, MeetingSheet, DayAddChooserSheet });
