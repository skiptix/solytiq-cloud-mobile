// Solytiq Cloud · iOS v2 — Feature screens & sheets
// Exports: TimelinesScreen, TimelineScreen,
//   AddTimelineSheet, MilestoneEditorSheet, WorkspaceSwitcherSheet,
//   WorkspaceWizardSheet, ItemSettingsSheet, TwoFASheet

const { useState: useStateF, useRef: useRefF, useMemo: useMemoF, useEffect: useEffectF } = React;

// ─── Shared helpers ───────────────────────────────────────────
const TL_STATUSES = [
  { key:'upcoming',    label:'Upcoming',    color:'#9d8dff', icon:'schedule' },
  { key:'in-progress', label:'In progress', color:'#ea580c', icon:'pending' },
  { key:'done',        label:'Done',        color:'#10B981', icon:'check_circle' },
];
const MS_COLORS = ['#5e4dbb','#1D4ED8','#10B981','#ea580c','#f59e0b','#ba1a1a','#db2777','#0d9488'];
const statusOf = k => TL_STATUSES.find(s => s.key === k) || TL_STATUSES[0];
const MONTHS_SHORT = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
function fmtMilestoneDate(d) {
  if (!d) return null;
  const [y,m,day] = d.slice(0,10).split('-').map(Number);
  if (!m || !day) return d;
  return `${MONTHS_SHORT[m-1]} ${day}`;
}
function sortMilestones(ms) {
  return [...ms].sort((a,b) => {
    if (a.date && b.date) { if (a.date !== b.date) return a.date < b.date ? -1 : 1; }
    else if (a.date) return -1;
    else if (b.date) return 1;
    return 0;
  });
}
// effective status accounting for "today is in progress, past = done"
function effectiveMs(m, today) {
  if (m.status === 'done') return 'done';
  if (m.date && m.date < today) return 'done';
  if (m.date === today) return 'in-progress';
  return m.status;
}

// ════════════════════════════════════════════════════════════
//  TimelinesScreen — list of timelines
// ════════════════════════════════════════════════════════════
function TimelinesScreen() {
  const app = window.useApp();
  const { NavHeader, Card, SectionHeader, EmptyRow, SFSymbol } = window;
  const [scrollY, setScrollY] = useStateF(0);
  const today = window.todayIso();
  const timelines = app.timelines || [];
  const connected = app.profile.mode === 'server';

  const goTo = id => { app.setSelectedTimelineId(id); app.setScreen('timeline'); };

  const Row = ({ tl, index=0 }) => {
    const total = tl.milestones.length;
    const done = tl.milestones.filter(m => effectiveMs(m, today) === 'done').length;
    const pct = total ? Math.round((done/total)*100) : 0;
    const accent = tl.color || 'var(--sc-primary)';
    return (
      <button onClick={() => goTo(tl.id)} style={{
        width:'100%', display:'flex', alignItems:'center', gap:13, padding:'14px 16px',
        background:'transparent', border:'none', borderBottom:'0.5px solid var(--sc-separator)',
        cursor:'pointer', textAlign:'left',
        animation:`rowSlideIn 300ms cubic-bezier(0.34,1.2,0.64,1) ${index*50}ms both`,
      }}
        onMouseEnter={e=>e.currentTarget.style.background='var(--sc-hover)'}
        onMouseLeave={e=>e.currentTarget.style.background='transparent'}>
        <div style={{ width:46, height:46, borderRadius:14, flexShrink:0, fontSize:22,
          background: tl.colorBg || 'var(--sc-primary-bg)',
          display:'flex', alignItems:'center', justifyContent:'center' }}>{tl.emoji}</div>
        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ display:'flex', alignItems:'center', gap:7 }}>
            <span style={{ fontSize:15, fontWeight:600, color:'var(--sc-text)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{tl.name}</span>
            {tl.shareEnabled && connected && <SFSymbol name="link" size={12} color="var(--sc-primary-soft)"/>}
          </div>
          <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:5 }}>
            <div style={{ flex:1, height:4, background:'#ebe6f0', borderRadius:9999, overflow:'hidden' }}>
              <div style={{ width:`${pct}%`, height:'100%', background:accent, borderRadius:9999, transition:'width 400ms' }}/>
            </div>
            <span className="sc-mono" style={{ fontSize:11, color:'var(--sc-text-3)', flexShrink:0 }}>{done}/{total}</span>
          </div>
        </div>
        <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
      </button>
    );
  };

  return (
    <div style={{ display:'flex', flexDirection:'column', height:'100%', background:'var(--sc-page)', position:'relative', overflow:'hidden' }}>
      <div className="sc-scroll" onScroll={e=>setScrollY(e.currentTarget.scrollTop)}
        style={{ flex:1, minHeight:0, overflowY:'auto', paddingBottom:96 }}>
        <NavHeader title="Timelines" subtitle="Plan projects and milestones chronologically." scrollY={scrollY}
          leading={
            <button onClick={()=>app.setScreen('lists')} style={{ display:'flex', alignItems:'center', gap:2, background:'transparent', border:'none', cursor:'pointer', color:'var(--sc-primary)', padding:'6px 4px' }}>
              <SFSymbol name="chevron_left" size={22} color="var(--sc-primary)" weight={500}/>
              <span style={{ fontSize:16 }}>Lists</span>
            </button>
          }/>
        <SectionHeader title="All Timelines" right={<span style={{ fontSize:11, color:'var(--sc-text-4)' }}>{timelines.length}</span>}/>
        <Card>
          {timelines.length === 0
            ? <EmptyRow text="No timelines yet."/>
            : timelines.map((tl,i) => <Row key={tl.id} tl={tl} index={i}/>)}
        </Card>
        <div style={{ padding:'16px 22px 0' }}>
          <button onClick={()=>app.setModal('add-timeline')} style={{ width:'100%', padding:'13px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:14, fontWeight:600, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:7, boxShadow:'0 6px 20px rgba(94,77,187,0.35)' }}>
            <SFSymbol name="add" size={16} color="#fff" weight={600}/>New Timeline
          </button>
        </div>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  TimelineScreen — detail with vertical rail
// ════════════════════════════════════════════════════════════
function TimelineScreen() {
  const app = window.useApp();
  const { NavHeader, SFSymbol } = window;
  const [scrollY, setScrollY] = useStateF(0);
  const [menu, setMenu] = useStateF(false);
  const today = window.todayIso();
  const tl = (app.timelines||[]).find(t => t.id === app.selectedTimelineId) || app.timelines[0];
  if (!tl) return null;
  const connected = app.profile.mode === 'server';

  const accent = tl.color || 'var(--sc-primary)';
  const bg = tl.colorBg || 'var(--sc-primary-bg)';
  const layout = tl.layout || 'vertical';
  const milestones = sortMilestones(tl.milestones);
  const total = milestones.length;
  const completions = milestones.map(m => effectiveMs(m, today) === 'done' ? 1 : 0);
  const done = completions.reduce((a,c)=>a+c,0);
  const pct = total ? Math.round((done/total)*100) : 0;
  // rail fill — up to last done node
  let lastDone = -1;
  completions.forEach((c,i) => { if (c) lastDone = i; });
  const fillPct = total > 1 ? Math.max(0, lastDone) / (total-1) * 100 : (done ? 100 : 0);

  const gap = layout === 'compact' ? 8 : layout === 'detailed' ? 24 : 15;
  const nodeSize = layout === 'detailed' ? 20 : layout === 'compact' ? 14 : 17;
  const cardPad = layout === 'compact' ? '9px 12px' : layout === 'detailed' ? '15px 16px' : '12px 14px';

  const cycleStatus = m => {
    const order = ['upcoming','in-progress','done'];
    const next = order[(order.indexOf(m.status)+1) % 3];
    app.updateMilestone(tl.id, m.id, { status: next });
  };
  const editMs = m => { app.setModalData({ tlId: tl.id, milestone: m }); app.setModal('milestone-editor'); };
  const addMs  = () => { app.setModalData({ tlId: tl.id, milestone: null }); app.setModal('milestone-editor'); };

  return (
    <div style={{ display:'flex', flexDirection:'column', height:'100%', background:'var(--sc-page)', position:'relative', overflow:'hidden' }}>
      {menu && <div onClick={()=>setMenu(false)} style={{ position:'absolute', inset:0, zIndex:18 }}/>}
      <div className="sc-scroll" onScroll={e=>setScrollY(e.currentTarget.scrollTop)}
        style={{ flex:1, minHeight:0, overflowY:'auto', paddingBottom:96 }}>
        <NavHeader title={tl.name} large={false} scrollY={1}
          leading={
            <button onClick={()=>app.setScreen('timelines')} style={{ display:'flex', alignItems:'center', gap:2, background:'transparent', border:'none', cursor:'pointer', color:'var(--sc-primary)', padding:'6px 4px' }}>
              <SFSymbol name="chevron_left" size={22} color="var(--sc-primary)" weight={500}/>
              <span style={{ fontSize:16 }}>Timelines</span>
            </button>
          }
          trailing={
            <div style={{ position:'relative' }}>
              <button onClick={()=>setMenu(m=>!m)} style={{ width:32, height:32, borderRadius:'50%', background:menu?'var(--sc-primary)':'var(--sc-primary-bg)', border:'none', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}>
                <SFSymbol name="more_horiz" size={18} color={menu?'#fff':'var(--sc-primary)'}/>
              </button>
              {menu && (
                <div style={{ position:'absolute', right:0, top:40, zIndex:60, background:'var(--sc-card)', borderRadius:16, border:'0.5px solid var(--sc-border)', boxShadow:'0 8px 32px rgba(28,27,34,0.16)', minWidth:190, overflow:'hidden', animation:'popIn 180ms cubic-bezier(0.34,1.56,0.64,1) both' }}>
                  {[
                    { icon:'add_circle', label:'Add Milestone', fn:()=>{ setMenu(false); addMs(); } },
                    { icon:'tune', label:'Timeline Settings', fn:()=>{ setMenu(false); app.setModalData({ kind:'timeline', id:tl.id }); app.setModal('item-settings'); } },
                    ...(connected ? [{ icon:'ios_share', label:'Share', fn:()=>{ setMenu(false); app.setModalData({ kind:'timeline', id:tl.id, tab:'share' }); app.setModal('item-settings'); } }] : []),
                  ].map((item,i)=>(
                    <button key={i} onClick={item.fn} style={{ width:'100%', display:'flex', alignItems:'center', gap:10, padding:'13px 16px', background:'transparent', border:'none', borderTop:i>0?'0.5px solid var(--sc-separator)':'none', cursor:'pointer', fontFamily:'var(--sc-font)', fontSize:14.5, fontWeight:500, color:'var(--sc-text)', textAlign:'left' }}>
                      <SFSymbol name={item.icon} size={16} color="var(--sc-primary)"/>{item.label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          }/>

        {/* Hero */}
        <div style={{ margin:'10px 22px 18px', padding:18, background:`linear-gradient(135deg, ${bg} 0%, #fff 80%)`, border:'0.5px solid var(--sc-border)', borderRadius:24, animation:'springUp 400ms cubic-bezier(0.34,1.2,0.64,1) 60ms both' }}>
          <div style={{ display:'flex', justifyContent:'space-between', alignItems:'flex-start' }}>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontSize:34, lineHeight:1, marginBottom:8 }}>{tl.emoji}</div>
              <div style={{ display:'flex', alignItems:'center', gap:7, flexWrap:'wrap' }}>
                <span style={{ fontSize:21, fontWeight:700, letterSpacing:'-0.015em', color:'var(--sc-text)' }}>{tl.name}</span>
              </div>
              <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:6, flexWrap:'wrap' }}>
                <span style={{ display:'inline-flex', alignItems:'center', gap:4, fontSize:10.5, fontWeight:700, color:accent, background:'#fff', padding:'3px 9px', borderRadius:9999, border:`1px solid ${accent}33` }}>
                  <SFSymbol name="timeline" size={12} color={accent}/>Timeline
                </span>
                {tl.isPublic && connected && <span style={{ display:'inline-flex', alignItems:'center', gap:4, fontSize:11, color:'var(--sc-text-3)' }}>
                  <SFSymbol name="public" size={12} color="var(--sc-text-3)"/>Public
                </span>}
                {tl.shareEnabled && connected && <span style={{ display:'inline-flex', alignItems:'center', gap:4, fontSize:11, color:'var(--sc-primary)', fontWeight:600 }}><SFSymbol name="link" size={12} color="var(--sc-primary)"/>Shared</span>}
              </div>
              {tl.subtitle && <div style={{ fontSize:13, color:'var(--sc-text-3)', marginTop:8 }}>{tl.subtitle}</div>}
            </div>
            <div style={{ textAlign:'right', flexShrink:0, marginLeft:10 }}>
              <div className="sc-mono" style={{ fontSize:34, fontWeight:700, color:accent, letterSpacing:'-0.03em', lineHeight:1 }}>{pct}%</div>
              <div style={{ fontSize:10, color:'var(--sc-text-3)', marginTop:4, fontWeight:700, letterSpacing:'0.07em' }}>{done}/{total} DONE</div>
            </div>
          </div>
        </div>

        {/* Rail */}
        {total === 0 ? (
          <div style={{ padding:'40px 22px', textAlign:'center' }}>
            <div style={{ fontSize:42, marginBottom:10 }}>🛤️</div>
            <div style={{ fontSize:16, fontWeight:600, color:'var(--sc-text-3)', marginBottom:6 }}>No milestones yet</div>
            <div style={{ fontSize:13, color:'var(--sc-text-4)' }}>Add your first milestone to start building this timeline.</div>
          </div>
        ) : (
          <div style={{ position:'relative', padding:'0 22px', marginTop:4 }}>
            {/* rail track */}
            <div style={{ position:'absolute', left:22 + nodeSize/2 - 1, top:nodeSize/2 + 4, bottom:nodeSize/2, width:2, background:'#e8e4f0', borderRadius:2 }}/>
            <div style={{ position:'absolute', left:22 + nodeSize/2 - 1, top:nodeSize/2 + 4, height:`calc(${fillPct}% - 8px)`, width:2, background:accent, borderRadius:2, transition:'height 600ms cubic-bezier(0.4,0,0.2,1)' }}/>
            <div style={{ display:'flex', flexDirection:'column', gap }}>
              {milestones.map((m, i) => {
                const es = effectiveMs(m, today);
                const st = statusOf(es);
                const dot = m.color || st.color;
                const isToday = m.date === today;
                const dateLabel = fmtMilestoneDate(m.date);
                return (
                  <div key={m.id} style={{ position:'relative', display:'flex', gap:16, alignItems:'flex-start',
                    animation:`rowSlideIn 320ms cubic-bezier(0.34,1.2,0.64,1) ${i*60}ms both` }}>
                    <button onClick={()=>cycleStatus(m)} title={`Status: ${st.label}`}
                      style={{ position:'relative', zIndex:1, width:nodeSize, height:nodeSize, borderRadius:'50%', flexShrink:0, marginTop:4,
                        background: es==='done' ? dot : '#fff', border:`2.5px solid ${dot}`, cursor:'pointer', padding:0,
                        display:'flex', alignItems:'center', justifyContent:'center', boxShadow:'0 0 0 4px var(--sc-page)', transition:'all 300ms' }}>
                      {es==='done' && <SFSymbol name="check" size={nodeSize-7} color="#fff" weight={700}/>}
                      {es==='in-progress' && <div style={{ width:nodeSize/3, height:nodeSize/3, borderRadius:'50%', background:dot }}/>}
                    </button>
                    <div onClick={()=>editMs(m)} style={{ flex:1, minWidth:0, cursor:'pointer',
                      background: es==='done' ? `${dot}0c` : 'var(--sc-card)', border:`0.5px solid ${es==='done'?dot+'30':'var(--sc-border)'}`,
                      borderLeft:`3px solid ${dot}`, borderRadius:14, padding:cardPad, boxShadow:'0 1px 3px rgba(0,0,0,0.03)', transition:'box-shadow 150ms' }}
                      onMouseEnter={e=>e.currentTarget.style.boxShadow='0 4px 16px rgba(0,0,0,0.07)'}
                      onMouseLeave={e=>e.currentTarget.style.boxShadow='0 1px 3px rgba(0,0,0,0.03)'}>
                      <div style={{ display:'flex', alignItems:'flex-start', gap:9 }}>
                        {m.emoji && <span style={{ fontSize:layout==='detailed'?19:16, lineHeight:1.2, flexShrink:0 }}>{m.emoji}</span>}
                        <div style={{ flex:1, minWidth:0 }}>
                          <div style={{ display:'flex', alignItems:'center', gap:7, flexWrap:'wrap' }}>
                            <span style={{ fontSize:layout==='detailed'?15.5:14, fontWeight:700, color: es==='done'?'var(--sc-text-3)':'var(--sc-text)', textDecoration: m.status==='done'?'line-through':'none' }}>{m.title}</span>
                            <span style={{ display:'inline-flex', alignItems:'center', gap:3, fontSize:9.5, fontWeight:700, color:st.color, background:`${st.color}1a`, padding:'2px 7px', borderRadius:9999, textTransform:'uppercase', letterSpacing:'0.04em' }}>
                              <SFSymbol name={st.icon} size={10} color={st.color}/>{st.label}
                            </span>
                            {isToday && <span style={{ fontSize:9.5, fontWeight:700, color:'#ea580c', background:'#fff7ed', padding:'2px 7px', borderRadius:9999, letterSpacing:'0.04em' }}>TODAY</span>}
                          </div>
                          {(dateLabel || m.time) && (
                            <div style={{ display:'flex', alignItems:'center', gap:5, marginTop:4, fontSize:11.5, color:'var(--sc-text-3)' }}>
                              <SFSymbol name="event" size={12} color="var(--sc-primary-soft)"/>
                              {dateLabel}{m.time ? `${dateLabel?' · ':''}${m.time}` : ''}
                            </div>
                          )}
                          {m.description && layout !== 'compact' && (
                            <div style={{ fontSize:12.5, color:'var(--sc-text-2)', marginTop:6, lineHeight:1.5, display:'-webkit-box', WebkitLineClamp:3, WebkitBoxOrient:'vertical', overflow:'hidden' }}>{m.description}</div>
                          )}
                        </div>
                        <SFSymbol name="chevron_right" size={14} color="var(--sc-text-4)" style={{ marginTop:3, flexShrink:0 }}/>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
            <button onClick={addMs}
              style={{ display:'flex', alignItems:'center', gap:8, marginTop:gap, marginLeft:nodeSize+16, padding:'11px 14px', borderRadius:12, border:'1.5px dashed #d8d2e8', background:'var(--sc-card-2)', cursor:'pointer', fontFamily:'var(--sc-font)', fontSize:13, fontWeight:600, color:accent }}>
              <SFSymbol name="add" size={16} color={accent}/>Add milestone
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  MilestoneEditorSheet
// ════════════════════════════════════════════════════════════
function MilestoneEditorSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const data = app.modalData || {};
  const tlId = data.tlId;
  const initial = data.milestone;
  const editing = !!initial;

  const [title, setTitle] = useStateF(initial?.title || '');
  const [date, setDate] = useStateF(initial?.date || '');
  const [time, setTime] = useStateF(initial?.time || '');
  const [desc, setDesc] = useStateF(initial?.description || '');
  const [status, setStatus] = useStateF(initial?.status || 'upcoming');
  const [emoji, setEmoji] = useStateF(initial?.emoji || '📍');
  const [color, setColor] = useStateF(initial?.color || null);
  const [showCal, setShowCal] = useStateF(false);
  const [calOffset, setCalOffset] = useStateF(0);
  const [confirmDelete, setConfirmDelete] = useStateF(false);
  const titleRef = useRefF(null);
  useEffectF(() => { const t=setTimeout(()=>titleRef.current?.focus({preventScroll:true}),360); return ()=>clearTimeout(t); }, []);

  const accent = color || statusOf(status).color;
  const MS_EMOJIS = ['📍','🎯','🚀','🏁','🧪','🌐','📝','⛰️','🎉','📈','📉','🔧'];
  const canSave = title.trim().length > 0;
  const save = () => {
    if (!canSave) return;
    const payload = { title:title.trim(), date:date||null, time:time||null, description:desc.trim()||null, status, emoji:emoji||null, color:color||null };
    if (editing) app.updateMilestone(tlId, initial.id, payload);
    else app.addMilestone(tlId, payload);
    app.setModal(null);
  };
  const addDaysIso = n => { const d=new Date(); d.setDate(d.getDate()+n); return d.toISOString().slice(0,10); };
  const dateLabel = date ? new Date(date+'T12:00:00').toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'}) : 'No date';

  const Row = ({icon, iconColor, children, last=false}) => (
    <div style={{ display:'flex', alignItems:'flex-start', gap:13, padding:'13px 16px', borderBottom:last?'none':'0.5px solid var(--sc-separator)' }}>
      <div style={{ width:32, height:32, borderRadius:9, background:`${iconColor}18`, display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0, marginTop:1 }}>
        <SFSymbol name={icon} size={16} color={iconColor} fill/>
      </div>
      <div style={{ flex:1, minWidth:0 }}>{children}</div>
    </div>
  );

  return (
    <div style={{ display:'flex', flexDirection:'column', paddingBottom:32 }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'4px 20px 14px' }}>
        <button onClick={()=>app.setModal(null)} style={{ fontSize:15, color:'var(--sc-text-3)', background:'transparent', border:'none', cursor:'pointer', padding:'6px 0', fontFamily:'var(--sc-font)' }}>Cancel</button>
        <span style={{ fontSize:16, fontWeight:700, color:'var(--sc-text)' }}>{editing?'Edit Milestone':'New Milestone'}</span>
        <button onClick={save} disabled={!canSave} style={{ fontSize:15, fontWeight:700, color:canSave?accent:'var(--sc-text-4)', background:'transparent', border:'none', cursor:canSave?'pointer':'default', padding:'6px 0', fontFamily:'var(--sc-font)' }}>Save</button>
      </div>

      {/* title + emoji */}
      <div style={{ padding:'0 20px 14px', display:'flex', gap:10, alignItems:'center' }}>
        <button onClick={()=>{ const i=MS_EMOJIS.indexOf(emoji); setEmoji(MS_EMOJIS[(i+1)%MS_EMOJIS.length]); }}
          style={{ width:52, height:52, borderRadius:14, background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', fontSize:26, cursor:'pointer', flexShrink:0 }}>{emoji}</button>
        <input ref={titleRef} value={title} onChange={e=>setTitle(e.target.value)} placeholder="Milestone title"
          style={{ flex:1, fontFamily:'var(--sc-font)', fontSize:18, fontWeight:700, color:'var(--sc-text)', background:'var(--sc-tinted)', border:'none', borderRadius:14, padding:'14px 16px', outline:'none', boxSizing:'border-box', letterSpacing:'-0.01em' }}/>
      </div>

      <div style={{ margin:'0 20px 14px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16, overflow:'hidden' }}>
        {/* date */}
        <Row icon="calendar_today" iconColor="#ea580c">
          <div style={{ fontSize:13, fontWeight:500, color:date?'var(--sc-text)':'var(--sc-text-4)', marginBottom:8 }}>{dateLabel}</div>
          <div style={{ display:'flex', gap:6, flexWrap:'wrap' }}>
            {[['Today',0],['Tomorrow',1],['Next Week',7],['Clear',-1]].map(([l,n])=>{
              const v = n>=0 ? addDaysIso(n) : '';
              const a = n>=0 ? date===v : date==='';
              const isClear = n===-1;
              return <button key={l} onClick={()=>{setDate(isClear?'':v);setShowCal(false);}} style={{ fontSize:10.5, fontWeight:700, padding:'5px 9px', borderRadius:9999, background:a&&!isClear?'#ea580c':isClear?'var(--sc-hover)':'var(--sc-primary-bg)', color:a&&!isClear?'#fff':isClear?'var(--sc-text-4)':'var(--sc-primary)', border:'none', cursor:'pointer', whiteSpace:'nowrap' }}>{l}</button>;
            })}
            <button onClick={()=>setShowCal(s=>!s)} style={{ fontSize:10.5, fontWeight:700, padding:'5px 9px', borderRadius:9999, background:showCal?'var(--sc-primary)':'var(--sc-primary-bg)', color:showCal?'#fff':'var(--sc-primary)', border:'none', cursor:'pointer', display:'flex', alignItems:'center', gap:4 }}>
              <SFSymbol name="calendar_month" size={11} color={showCal?'#fff':'var(--sc-primary)'}/>Pick date
            </button>
          </div>
          {showCal && (()=>{
            const now=new Date(); const view=new Date(now.getFullYear(),now.getMonth()+calOffset,1);
            const monthName=view.toLocaleDateString('en-US',{month:'long',year:'numeric'});
            const dim=new Date(view.getFullYear(),view.getMonth()+1,0).getDate(); const fd=view.getDay();
            const cells=[]; for(let i=0;i<fd;i++)cells.push(null); for(let d=1;d<=dim;d++)cells.push(d);
            const isSel=d=>{ if(!date||!d)return false; const dd=new Date(date+'T12:00:00'); return dd.getFullYear()===view.getFullYear()&&dd.getMonth()===view.getMonth()&&dd.getDate()===d; };
            return (
              <div style={{ marginTop:12, background:'var(--sc-tinted)', borderRadius:14, padding:'12px 10px', animation:'springUp 220ms cubic-bezier(0.34,1.2,0.64,1) both' }}>
                <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:8, padding:'0 2px' }}>
                  <button onClick={()=>setCalOffset(o=>o-1)} style={{ width:28, height:28, borderRadius:8, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}><SFSymbol name="chevron_left" size={15} color="var(--sc-text-2)"/></button>
                  <span style={{ fontSize:13, fontWeight:700, color:'var(--sc-text)' }}>{monthName}</span>
                  <button onClick={()=>setCalOffset(o=>o+1)} style={{ width:28, height:28, borderRadius:8, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', display:'flex', alignItems:'center', justifyContent:'center', cursor:'pointer' }}><SFSymbol name="chevron_right" size={15} color="var(--sc-text-2)"/></button>
                </div>
                <div style={{ display:'grid', gridTemplateColumns:'repeat(7,1fr)', gap:2, marginBottom:2 }}>
                  {['S','M','T','W','T','F','S'].map((d,i)=><div key={i} style={{ textAlign:'center', fontSize:9.5, fontWeight:700, color:'var(--sc-text-4)', padding:'3px 0' }}>{d}</div>)}
                </div>
                <div style={{ display:'grid', gridTemplateColumns:'repeat(7,1fr)', gap:2 }}>
                  {cells.map((d,i)=>{ if(!d) return <div key={i}/>; const sel=isSel(d);
                    return <button key={i} onClick={()=>{ const y=view.getFullYear(),m=String(view.getMonth()+1).padStart(2,'0'),day=String(d).padStart(2,'0'); setDate(`${y}-${m}-${day}`); setShowCal(false); }} style={{ aspectRatio:'1/1', borderRadius:9, border:'none', cursor:'pointer', background:sel?'#ea580c':'transparent', color:sel?'#fff':'var(--sc-text)', fontSize:12, fontWeight:sel?700:400, display:'flex', alignItems:'center', justifyContent:'center' }}>{d}</button>;
                  })}
                </div>
              </div>
            );
          })()}
        </Row>
        {/* time */}
        <Row icon="schedule" iconColor="var(--sc-primary)">
          <div style={{ fontSize:12, color:'var(--sc-text-4)', marginBottom:8, fontWeight:500 }}>{time||'No time set'}</div>
          <div style={{ display:'flex', gap:6, flexWrap:'wrap' }}>
            {['','06:00','09:00','12:00','15:00','18:00'].map(t=>{ const a=time===t; const l=t||'None';
              return <button key={l} onClick={()=>setTime(t)} style={{ fontSize:11, fontWeight:700, padding:'5px 10px', borderRadius:9999, background:a?'var(--sc-primary)':'var(--sc-primary-bg)', color:a?'#fff':'var(--sc-primary)', border:'none', cursor:'pointer' }}>{l}</button>;
            })}
          </div>
        </Row>
        {/* status */}
        <Row icon="flag" iconColor={statusOf(status).color}>
          <div style={{ fontSize:12, color:'var(--sc-text-4)', marginBottom:8, fontWeight:500 }}>Status</div>
          <div style={{ display:'flex', gap:6 }}>
            {TL_STATUSES.map(s=>{ const a=status===s.key;
              return <button key={s.key} onClick={()=>setStatus(s.key)} style={{ flex:1, padding:'8px 0', borderRadius:10, border:`1.5px solid ${a?s.color:'var(--sc-border)'}`, background:a?`${s.color}18`:'transparent', fontSize:11, fontWeight:700, color:a?s.color:'var(--sc-text-3)', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:4 }}>
                <SFSymbol name={s.icon} size={12} color={a?s.color:'var(--sc-text-4)'}/>{s.label}</button>;
            })}
          </div>
        </Row>
        {/* accent */}
        <Row icon="palette" iconColor="var(--sc-primary)" last>
          <div style={{ fontSize:12, color:'var(--sc-text-4)', marginBottom:8, fontWeight:500 }}>Accent</div>
          <div style={{ display:'flex', gap:8, flexWrap:'wrap', alignItems:'center' }}>
            <button onClick={()=>setColor(null)} style={{ height:26, padding:'0 11px', borderRadius:9999, background:color===null?'var(--sc-primary-bg)':'transparent', border:`1.5px solid ${color===null?'var(--sc-primary)':'var(--sc-border)'}`, fontSize:11, fontWeight:700, color:color===null?'var(--sc-primary)':'var(--sc-text-3)', cursor:'pointer' }}>Auto</button>
            {MS_COLORS.map(c=><button key={c} onClick={()=>setColor(c)} style={{ width:26, height:26, borderRadius:'50%', background:c, border:color===c?'2.5px solid var(--sc-text)':'2px solid transparent', cursor:'pointer', padding:0 }}/>)}
          </div>
        </Row>
      </div>

      {/* notes */}
      <div style={{ margin:'0 20px 14px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16, overflow:'hidden' }}>
        <div style={{ display:'flex', gap:13, padding:'13px 16px' }}>
          <div style={{ width:32, height:32, borderRadius:9, background:'rgba(94,77,187,0.10)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0, marginTop:1 }}>
            <SFSymbol name="edit_note" size={16} color="var(--sc-primary)" fill/>
          </div>
          <textarea value={desc} onChange={e=>setDesc(e.target.value)} rows={3} placeholder="Add notes, context, or details…"
            style={{ flex:1, fontFamily:'var(--sc-font)', fontSize:14, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', resize:'none', lineHeight:1.6, boxSizing:'border-box', paddingTop:4 }}/>
        </div>
      </div>

      <div style={{ padding:'0 20px' }}>
        <button onClick={save} disabled={!canSave} style={{ width:'100%', padding:'14px 0', background:canSave?accent:'var(--sc-hover)', color:canSave?'#fff':'var(--sc-text-4)', border:'none', borderRadius:14, fontSize:15, fontWeight:700, cursor:canSave?'pointer':'default', boxShadow:canSave?`0 6px 20px ${accent}55`:'none', display:'flex', alignItems:'center', justifyContent:'center', gap:7 }}>
          <SFSymbol name="check" size={16} color={canSave?'#fff':'var(--sc-text-4)'} weight={700}/>{editing?'Save Milestone':'Add Milestone'}
        </button>
      </div>

      {editing && (
        <div style={{ padding:'10px 20px 0' }}>
          <button onClick={()=>setConfirmDelete(true)} style={{ width:'100%', padding:'13px 0', background:'transparent', color:'var(--sc-danger)', border:'0.5px solid #ffdad6', borderRadius:14, fontSize:14, fontWeight:600, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:6 }}>
            <SFSymbol name="delete" size={15} color="var(--sc-danger)"/>Delete Milestone
          </button>
        </div>
      )}

      {confirmDelete && (
        <div style={{ position:'fixed', inset:0, zIndex:500, display:'flex', alignItems:'center', justifyContent:'center', padding:24 }}>
          <div onClick={()=>setConfirmDelete(false)} style={{ position:'absolute', inset:0, background:'rgba(0,0,0,0.45)', backdropFilter:'blur(8px)', WebkitBackdropFilter:'blur(8px)' }}/>
          <div style={{ position:'relative', width:'100%', maxWidth:300, background:'var(--sc-card)', borderRadius:22, overflow:'hidden', boxShadow:'0 32px 80px rgba(0,0,0,0.36)', animation:'springScale 320ms cubic-bezier(0.34,1.56,0.64,1) both' }}>
            <div style={{ padding:'28px 24px 20px', textAlign:'center' }}>
              <div style={{ width:52, height:52, borderRadius:16, background:'#ffdad6', display:'flex', alignItems:'center', justifyContent:'center', margin:'0 auto 16px' }}>
                <SFSymbol name="delete" size={26} color="var(--sc-danger)" fill/>
              </div>
              <div style={{ fontSize:17, fontWeight:700, color:'var(--sc-text)', marginBottom:8 }}>Delete Milestone?</div>
              <div style={{ fontSize:13.5, color:'var(--sc-text-3)', lineHeight:1.55 }}>"<span style={{ fontWeight:600, color:'var(--sc-text)' }}>{initial.title}</span>" will be moved to trash.</div>
            </div>
            <div style={{ display:'flex', borderTop:'0.5px solid var(--sc-separator)' }}>
              <button onClick={()=>setConfirmDelete(false)} style={{ flex:1, padding:'16px 0', background:'transparent', color:'var(--sc-text-2)', border:'none', borderRight:'0.5px solid var(--sc-separator)', fontSize:15, fontWeight:500, cursor:'pointer' }}>Cancel</button>
              <button onClick={()=>{ app.deleteMilestone(tlId, initial.id); app.setModal(null); }} style={{ flex:1, padding:'16px 0', background:'transparent', color:'var(--sc-danger)', border:'none', fontSize:15, fontWeight:700, cursor:'pointer' }}>Delete</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  AddTimelineSheet — wizard
// ════════════════════════════════════════════════════════════
function AddTimelineSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const connected = app.profile.mode === 'server';
  const [step, setStep] = useStateF(0);
  const [name, setName] = useStateF('');
  const [emoji, setEmoji] = useStateF('🛤️');
  const [color, setColor] = useStateF('#5e4dbb');
  const [subtitle, setSubtitle] = useStateF('');
  const [layout, setLayout] = useStateF('vertical');
  const [isPublic, setIsPublic] = useStateF(false);

  const COLORS = ['#5e4dbb','#1D4ED8','#10B981','#ea580c','#db2777','#7c3aed','#0d9488'];
  const EMOJIS = ['🛤️','🚀','🎯','🏁','📅','🌱','⚡','📈','🔬','🎉','🗺️','📊'];
  const LAYOUTS = [
    { key:'compact', label:'Compact', icon:'density_small', desc:'Tight rows, dates only' },
    { key:'vertical', label:'Standard', icon:'view_timeline', desc:'Balanced cards + notes' },
    { key:'detailed', label:'Detailed', icon:'view_agenda', desc:'Large cards, full notes' },
  ];
  const STEPS = connected
    ? [{label:'Name & Look',icon:'edit'},{label:'Layout',icon:'view_timeline'},{label:'Visibility',icon:'lock'}]
    : [{label:'Name & Look',icon:'edit'},{label:'Layout',icon:'view_timeline'}];

  const create = () => {
    const id = app.addTimeline({ name:name.trim()||'New Timeline', emoji, color, colorBg:`${color}18`, subtitle:subtitle.trim()||undefined, layout, isPublic });
    app.setSelectedTimelineId(id); app.setScreen('timeline'); app.setModal(null);
  };
  const canNext = step===0 ? name.trim().length>0 : true;

  return (
    <div style={{ padding:'0 20px 32px', display:'flex', flexDirection:'column' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'4px 0 18px' }}>
        <button onClick={()=>step>0?setStep(s=>s-1):app.setModal(null)} style={{ fontSize:15, color:'var(--sc-text-3)', background:'transparent', border:'none', cursor:'pointer', fontFamily:'var(--sc-font)', padding:'4px 0' }}>{step===0?'Cancel':'← Back'}</button>
        <div style={{ display:'flex', gap:5, alignItems:'center' }}>
          {STEPS.map((_,i)=><div key={i} style={{ height:6, borderRadius:9999, transition:'all 280ms', width:i===step?22:6, background:i<=step?'var(--sc-primary)':'var(--sc-border)', opacity:i>step?0.4:1 }}/>)}
        </div>
        <button onClick={step<STEPS.length-1?()=>setStep(s=>s+1):create} disabled={!canNext} style={{ fontSize:15, fontWeight:700, color:canNext?'var(--sc-primary)':'var(--sc-text-4)', background:'transparent', border:'none', cursor:canNext?'pointer':'default', padding:'4px 0', fontFamily:'var(--sc-font)' }}>{step===STEPS.length-1?'Create ✓':'Next →'}</button>
      </div>

      <div style={{ marginBottom:20 }}>
        <div style={{ display:'flex', alignItems:'center', gap:9, marginBottom:5 }}>
          <div style={{ width:28, height:28, borderRadius:8, background:'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center' }}><SFSymbol name={STEPS[step].icon} size={14} color="var(--sc-primary)" fill/></div>
          <span style={{ fontSize:10, fontWeight:700, color:'var(--sc-primary)', letterSpacing:'0.08em', textTransform:'uppercase' }}>Step {step+1} of {STEPS.length}</span>
        </div>
        <div style={{ fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--sc-text)' }}>{STEPS[step].label}</div>
      </div>

      {step===0 && (
        <div style={{ display:'flex', flexDirection:'column', gap:18 }}>
          <div style={{ display:'flex', alignItems:'center', gap:14, padding:'14px 16px', background:`linear-gradient(135deg, ${color}18 0%, #fff 80%)`, border:`1px solid ${color}30`, borderRadius:18 }}>
            <div style={{ width:52, height:52, borderRadius:15, background:`${color}22`, display:'flex', alignItems:'center', justifyContent:'center', fontSize:26, flexShrink:0, border:`1.5px solid ${color}40` }}>{emoji}</div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontSize:name?17:14, fontWeight:700, color:name?'var(--sc-text)':'var(--sc-text-4)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{name||'Your timeline name…'}</div>
              <div style={{ fontSize:11, color:'var(--sc-text-4)', marginTop:3 }}>Preview</div>
            </div>
          </div>
          <div style={{ background:'var(--sc-tinted)', borderRadius:14, padding:'12px 16px' }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:8 }}>Timeline name *</div>
            <input value={name} onChange={e=>setName(e.target.value)} autoFocus placeholder="e.g. Product Launch, Race Prep…" style={{ width:'100%', fontFamily:'var(--sc-font)', fontSize:17, fontWeight:600, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', boxSizing:'border-box' }}/>
          </div>
          <div style={{ background:'var(--sc-tinted)', borderRadius:14, padding:'12px 16px' }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:8 }}>Subtitle (optional)</div>
            <input value={subtitle} onChange={e=>setSubtitle(e.target.value)} placeholder="A short description…" style={{ width:'100%', fontFamily:'var(--sc-font)', fontSize:14, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', boxSizing:'border-box' }}/>
          </div>
          <div>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Pick an icon</div>
            <div style={{ display:'flex', flexWrap:'wrap', gap:8 }}>
              {EMOJIS.map(e=><button key={e} onClick={()=>setEmoji(e)} style={{ width:42, height:42, borderRadius:12, border:`2px solid ${e===emoji?color:'var(--sc-border)'}`, background:e===emoji?`${color}18`:'transparent', fontSize:20, cursor:'pointer', transform:e===emoji?'scale(1.12)':'scale(1)', transition:'all 150ms' }}>{e}</button>)}
            </div>
          </div>
          <div>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Color</div>
            <div style={{ display:'flex', gap:10 }}>
              {COLORS.map(c=><button key={c} onClick={()=>setColor(c)} style={{ width:32, height:32, borderRadius:'50%', background:c, cursor:'pointer', flexShrink:0, border:c===color?`3px solid ${c}`:'2px solid transparent', outline:c===color?'2px solid #fff':'none', outlineOffset:1, boxShadow:c===color?`0 3px 10px ${c}55`:'none', transform:c===color?'scale(1.15)':'scale(1)', transition:'all 150ms' }}/>)}
            </div>
          </div>
        </div>
      )}

      {step===1 && (
        <div style={{ display:'flex', flexDirection:'column', gap:10 }}>
          {LAYOUTS.map(l=>{ const sel=layout===l.key;
            return <button key={l.key} onClick={()=>setLayout(l.key)} style={{ width:'100%', display:'flex', alignItems:'center', gap:14, padding:'16px', borderRadius:18, border:`1.5px solid ${sel?color:'var(--sc-border)'}`, background:sel?`${color}10`:'var(--sc-card)', cursor:'pointer', textAlign:'left', transition:'all 180ms' }}>
              <div style={{ width:44, height:44, borderRadius:13, flexShrink:0, background:sel?color:'var(--sc-hover)', display:'flex', alignItems:'center', justifyContent:'center' }}><SFSymbol name={l.icon} size={21} color={sel?'#fff':'var(--sc-text-3)'} fill/></div>
              <div style={{ flex:1 }}>
                <div style={{ fontSize:15, fontWeight:700, color:'var(--sc-text)' }}>{l.label}</div>
                <div style={{ fontSize:13, color:'var(--sc-text-3)', marginTop:2 }}>{l.desc}</div>
              </div>
              <div style={{ width:22, height:22, borderRadius:'50%', flexShrink:0, border:`1.5px solid ${sel?color:'var(--sc-border)'}`, background:sel?color:'transparent', display:'flex', alignItems:'center', justifyContent:'center' }}>
                {sel && <svg width="10" height="8" viewBox="0 0 12 10"><path d="M1 5l3 3 7-7" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" fill="none"/></svg>}
              </div>
            </button>;
          })}
          {!connected && (
            <button onClick={create} style={{ marginTop:8, width:'100%', padding:'15px 0', background:color, color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:700, cursor:'pointer', boxShadow:`0 8px 24px ${color}44`, display:'flex', alignItems:'center', justifyContent:'center', gap:8 }}>
              <SFSymbol name="add_circle" size={18} color="#fff" fill/>Create Timeline
            </button>
          )}
        </div>
      )}

      {step===2 && (
        <div style={{ display:'flex', flexDirection:'column', gap:10 }}>
          {[
            { val:false, icon:'lock', title:'Private', sub:'Just you', desc:'Only you can see this timeline.', color:'#5e4dbb', bg:'#F5F3FF' },
            { val:true, icon:'public', title:'Public', sub:'Workspace', desc:'Visible to everyone in your workspace.', color:'#10B981', bg:'#ecfdf5' },
          ].map(opt=>{ const sel=isPublic===opt.val;
            return <button key={String(opt.val)} onClick={()=>setIsPublic(opt.val)} style={{ width:'100%', display:'flex', alignItems:'flex-start', gap:14, padding:'16px', borderRadius:18, border:`1.5px solid ${sel?opt.color:'var(--sc-border)'}`, background:sel?opt.bg:'var(--sc-card)', cursor:'pointer', textAlign:'left', boxShadow:sel?`0 4px 16px ${opt.color}22`:'none', transition:'all 180ms' }}>
              <div style={{ width:44, height:44, borderRadius:13, flexShrink:0, background:sel?opt.color:'var(--sc-hover)', display:'flex', alignItems:'center', justifyContent:'center' }}><SFSymbol name={opt.icon} size={21} color={sel?'#fff':'var(--sc-text-3)'} fill/></div>
              <div style={{ flex:1 }}>
                <div style={{ display:'flex', alignItems:'center', gap:8, marginBottom:4 }}>
                  <span style={{ fontSize:15, fontWeight:700, color:'var(--sc-text)' }}>{opt.title}</span>
                  <span style={{ fontSize:10, fontWeight:700, color:opt.color, background:`${opt.color}18`, borderRadius:9999, padding:'2px 8px' }}>{opt.sub}</span>
                </div>
                <div style={{ fontSize:13, color:'var(--sc-text-3)', lineHeight:1.45 }}>{opt.desc}</div>
              </div>
            </button>;
          })}
          <button onClick={create} style={{ marginTop:8, width:'100%', padding:'15px 0', background:color, color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:700, cursor:'pointer', boxShadow:`0 8px 24px ${color}44`, display:'flex', alignItems:'center', justifyContent:'center', gap:8 }}>
            <SFSymbol name="add_circle" size={18} color="#fff" fill/>Create Timeline
          </button>
        </div>
      )}
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  WorkspaceSwitcherSheet
// ════════════════════════════════════════════════════════════
function WorkspaceSwitcherSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const wss = app.workspaces || [];
  const select = id => { app.setCurrentWorkspaceId(id); app.setModal(null); };

  return (
    <div style={{ paddingBottom:28 }}>
      <div style={{ padding:'6px 22px 14px' }}>
        <div style={{ fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--sc-text)' }}>Workspaces</div>
        <div style={{ fontSize:13, color:'var(--sc-text-3)', marginTop:2 }}>Switch between separate environments.</div>
      </div>
      <window.Card style={{ margin:'0 18px 14px' }}>
        {wss.map((ws,i)=>{
          const active = ws.id === app.currentWorkspaceId;
          return (
            <button key={ws.id} onClick={()=>select(ws.id)} style={{ width:'100%', display:'flex', alignItems:'center', gap:13, padding:'14px 16px', background:active?'var(--sc-primary-bg)':'transparent', border:'none', borderBottom:i<wss.length-1?'0.5px solid var(--sc-separator)':'none', cursor:'pointer', textAlign:'left' }}>
              <div style={{ width:46, height:46, borderRadius:14, background:active?'var(--sc-primary)':'var(--sc-tinted)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:24, flexShrink:0 }}>{ws.emoji}</div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ display:'flex', alignItems:'center', gap:7 }}>
                  <span style={{ fontSize:15.5, fontWeight:700, color:'var(--sc-text)' }}>{ws.name}</span>
                  {ws.role==='owner' && <span style={{ fontSize:9, fontWeight:700, color:'var(--sc-primary)', background:'var(--sc-primary-bg-2)', borderRadius:9999, padding:'2px 7px', textTransform:'uppercase', letterSpacing:'0.04em' }}>Owner</span>}
                </div>
                <div style={{ display:'flex', alignItems:'center', gap:8, marginTop:3, fontSize:11.5, color:'var(--sc-text-3)', whiteSpace:'nowrap' }}>
                  <span style={{ display:'flex', alignItems:'center', gap:3 }}><SFSymbol name={ws.visibility==='public'?'public':'lock'} size={11} color="var(--sc-text-4)"/>{ws.visibility==='public'?'Public':'Private'}</span>
                  <span>·</span>
                  <span style={{ display:'flex', alignItems:'center', gap:3 }}><SFSymbol name="group" size={11} color="var(--sc-text-4)"/>{ws.memberCount} member{ws.memberCount!==1?'s':''}</span>
                </div>
              </div>
              {active && <SFSymbol name="check_circle" size={20} color="var(--sc-primary)" fill/>}
            </button>
          );
        })}
      </window.Card>
      <div style={{ padding:'0 18px' }}>
        <button onClick={()=>app.setModal('workspace-wizard')} style={{ width:'100%', padding:'14px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:600, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:7, boxShadow:'0 6px 20px rgba(94,77,187,0.35)' }}>
          <SFSymbol name="add" size={18} color="#fff" weight={600}/>New Workspace
        </button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  WorkspaceWizardSheet
// ════════════════════════════════════════════════════════════
function WorkspaceWizardSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [step, setStep] = useStateF(0);
  const [name, setName] = useStateF('');
  const [desc, setDesc] = useStateF('');
  const [emoji, setEmoji] = useStateF('🏠');
  const [visibility, setVisibility] = useStateF('private');
  const [memberInput, setMemberInput] = useStateF('');
  const [members, setMembers] = useStateF([]);
  const [done, setDone] = useStateF(false);

  const EMOJIS = ['🏠','🚀','🎨','💼','🌿','🎯','⚡','🔬','📚','🏡','🎸','🧩'];
  const KNOWN = ['sam_lee','priya_n','jonas_k','dana_w','marco_b'];
  const addMember = () => {
    const u = memberInput.trim().replace(/^@/,'');
    if (!u || members.find(m=>m.username===u)) { setMemberInput(''); return; }
    setMembers(prev=>[...prev, {userId:`u-${Date.now()}`, username:u, role:'member'}]);
    setMemberInput('');
  };
  const create = () => {
    app.addWorkspace({ name:name.trim(), description:desc.trim()||undefined, emoji, visibility, members });
    setDone(true);
  };
  const canNext = name.trim().length>0;

  if (done) {
    return (
      <div style={{ padding:'40px 24px', textAlign:'center' }}>
        <div style={{ width:72, height:72, borderRadius:'50%', background:'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center', margin:'0 auto 16px', fontSize:34, animation:'springScale 400ms cubic-bezier(0.34,1.56,0.64,1) both' }}>{emoji}</div>
        <div style={{ fontSize:20, fontWeight:700, color:'var(--sc-text)', marginBottom:8 }}>"{name}" created!</div>
        <div style={{ fontSize:13.5, color:'var(--sc-text-3)', marginBottom:24, lineHeight:1.5 }}>Your workspace is ready. Start adding lists, folders and timelines.</div>
        <button onClick={()=>{ const ws=app.workspaces[app.workspaces.length-1]; if(ws) app.setCurrentWorkspaceId(ws.id); app.setModal(null); app.setScreen('lists'); }} style={{ width:'100%', padding:'14px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:600, cursor:'pointer', boxShadow:'0 6px 20px rgba(94,77,187,0.35)' }}>Go to workspace</button>
      </div>
    );
  }

  return (
    <div style={{ padding:'0 20px 32px', display:'flex', flexDirection:'column' }}>
      <div style={{ display:'flex', alignItems:'center', justifyContent:'space-between', padding:'4px 0 18px' }}>
        <button onClick={()=>step>0?setStep(0):app.setModal('workspace-switcher')} style={{ fontSize:15, color:'var(--sc-text-3)', background:'transparent', border:'none', cursor:'pointer', fontFamily:'var(--sc-font)' }}>{step===0?'← Workspaces':'Back'}</button>
        <div style={{ display:'flex', gap:5 }}>{[0,1].map(i=><div key={i} style={{ height:6, borderRadius:9999, width:i===step?22:6, background:i<=step?'var(--sc-primary)':'var(--sc-border)' }}/>)}</div>
        <button onClick={step===0?()=>setStep(1):create} disabled={!canNext} style={{ fontSize:15, fontWeight:700, color:canNext?'var(--sc-primary)':'var(--sc-text-4)', background:'transparent', border:'none', cursor:canNext?'pointer':'default', fontFamily:'var(--sc-font)' }}>{step===0?'Next →':'Create ✓'}</button>
      </div>

      {step===0 && (
        <div style={{ display:'flex', flexDirection:'column', gap:18 }}>
          <div style={{ fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--sc-text)' }}>Create workspace</div>
          <div style={{ display:'flex', alignItems:'center', gap:14, padding:'14px 16px', background:'var(--sc-tinted)', borderRadius:18, border:'0.5px solid var(--sc-border)' }}>
            <div style={{ width:56, height:56, borderRadius:16, background:'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:30, flexShrink:0 }}>{emoji}</div>
            <div style={{ flex:1, minWidth:0 }}>
              <div style={{ fontSize:name?17:14, fontWeight:700, color:name?'var(--sc-text)':'var(--sc-text-4)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{name||'Workspace name…'}</div>
              <div style={{ fontSize:11.5, color:'var(--sc-text-4)', marginTop:3 }}>{visibility==='public'?'Public':'Private'} workspace</div>
            </div>
          </div>
          <div style={{ background:'var(--sc-tinted)', borderRadius:14, padding:'12px 16px' }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:8 }}>Name *</div>
            <input value={name} onChange={e=>setName(e.target.value)} autoFocus placeholder="e.g. Marketing, Side Projects…" style={{ width:'100%', fontFamily:'var(--sc-font)', fontSize:17, fontWeight:600, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', boxSizing:'border-box' }}/>
          </div>
          <div style={{ background:'var(--sc-tinted)', borderRadius:14, padding:'12px 16px' }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:8 }}>Description (optional)</div>
            <input value={desc} onChange={e=>setDesc(e.target.value)} placeholder="What's this workspace for?" style={{ width:'100%', fontFamily:'var(--sc-font)', fontSize:14, color:'var(--sc-text)', background:'transparent', border:'none', outline:'none', boxSizing:'border-box' }}/>
          </div>
          <div>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Icon</div>
            <div style={{ display:'flex', flexWrap:'wrap', gap:8 }}>
              {EMOJIS.map(e=><button key={e} onClick={()=>setEmoji(e)} style={{ width:42, height:42, borderRadius:12, border:`2px solid ${e===emoji?'var(--sc-primary)':'var(--sc-border)'}`, background:e===emoji?'var(--sc-primary-bg)':'transparent', fontSize:20, cursor:'pointer', transform:e===emoji?'scale(1.12)':'scale(1)', transition:'all 150ms' }}>{e}</button>)}
            </div>
          </div>
          <div>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Visibility</div>
            <div style={{ display:'flex', gap:8 }}>
              {['private','public'].map(v=>{ const sel=visibility===v;
                return <button key={v} onClick={()=>setVisibility(v)} style={{ flex:1, display:'flex', alignItems:'center', gap:8, padding:'12px 14px', borderRadius:12, border:`1.5px solid ${sel?'var(--sc-primary)':'var(--sc-border)'}`, background:sel?'var(--sc-primary-bg)':'transparent', cursor:'pointer', textAlign:'left' }}>
                  <SFSymbol name={v==='private'?'lock':'public'} size={16} color={sel?'var(--sc-primary)':'var(--sc-text-3)'}/>
                  <div>
                    <div style={{ fontSize:13, fontWeight:600, color:sel?'var(--sc-primary)':'var(--sc-text)' }}>{v==='private'?'Private':'Public'}</div>
                    <div style={{ fontSize:10.5, color:'var(--sc-text-4)', marginTop:1 }}>{v==='private'?'Invited only':'All users'}</div>
                  </div>
                </button>;
              })}
            </div>
          </div>
        </div>
      )}

      {step===1 && (
        <div style={{ display:'flex', flexDirection:'column', gap:14 }}>
          <div>
            <div style={{ fontSize:22, fontWeight:700, letterSpacing:'-0.02em', color:'var(--sc-text)' }}>Invite members</div>
            <div style={{ fontSize:13, color:'var(--sc-text-3)', marginTop:3 }}>Add people now or invite them later.</div>
          </div>
          <div style={{ display:'flex', gap:8 }}>
            <div style={{ flex:1, display:'flex', alignItems:'center', gap:8, background:'var(--sc-tinted)', borderRadius:12, padding:'10px 14px', border:'0.5px solid var(--sc-border)' }}>
              <SFSymbol name="person" size={16} color="var(--sc-text-3)"/>
              <input value={memberInput} onChange={e=>setMemberInput(e.target.value)} onKeyDown={e=>e.key==='Enter'&&addMember()} placeholder="Username…" style={{ flex:1, background:'transparent', border:'none', outline:'none', fontFamily:'var(--sc-font)', fontSize:14, color:'var(--sc-text)' }}/>
            </div>
            <button onClick={addMember} disabled={!memberInput.trim()} style={{ padding:'0 18px', borderRadius:12, border:'none', background:memberInput.trim()?'var(--sc-primary)':'var(--sc-hover)', color:memberInput.trim()?'#fff':'var(--sc-text-4)', fontSize:14, fontWeight:700, cursor:memberInput.trim()?'pointer':'default' }}>Add</button>
          </div>
          <div style={{ display:'flex', flexWrap:'wrap', gap:6 }}>
            {KNOWN.filter(k=>!members.find(m=>m.username===k)).slice(0,4).map(k=>(
              <button key={k} onClick={()=>setMembers(prev=>[...prev,{userId:`u-${k}`, username:k, role:'member'}])} style={{ fontSize:12, fontWeight:600, color:'var(--sc-primary)', background:'var(--sc-primary-bg)', border:'none', borderRadius:9999, padding:'6px 12px', cursor:'pointer', display:'flex', alignItems:'center', gap:4 }}>
                <SFSymbol name="add" size={12} color="var(--sc-primary)"/>@{k}
              </button>
            ))}
          </div>
          <window.Card style={{ margin:0 }}>
            <div style={{ display:'flex', alignItems:'center', gap:12, padding:'12px 16px', borderBottom:members.length?'0.5px solid var(--sc-separator)':'none' }}>
              <div style={{ width:36, height:36, borderRadius:'50%', background:'linear-gradient(135deg,#9d8dff,#5e4dbb)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}><span style={{ fontSize:13, fontWeight:700, color:'#fff' }}>AM</span></div>
              <div style={{ flex:1 }}>
                <div style={{ fontSize:14, fontWeight:600, color:'var(--sc-text)' }}>Alex Mendez (You)</div>
                <div style={{ fontSize:11.5, color:'var(--sc-text-4)' }}>@alex_admin</div>
              </div>
              <span style={{ fontSize:9.5, fontWeight:700, color:'var(--sc-primary)', background:'var(--sc-primary-bg)', borderRadius:9999, padding:'2px 8px', textTransform:'uppercase' }}>Owner</span>
            </div>
            {members.map((m,i)=>(
              <div key={m.userId} style={{ display:'flex', alignItems:'center', gap:12, padding:'12px 16px', borderBottom:i<members.length-1?'0.5px solid var(--sc-separator)':'none' }}>
                <div style={{ width:36, height:36, borderRadius:'50%', background:'var(--sc-primary)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}><span style={{ fontSize:13, fontWeight:700, color:'#fff' }}>{m.username[0].toUpperCase()}</span></div>
                <div style={{ flex:1 }}>
                  <div style={{ fontSize:14, fontWeight:600, color:'var(--sc-text)' }}>@{m.username}</div>
                  <div style={{ fontSize:11.5, color:'var(--sc-text-4)' }}>Member</div>
                </div>
                <button onClick={()=>setMembers(prev=>prev.filter(x=>x.userId!==m.userId))} style={{ width:30, height:30, borderRadius:'50%', background:'var(--sc-hover)', border:'none', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center' }}><SFSymbol name="close" size={14} color="var(--sc-text-4)"/></button>
              </div>
            ))}
          </window.Card>
          <button onClick={create} style={{ width:'100%', padding:'15px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:700, cursor:'pointer', boxShadow:'0 8px 24px rgba(94,77,187,0.4)', display:'flex', alignItems:'center', justifyContent:'center', gap:8 }}>
            <SFSymbol name="rocket_launch" size={17} color="#fff" fill/>Create Workspace
          </button>
        </div>
      )}
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  ItemSettingsSheet — appearance / access / folder / share
// ════════════════════════════════════════════════════════════
function ItemSettingsSheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const data = app.modalData || {};
  const kind = data.kind || 'list';
  const id = data.id;
  const item = kind==='timeline' ? (app.timelines||[]).find(t=>t.id===id) : (app.lists||[]).find(l=>l.id===id);
  const update = kind==='timeline' ? app.updateTimeline : app.updateList;
  const [tab, setTab] = useStateF(data.tab || 'appearance');
  const [copied, setCopied] = useStateF(false);
  const [pwInput, setPwInput] = useStateF('');
  const [showPwField, setShowPwField] = useStateF(false);
  const connected = app.profile.mode === 'server';

  if (!item) return <div style={{ padding:24, color:'var(--sc-text-3)' }}>Item not found.</div>;
  const accent = item.color || 'var(--sc-primary)';
  const LIST_COLORS = [['#5e4dbb','#F5F3FF'],['#1D4ED8','#eff6ff'],['#10B981','#ECFDF5'],['#ea580c','#fff7ed'],['#f59e0b','#fffbeb'],['#db2777','#fdf2f8'],['#7c3aed','#f5f3ff'],['#0d9488','#f0fdfa']];
  const EMOJIS = ['📋','🚀','💼','📚','🏡','🌱','⚡','🎯','🔬','💡','🎨','📊','🛤️','🏁','📈'];
  const folders = app.folders || [];
  const hasShare = true;

  const TABS = [
    { id:'appearance', label:'Look', icon:'palette' },
    ...(kind==='list' ? [{ id:'organization', label:'Folder', icon:'folder_open' }] : []),
    ...(connected ? [
      { id:'access', label:'Access', icon:'shield_person' },
      { id:'share', label:'Share', icon:'link' },
    ] : []),
  ];
  // If a share/access tab was requested but we're offline, fall back to appearance.
  const activeTab = TABS.find(t => t.id === tab) ? tab : 'appearance';

  const shareUrl = item.shareToken ? `cloud.solytiq.app/share/${kind}/${item.shareToken}` : '';
  const copyLink = () => { setCopied(true); setTimeout(()=>setCopied(false),1600); };
  const toggleShare = on => update(id, on ? { shareEnabled:true, shareToken: item.shareToken || `${kind.slice(0,2)}-${Date.now().toString(36)}` } : { shareEnabled:false });

  return (
    <div style={{ paddingBottom:28 }}>
      {/* header */}
      <div style={{ display:'flex', alignItems:'center', gap:12, padding:'6px 20px 14px' }}>
        <div style={{ width:40, height:40, borderRadius:12, background:item.colorBg||'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:20, flexShrink:0 }}>{item.emoji}</div>
        <div style={{ flex:1, minWidth:0 }}>
          <div style={{ fontSize:17, fontWeight:700, color:'var(--sc-text)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{item.name}</div>
          <div style={{ fontSize:11.5, color:'var(--sc-text-4)' }}>{kind==='timeline'?'Timeline settings':'List settings'}</div>
        </div>
        <button onClick={()=>app.setModal(null)} style={{ width:30, height:30, borderRadius:'50%', background:'var(--sc-hover)', border:'none', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center' }}><SFSymbol name="close" size={15} color="var(--sc-text-2)"/></button>
      </div>

      {/* tabs */}
      <div style={{ padding:'0 20px 16px' }}>
        <div style={{ display:'flex', gap:3, background:'var(--sc-primary-bg)', borderRadius:14, padding:4 }}>
          {TABS.map(t=>{ const a=activeTab===t.id;
            return <button key={t.id} onClick={()=>setTab(t.id)} style={{ flex:1, display:'flex', alignItems:'center', justifyContent:'center', gap:5, fontFamily:'var(--sc-font)', fontSize:12, fontWeight:600, color:a?'#fff':'var(--sc-primary)', background:a?'var(--sc-primary)':'transparent', border:'none', borderRadius:10, padding:'8px 4px', cursor:'pointer', transition:'all 150ms' }}>
              <SFSymbol name={t.icon} size={13} color={a?'#fff':'var(--sc-primary)'}/>{t.label}</button>;
          })}
        </div>
      </div>

      <div style={{ padding:'0 20px' }}>
        {/* APPEARANCE */}
        {activeTab==='appearance' && (
          <div style={{ display:'flex', flexDirection:'column', gap:18, animation:'fadeUp 240ms ease both' }}>
            <div>
              <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Icon</div>
              <div style={{ display:'flex', flexWrap:'wrap', gap:8 }}>
                {EMOJIS.map(e=><button key={e} onClick={()=>update(id,{emoji:e})} style={{ width:40, height:40, borderRadius:12, border:`2px solid ${e===item.emoji?accent:'var(--sc-border)'}`, background:e===item.emoji?`${accent}18`:'transparent', fontSize:19, cursor:'pointer', transform:e===item.emoji?'scale(1.1)':'scale(1)', transition:'all 150ms' }}>{e}</button>)}
              </div>
            </div>
            <div>
              <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Color</div>
              <div style={{ display:'flex', gap:10, flexWrap:'wrap' }}>
                {LIST_COLORS.map(([c,bg])=><button key={c} onClick={()=>update(id,{color:c, colorBg:bg})} style={{ width:32, height:32, borderRadius:'50%', background:c, cursor:'pointer', flexShrink:0, border:c===item.color?`3px solid ${c}`:'2px solid transparent', outline:c===item.color?'2px solid #fff':'none', outlineOffset:1, boxShadow:c===item.color?`0 3px 10px ${c}55`:'none', transform:c===item.color?'scale(1.15)':'scale(1)', transition:'all 150ms' }}/>)}
              </div>
            </div>
          </div>
        )}

        {/* ACCESS */}
        {activeTab==='access' && connected && (
          <div style={{ animation:'fadeUp 240ms ease both' }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Workspace visibility</div>
            <div style={{ display:'flex', gap:4, background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', borderRadius:14, padding:4 }}>
              {[{label:'Private',icon:'lock',val:false},{label:'Public',icon:'public',val:true}].map(opt=>{ const sel=!!item.isPublic===opt.val;
                return <button key={opt.label} onClick={()=>update(id,{isPublic:opt.val})} style={{ flex:1, display:'flex', alignItems:'center', justifyContent:'center', gap:6, padding:'11px 12px', borderRadius:10, border:'none', background:sel?'var(--sc-primary)':'transparent', cursor:'pointer', fontSize:13, fontWeight:sel?600:500, color:sel?'#fff':'var(--sc-primary)', transition:'all 120ms' }}>
                  <SFSymbol name={opt.icon} size={14} color={sel?'#fff':'var(--sc-primary)'}/>{opt.label}{sel&&<SFSymbol name="check" size={13} color="#fff"/>}</button>;
              })}
            </div>
            <div style={{ fontSize:12, color:'var(--sc-text-4)', marginTop:10, lineHeight:1.5 }}>Controls who can see this {kind} inside your workspace. Doesn't affect public share links.</div>
          </div>
        )}

        {/* ORGANIZATION */}
        {activeTab==='organization' && kind==='list' && (
          <div style={{ animation:'fadeUp 240ms ease both' }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Folder</div>
            <window.Card style={{ margin:0 }}>
              {[{id:undefined, name:'No folder', emoji:undefined, color:undefined}, ...folders].map((f,i,arr)=>{
                const sel = (f.id||undefined) === (item.folderId||undefined);
                return (
                  <button key={f.id||'none'} onClick={()=>update(id,{folderId:f.id})} style={{ width:'100%', display:'flex', alignItems:'center', gap:12, padding:'13px 16px', background:sel?'var(--sc-primary-bg)':'transparent', border:'none', borderBottom:i<arr.length-1?'0.5px solid var(--sc-separator)':'none', cursor:'pointer', textAlign:'left' }}>
                    {f.id ? <span style={{ fontSize:17 }}>{f.emoji}</span> : <SFSymbol name="remove_circle_outline" size={17} color="var(--sc-text-4)"/>}
                    <span style={{ flex:1, fontSize:14, fontWeight:sel?600:500, color:sel?'var(--sc-primary)':'var(--sc-text)' }}>{f.name}</span>
                    {sel && <SFSymbol name="check" size={15} color="var(--sc-primary)"/>}
                  </button>
                );
              })}
            </window.Card>
          </div>
        )}

        {/* SHARE */}
        {activeTab==='share' && connected && (
          <div style={{ display:'flex', flexDirection:'column', gap:16, animation:'fadeUp 240ms ease both' }}>
            <div>
              <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Public link</div>
              <div style={{ display:'flex', gap:4, background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', borderRadius:14, padding:4 }}>
                {[{label:'Off',icon:'link_off',val:false},{label:'On',icon:'link',val:true}].map(opt=>{ const sel=!!item.shareEnabled===opt.val;
                  return <button key={opt.label} onClick={()=>toggleShare(opt.val)} style={{ flex:1, display:'flex', alignItems:'center', justifyContent:'center', gap:6, padding:'11px 12px', borderRadius:10, border:'none', background:sel?'var(--sc-primary)':'transparent', cursor:'pointer', fontSize:13, fontWeight:sel?600:500, color:sel?'#fff':'var(--sc-primary)', transition:'all 120ms' }}>
                    <SFSymbol name={opt.icon} size={14} color={sel?'#fff':'var(--sc-primary)'}/>{opt.label}{sel&&<SFSymbol name="check" size={13} color="#fff"/>}</button>;
                })}
              </div>
            </div>

            {item.shareEnabled && (
              <div style={{ display:'flex', flexDirection:'column', gap:16, animation:'fadeUp 200ms ease both' }}>
                {/* URL */}
                <div>
                  <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Share URL</div>
                  <div style={{ background:'var(--sc-primary-bg)', borderRadius:12, padding:'10px 14px', display:'flex', alignItems:'center', gap:10 }}>
                    <SFSymbol name="link" size={16} color="var(--sc-primary)"/>
                    <span style={{ flex:1, fontFamily:'var(--sc-font-mono)', fontSize:11.5, color:'var(--sc-primary)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap' }}>{shareUrl}</span>
                    <button onClick={copyLink} style={{ fontSize:12, fontWeight:600, color:copied?'#10B981':'var(--sc-primary)', background:copied?'#f0fdf4':'#fff', border:`1px solid ${copied?'#a7f3d0':'var(--sc-primary-bg-2)'}`, borderRadius:8, padding:'5px 12px', cursor:'pointer', flexShrink:0, display:'flex', alignItems:'center', gap:4 }}>
                      <SFSymbol name={copied?'check':'content_copy'} size={12} color={copied?'#10B981':'var(--sc-primary)'}/>{copied?'Copied!':'Copy'}
                    </button>
                  </div>
                  <div style={{ fontSize:11.5, color:'var(--sc-text-4)', marginTop:6, lineHeight:1.4, display:'flex', gap:6 }}>
                    <SFSymbol name="visibility" size={13} color="var(--sc-text-4)" style={{ flexShrink:0, marginTop:1 }}/>
                    Anyone with this link can view a read-only copy. No sign-in required.
                  </div>
                </div>

                {/* Subpages (lists only) */}
                {kind==='list' && (
                  <div>
                    <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Sublists</div>
                    <div style={{ display:'flex', gap:4, background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', borderRadius:14, padding:4 }}>
                      {[{label:'Keep private',icon:'lock',val:false},{label:'Share too',icon:'account_tree',val:true}].map(opt=>{ const sel=!!item.shareSubpages===opt.val;
                        return <button key={opt.label} onClick={()=>update(id,{shareSubpages:opt.val})} style={{ flex:1, display:'flex', alignItems:'center', justifyContent:'center', gap:6, padding:'10px 12px', borderRadius:10, border:'none', background:sel?'var(--sc-primary)':'transparent', cursor:'pointer', fontSize:12.5, fontWeight:sel?600:500, color:sel?'#fff':'var(--sc-primary)' }}>
                          <SFSymbol name={opt.icon} size={13} color={sel?'#fff':'var(--sc-primary)'}/>{opt.label}</button>;
                      })}
                    </div>
                  </div>
                )}

                {/* Password */}
                <div>
                  <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Password</div>
                  {item.shareHasPassword && !showPwField ? (
                    <div style={{ background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', borderRadius:12, padding:'12px 16px', display:'flex', alignItems:'center', gap:10 }}>
                      <SFSymbol name="lock" size={15} color="var(--sc-primary)"/>
                      <span style={{ flex:1, fontSize:13, color:'var(--sc-text-2)' }}>Password protected</span>
                      <button onClick={()=>setShowPwField(true)} style={{ fontSize:12, fontWeight:600, color:'var(--sc-primary)', background:'transparent', border:'none', cursor:'pointer' }}>Change</button>
                      <button onClick={()=>update(id,{shareHasPassword:false})} style={{ fontSize:12, fontWeight:600, color:'var(--sc-danger)', background:'transparent', border:'none', cursor:'pointer' }}>Remove</button>
                    </div>
                  ) : (
                    <div style={{ display:'flex', gap:8 }}>
                      <input type="password" value={pwInput} onChange={e=>setPwInput(e.target.value)} placeholder="Set a password (optional)" style={{ flex:1, fontFamily:'var(--sc-font)', fontSize:13, border:'1.5px solid var(--sc-border)', borderRadius:10, padding:'10px 14px', outline:'none', background:'var(--sc-card)', color:'var(--sc-text)', boxSizing:'border-box' }}/>
                      <button onClick={()=>{ if(pwInput.trim()){ update(id,{shareHasPassword:true}); setPwInput(''); setShowPwField(false); } }} disabled={!pwInput.trim()} style={{ padding:'10px 18px', borderRadius:10, border:'none', background:pwInput.trim()?'var(--sc-primary)':'var(--sc-hover)', color:pwInput.trim()?'#fff':'var(--sc-text-4)', fontSize:13, fontWeight:600, cursor:pwInput.trim()?'pointer':'default', flexShrink:0 }}>Set</button>
                    </div>
                  )}
                </div>

                {/* Expiry */}
                <div>
                  <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase', marginBottom:10 }}>Expiry</div>
                  <div style={{ display:'flex', gap:6, flexWrap:'wrap' }}>
                    {[['No expiry',null],['7 days',7],['30 days',30],['90 days',90]].map(([l,n])=>{
                      const v = n ? (()=>{const d=new Date();d.setDate(d.getDate()+n);return d.toISOString().slice(0,10);})() : null;
                      const a = n ? item.shareExpiresAt && Math.abs(new Date(item.shareExpiresAt)-new Date(v))<864e5 : !item.shareExpiresAt;
                      return <button key={l} onClick={()=>update(id,{shareExpiresAt:v})} style={{ fontSize:12, fontWeight:700, padding:'7px 13px', borderRadius:9999, background:a?'var(--sc-primary)':'var(--sc-primary-bg)', color:a?'#fff':'var(--sc-primary)', border:'none', cursor:'pointer' }}>{l}</button>;
                    })}
                  </div>
                  {item.shareExpiresAt && <div style={{ fontSize:11.5, color:'var(--sc-text-4)', marginTop:8 }}>Expires {new Date(item.shareExpiresAt+'T12:00:00').toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'})}</div>}
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      <div style={{ padding:'18px 20px 0' }}>
        <button onClick={()=>app.setModal(null)} style={{ width:'100%', padding:'14px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:600, cursor:'pointer', boxShadow:'0 6px 20px rgba(94,77,187,0.3)' }}>Done</button>
      </div>
    </div>
  );
}

// ════════════════════════════════════════════════════════════
//  TwoFASheet — enable two-factor authentication wizard
// ════════════════════════════════════════════════════════════
function TwoFASheet() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [step, setStep] = useStateF('intro'); // intro | scan | verify | done
  const [otp, setOtp] = useStateF(Array(6).fill(''));
  const [err, setErr] = useStateF('');
  const [shake, setShake] = useStateF(false);
  const [copied, setCopied] = useStateF(false);
  const refs = [useRefF(null),useRefF(null),useRefF(null),useRefF(null),useRefF(null),useRefF(null)];
  const secret = 'JBSW Y3DP EHPK 3PXP';
  const complete = otp.every(d=>d!=='');

  useEffectF(() => { if (step==='done') { const t=setTimeout(()=>{ app.setProfile(p=>({...p, totpEnabled:true})); app.setModal('settings'); }, 1700); return ()=>clearTimeout(t); } }, [step]);

  const onChange = (i,raw) => {
    const d = raw.replace(/\D/g,'').slice(-1);
    setOtp(prev=>{ const n=[...prev]; n[i]=d; return n; });
    setErr('');
    if (d && i<5) refs[i+1].current?.focus();
  };
  const onKey = (i,e) => {
    if (e.key==='Backspace') {
      if (!otp[i] && i>0) { setOtp(prev=>{const n=[...prev];n[i-1]='';return n;}); refs[i-1].current?.focus(); }
      else setOtp(prev=>{const n=[...prev];n[i]='';return n;});
    } else if (e.key==='Enter' && complete) verify();
  };
  const verify = () => {
    // demo: accept any complete 6-digit code except 000000
    if (otp.join('')==='000000') { setErr('Invalid code — please try again.'); setOtp(Array(6).fill('')); setShake(true); setTimeout(()=>setShake(false),500); setTimeout(()=>refs[0].current?.focus(),80); return; }
    setStep('done');
  };

  return (
    <div style={{ paddingBottom:32, minHeight:step==='verify'?360:undefined }}>
      {step==='intro' && (
        <div style={{ padding:'10px 24px 24px', display:'flex', flexDirection:'column' }}>
          <div style={{ width:64, height:64, borderRadius:20, background:'linear-gradient(135deg,#F5F3FF 0%,#e0d9ff 100%)', display:'flex', alignItems:'center', justifyContent:'center', marginBottom:18 }}>
            <SFSymbol name="shield_lock" size={30} color="var(--sc-primary)" fill/>
          </div>
          <div style={{ fontSize:22, fontWeight:700, color:'var(--sc-text)', letterSpacing:'-0.02em', marginBottom:8 }}>Enable Two-Factor Auth</div>
          <div style={{ fontSize:14, color:'var(--sc-text-3)', lineHeight:1.6, marginBottom:22 }}>Add an extra layer of security. Each time you log in you'll enter a one-time code from your authenticator app in addition to your password.</div>
          <div style={{ background:'var(--sc-tinted)', borderRadius:14, padding:'14px 16px', marginBottom:24, display:'flex', flexDirection:'column', gap:12 }}>
            <div style={{ fontSize:10, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase' }}>You'll need</div>
            {[{icon:'smartphone',text:'An authenticator app (Google Authenticator, Authy, 1Password…)'},{icon:'qr_code_scanner',text:'A few seconds to scan a QR code'}].map(it=>(
              <div key={it.icon} style={{ display:'flex', alignItems:'flex-start', gap:10 }}>
                <div style={{ width:28, height:28, borderRadius:8, background:'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0, marginTop:1 }}><SFSymbol name={it.icon} size={14} color="var(--sc-primary)"/></div>
                <div style={{ fontSize:13, color:'var(--sc-text-2)', lineHeight:1.5, paddingTop:4 }}>{it.text}</div>
              </div>
            ))}
          </div>
          <button onClick={()=>setStep('scan')} style={{ width:'100%', padding:'14px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:15, fontWeight:600, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:8, boxShadow:'0 6px 20px rgba(94,77,187,0.35)' }}>Get Started <SFSymbol name="arrow_forward" size={16} color="#fff"/></button>
        </div>
      )}

      {step==='scan' && (
        <div style={{ padding:'4px 24px 24px', display:'flex', flexDirection:'column' }}>
          <div style={{ display:'flex', gap:6, marginBottom:20 }}>
            <div style={{ width:22, height:8, borderRadius:4, background:'var(--sc-primary)' }}/>
            <div style={{ width:8, height:8, borderRadius:4, background:'var(--sc-border)' }}/>
          </div>
          <div style={{ fontSize:20, fontWeight:700, color:'var(--sc-text)', marginBottom:6 }}>Scan the QR code</div>
          <div style={{ fontSize:13, color:'var(--sc-text-3)', lineHeight:1.5, marginBottom:20 }}>Open your authenticator app and scan this code, or enter the setup key manually.</div>
          <div style={{ display:'flex', justifyContent:'center', marginBottom:18 }}>
            <div style={{ padding:14, background:'#fff', border:'1.5px solid var(--sc-border)', borderRadius:16, boxShadow:'0 2px 12px rgba(94,77,187,0.08)' }}>
              <QRMock/>
            </div>
          </div>
          <div style={{ background:'var(--sc-tinted)', border:'0.5px solid var(--sc-border)', borderRadius:12, padding:'11px 14px', marginBottom:22, display:'flex', alignItems:'center', justifyContent:'space-between', gap:8 }}>
            <div>
              <div style={{ fontSize:9.5, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.06em', textTransform:'uppercase', marginBottom:3 }}>Setup key</div>
              <div style={{ fontFamily:'var(--sc-font-mono)', fontSize:13, color:'var(--sc-text)', letterSpacing:'0.08em' }}>{secret}</div>
            </div>
            <button onClick={()=>{ setCopied(true); setTimeout(()=>setCopied(false),1600); }} style={{ width:34, height:34, borderRadius:9, border:'none', background:copied?'#ecfdf5':'transparent', cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
              <SFSymbol name={copied?'check':'content_copy'} size={16} color={copied?'#10B981':'var(--sc-text-3)'}/>
            </button>
          </div>
          <div style={{ display:'flex', gap:10 }}>
            <button onClick={()=>setStep('intro')} style={{ flex:1, padding:'13px 0', background:'var(--sc-hover)', color:'var(--sc-text-2)', border:'none', borderRadius:14, fontSize:14, fontWeight:600, cursor:'pointer' }}>Back</button>
            <button onClick={()=>{ setStep('verify'); setTimeout(()=>refs[0].current?.focus(),120); }} style={{ flex:2, padding:'13px 0', background:'var(--sc-primary)', color:'#fff', border:'none', borderRadius:14, fontSize:14, fontWeight:700, cursor:'pointer', display:'flex', alignItems:'center', justifyContent:'center', gap:8, boxShadow:'0 6px 18px rgba(94,77,187,0.32)' }}>I've scanned it <SFSymbol name="arrow_forward" size={15} color="#fff"/></button>
          </div>
        </div>
      )}

      {step==='verify' && (
        <div style={{ padding:'4px 24px 24px', display:'flex', flexDirection:'column' }}>
          <div style={{ display:'flex', gap:6, marginBottom:20 }}>
            <div style={{ width:8, height:8, borderRadius:4, background:'var(--sc-border)' }}/>
            <div style={{ width:22, height:8, borderRadius:4, background:'var(--sc-primary)' }}/>
          </div>
          <div style={{ fontSize:20, fontWeight:700, color:'var(--sc-text)', marginBottom:6 }}>Confirm setup</div>
          <div style={{ fontSize:13, color:'var(--sc-text-3)', lineHeight:1.5, marginBottom:26 }}>Enter the 6-digit code from your authenticator app to confirm.</div>
          <div style={{ display:'flex', gap:8, justifyContent:'center', marginBottom:8, animation:shake?'shake 420ms ease':'none' }}>
            {otp.map((d,i)=>(
              <input key={i} ref={refs[i]} type="text" inputMode="numeric" maxLength={1} value={d}
                onChange={e=>onChange(i,e.target.value)} onKeyDown={e=>onKey(i,e)}
                style={{ width:44, height:54, textAlign:'center', fontFamily:'var(--sc-font)', fontSize:22, fontWeight:700, color:'var(--sc-text)', background:d?'var(--sc-primary-bg)':'var(--sc-tinted)', border:`2px solid ${err?'#ffdad6':d?'var(--sc-primary)':'var(--sc-border)'}`, borderRadius:12, outline:'none', caretColor:'var(--sc-primary)', transition:'all 150ms', boxSizing:'border-box' }}/>
            ))}
          </div>
          <div style={{ height:20, textAlign:'center', marginBottom:14 }}>
            {err && <span style={{ fontSize:12, color:'var(--sc-danger)' }}>{err}</span>}
          </div>
          <div style={{ display:'flex', gap:10 }}>
            <button onClick={()=>{ setStep('scan'); setOtp(Array(6).fill('')); setErr(''); }} style={{ flex:1, padding:'13px 0', background:'var(--sc-hover)', color:'var(--sc-text-2)', border:'none', borderRadius:14, fontSize:14, fontWeight:600, cursor:'pointer' }}>Back</button>
            <button onClick={verify} disabled={!complete} style={{ flex:2, padding:'13px 0', background:complete?'var(--sc-primary)':'var(--sc-hover)', color:complete?'#fff':'var(--sc-text-4)', border:'none', borderRadius:14, fontSize:14, fontWeight:700, cursor:complete?'pointer':'default', display:'flex', alignItems:'center', justifyContent:'center', gap:7, boxShadow:complete?'0 6px 18px rgba(94,77,187,0.32)':'none' }}>
              <SFSymbol name="shield_lock" size={15} color={complete?'#fff':'var(--sc-text-4)'}/>Activate 2FA</button>
          </div>
        </div>
      )}

      {step==='done' && (
        <div style={{ padding:'40px 24px', display:'flex', flexDirection:'column', alignItems:'center', gap:16 }}>
          <div style={{ width:68, height:68, borderRadius:'50%', background:'rgba(16,185,129,0.12)', display:'flex', alignItems:'center', justifyContent:'center', animation:'scIn 400ms cubic-bezier(0.34,1.56,0.64,1) both' }}>
            <SFSymbol name="check_circle" size={36} color="#10B981" fill/>
          </div>
          <div style={{ fontSize:20, fontWeight:700, color:'var(--sc-text)' }}>2FA Enabled!</div>
          <div style={{ fontSize:14, color:'var(--sc-text-3)', textAlign:'center', lineHeight:1.5 }}>Your account is now protected with two-factor authentication.</div>
        </div>
      )}
    </div>
  );
}

// Decorative QR placeholder (deterministic pattern — not a real code)
function QRMock() {
  const cells = useMemoF(() => {
    const n = 21; const g = [];
    for (let y=0;y<n;y++) for (let x=0;x<n;x++) {
      const finder = (a,b)=> a<7&&b<7 || a<7&&b>=n-7 || a>=n-7&&b<7;
      let on;
      if (finder(y,x)) { const dy=Math.min(y,Math.abs(y-(n-1))), dx=x<7?x:Math.abs(x-(n-1)); on = (dy===0||dy===6||dx===0||dx===6||(dy>=2&&dy<=4&&dx>=2&&dx<=4)); }
      else on = ((x*y+x*3+y*7) % 3 === 0);
      if (on) g.push(<rect key={`${x}-${y}`} x={x*7} y={y*7} width={7} height={7} fill="#1c1b22"/>);
    }
    return g;
  }, []);
  return <svg width="160" height="160" viewBox="0 0 147 147" style={{ display:'block' }}>{cells}</svg>;
}

// ─── Exports ──────────────────────────────────────────────────
Object.assign(window, {
  TimelinesScreen, TimelineScreen, MilestoneEditorSheet, AddTimelineSheet,
  WorkspaceSwitcherSheet, WorkspaceWizardSheet, ItemSettingsSheet, TwoFASheet,
});
