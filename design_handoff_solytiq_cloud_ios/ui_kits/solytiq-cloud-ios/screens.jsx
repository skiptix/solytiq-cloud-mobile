// Solytiq Cloud · iOS v2 — Screens
// Exports: WelcomeScreen, LoginScreen, DashboardScreen, ListScreen,
//          ScheduledScreen, FilesScreen, FolderDashboardScreen, AppShell

const { useState, useRef, useMemo } = React;

const LOGO = '../../assets/solytiq-cloud-logo.png';

// ─── WelcomeScreen ────────────────────────────────────────────
function WelcomeScreen() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [sel, setSel] = useState(null);
  const proceed = () => {
    if (sel === 'local') { app.setProfile(p => ({ ...p, mode: 'local' })); app.setScreen('dashboard'); }
    else if (sel === 'server') app.setScreen('login');
  };  const ModeCard = ({ id, icon, title, desc, badge }) => {
    const a = sel === id;
    return (
      <button onClick={() => setSel(id)} style={{
        width: '100%', textAlign: 'left',
        background: a ? '#fff' : 'rgba(255,255,255,0.55)',
        border: `1.5px solid ${a ? 'var(--sc-primary)' : 'rgba(255,255,255,0.7)'}`,
        borderRadius: 20, padding: 16, display: 'flex', alignItems: 'flex-start', gap: 14,
        cursor: 'pointer', transition: 'all 200ms',
        boxShadow: a ? '0 8px 28px rgba(94,77,187,0.22), 0 0 0 4px rgba(94,77,187,0.08)' : '0 1px 0 rgba(255,255,255,0.6) inset',
        backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
      }}>
        <div style={{ width: 46, height: 46, borderRadius: 14, flexShrink: 0, transition: 'all 200ms',
          background: a ? 'var(--sc-primary)' : 'var(--sc-primary-bg)',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <SFSymbol name={icon} size={23} color={a ? '#fff' : 'var(--sc-primary)'} fill />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <span style={{ fontSize: 16, fontWeight: 700, color: 'var(--sc-text)' }}>{title}</span>
            {badge && <span style={{ fontSize: 9, fontWeight: 700, color: '#10B981', background: 'rgba(16,185,129,0.12)', borderRadius: 9999, padding: '2px 7px', textTransform: 'uppercase', letterSpacing: '0.04em' }}>{badge}</span>}
          </div>
          <div style={{ fontSize: 13, color: 'var(--sc-text-3)', lineHeight: 1.45 }}>{desc}</div>
        </div>
        <div style={{ width: 22, height: 22, borderRadius: '50%', flexShrink: 0, marginTop: 2, transition: 'all 200ms',
          border: `1.5px solid ${a ? 'var(--sc-primary)' : '#d6d0e0'}`,
          background: a ? 'var(--sc-primary)' : 'transparent',
          display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {a && <svg width="11" height="9" viewBox="0 0 12 10" fill="none"><path d="M1 5l3 3 7-7" stroke="white" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>}
        </div>
      </button>
    );
  };
  return (
    <div style={{ height: '100%', background: 'linear-gradient(160deg,#ede9ff 0%,#fdf8ff 50%,#fff0f9 100%)', padding: '32px 24px 28px', display: 'flex', flexDirection: 'column', gap: 24, overflowY: 'auto' }}>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14, animation:'heroIn 600ms cubic-bezier(0.34,1.2,0.64,1) both' }}>
        <img src={LOGO} alt="Solytiq Cloud" style={{ width: 80, height: 80, borderRadius: 22, objectFit: 'cover', boxShadow: '0 16px 48px rgba(94,77,187,0.38)', animation:'springScale 550ms cubic-bezier(0.34,1.56,0.64,1) 80ms both' }} />
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 26, fontWeight: 700, letterSpacing: '-0.025em', color: 'var(--sc-text)' }}>Solytiq Cloud</div>
          <div style={{ fontSize: 13.5, color: 'var(--sc-text-3)', marginTop: 5, lineHeight: 1.5 }}>Your self-hosted task manager.</div>
        </div>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        <div style={{animation:'springUp 420ms cubic-bezier(0.34,1.2,0.64,1) 180ms both'}}>
          <ModeCard id="local" icon="smartphone" title="On This Phone" badge="Private" desc="Tasks stay on device. No account or internet required." />
        </div>
        <div style={{animation:'springUp 420ms cubic-bezier(0.34,1.2,0.64,1) 270ms both'}}>
          <ModeCard id="server" icon="cloud" title="Connect to Server" desc="Sign in to your self-hosted Solytiq Cloud instance. Sync across devices." />
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <button onClick={proceed} disabled={!sel} style={{
        width: '100%', padding: '15px 0',
        background: sel ? 'var(--sc-primary)' : '#d6d0e0', color: '#fff',
        fontSize: 15.5, fontWeight: 600, border: 'none', borderRadius: 16, cursor: sel ? 'pointer' : 'not-allowed',
        boxShadow: sel ? '0 10px 28px rgba(94,77,187,0.38)' : 'none',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7, transition: 'all 220ms',
      }}>
        Continue {sel && <SFSymbol name="arrow_forward" size={16} color="#fff" />}
      </button>
      <div style={{ fontSize: 11, color: 'var(--sc-text-4)', textAlign: 'center', lineHeight: 1.5 }}>You can switch modes anytime from Settings.</div>
    </div>
  );
}

// ─── LoginScreen ──────────────────────────────────────────────
function LoginScreen() {
  const app = window.useApp();
  const { SFSymbol } = window;
  const [step, setStep] = useState(0);
  const [url,  setUrl]  = useState('https://cloud.solytiq.app');
  const [user, setUser] = useState('alex_admin');
  const [pw,   setPw]   = useState('');
  const [showPw, setShowPw] = useState(false);
  const [shake, setShake] = useState(false);
  const inputRef = useRef(null);

  useEffect(() => {
    const t = setTimeout(() => inputRef.current?.focus({ preventScroll: true }), 200);
    return () => clearTimeout(t);
  }, [step]);

  const STEPS = [
    { icon: 'dns',    title: 'Server address',  hint: 'Enter the URL of your self-hosted Solytiq Cloud instance.' },
    { icon: 'person', title: 'Your username',    hint: 'Enter the username you use to log in.' },
    { icon: 'lock',   title: 'Password',         hint: 'Enter your password. It never leaves this device.' },
  ];

  const values = [url, user, pw];
  const canNext = values[step].trim().length > 0;

  const next = () => {
    if (!canNext) { setShake(true); setTimeout(() => setShake(false), 500); return; }
    if (step < 2) { setStep(s => s + 1); }
    else {
      app.setProfile(p => ({ ...p, mode: 'server', serverUrl: url, username: user }));
      app.setScreen('dashboard');
    }
  };

  const handleKey = e => { if (e.key === 'Enter') next(); };

  return (
    <div style={{ height: '100%', background: 'linear-gradient(160deg,#ede9ff 0%,#fdf8ff 55%,#fff0f9 100%)',
      display: 'flex', flexDirection: 'column', overflowY: 'auto' }}>

      {/* Back button */}
      <div style={{ padding: '20px 24px 0', flexShrink: 0 }}>
        <button onClick={() => step > 0 ? setStep(s => s - 1) : app.setScreen('welcome')}
          style={{ display: 'flex', alignItems: 'center', gap: 3, background: 'transparent', border: 'none',
            cursor: 'pointer', color: 'var(--sc-primary)', padding: '4px 0', fontFamily: 'var(--sc-font)' }}>
          <SFSymbol name="chevron_left" size={22} color="var(--sc-primary)" weight={500} />
          <span style={{ fontSize: 16 }}>{step > 0 ? 'Back' : 'Back'}</span>
        </button>
      </div>

      {/* Logo + branding */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, padding: '20px 24px 0', flexShrink: 0 }}>
        <img src={LOGO} alt="Solytiq Cloud" style={{ width: 56, height: 56, borderRadius: 16, objectFit: 'cover', boxShadow: '0 10px 28px rgba(94,77,187,0.30)' }} />
      </div>

      {/* Step progress */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, padding: '20px 0 0', flexShrink: 0 }}>
        {STEPS.map((_, i) => (
          <div key={i} style={{
            height: 5, borderRadius: 9999, transition: 'all 300ms cubic-bezier(0.34,1.2,0.64,1)',
            width: i === step ? 24 : 6,
            background: i <= step ? 'var(--sc-primary)' : 'var(--sc-border)',
            opacity: i > step ? 0.35 : 1,
          }} />
        ))}
      </div>

      {/* Step card */}
      <div style={{ flex: 1, padding: '16px 24px 32px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{
          background: 'rgba(255,255,255,0.72)', border: '0.5px solid rgba(255,255,255,0.85)',
          borderRadius: 24, padding: '28px 22px 24px', display: 'flex', flexDirection: 'column', gap: 22,
          backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
          boxShadow: '0 12px 40px rgba(94,77,187,0.12)',
          animation: shake ? 'shake 420ms ease' : 'fadeBlur 240ms ease both',
          key: step,
        }}>
          {/* Step header */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
            <div style={{ width: 48, height: 48, borderRadius: 15, background: 'var(--sc-primary-bg)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
              border: '1px solid var(--sc-primary-bg-2)' }}>
              <SFSymbol name={STEPS[step].icon} size={23} color="var(--sc-primary)" fill />
            </div>
            <div>
              <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-primary)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 3 }}>
                Step {step + 1} of {STEPS.length}
              </div>
              <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: '-0.02em', color: 'var(--sc-text)', lineHeight: 1.1 }}>
                {STEPS[step].title}
              </div>
            </div>
          </div>

          <div style={{ fontSize: 13, color: 'var(--sc-text-3)', lineHeight: 1.55, marginTop: -8 }}>
            {STEPS[step].hint}
          </div>

          {/* Input */}
          {step === 0 && (
            <div style={{ background: 'var(--sc-tinted)', borderRadius: 14, padding: '13px 16px',
              border: '0.5px solid var(--sc-border)' }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 8 }}>Server URL</div>
              <input ref={inputRef} value={url} onChange={e => setUrl(e.target.value)} onKeyDown={handleKey}
                placeholder="https://cloud.example.com" spellCheck={false}
                style={{ width: '100%', fontFamily: 'var(--sc-font-mono)', fontSize: 14, color: 'var(--sc-text)',
                  background: 'transparent', border: 'none', outline: 'none', boxSizing: 'border-box' }} />
            </div>
          )}
          {step === 1 && (
            <div style={{ background: 'var(--sc-tinted)', borderRadius: 14, padding: '13px 16px',
              border: '0.5px solid var(--sc-border)' }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase', marginBottom: 8 }}>Username</div>
              <input ref={inputRef} value={user} onChange={e => setUser(e.target.value)} onKeyDown={handleKey}
                placeholder="your_username" spellCheck={false} autoCapitalize="none"
                style={{ width: '100%', fontFamily: 'var(--sc-font)', fontSize: 16, fontWeight: 600, color: 'var(--sc-text)',
                  background: 'transparent', border: 'none', outline: 'none', boxSizing: 'border-box' }} />
            </div>
          )}
          {step === 2 && (
            <div style={{ background: 'var(--sc-tinted)', borderRadius: 14, padding: '13px 16px',
              border: '0.5px solid var(--sc-border)' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.08em', textTransform: 'uppercase' }}>Password</div>
                <button onClick={() => setShowPw(s => !s)}
                  style={{ fontSize: 12, fontWeight: 700, color: 'var(--sc-primary)', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'var(--sc-font)', padding: 0 }}>
                  {showPw ? 'Hide' : 'Show'}
                </button>
              </div>
              <input ref={inputRef} type={showPw ? 'text' : 'password'} value={pw} onChange={e => setPw(e.target.value)} onKeyDown={handleKey}
                placeholder="••••••••"
                style={{ width: '100%', fontFamily: 'var(--sc-font)', fontSize: 18, color: 'var(--sc-text)',
                  background: 'transparent', border: 'none', outline: 'none', boxSizing: 'border-box', letterSpacing: showPw ? 0 : '0.12em' }} />
            </div>
          )}

          {/* Summary of entered info on step 2 */}
          {step === 2 && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
              {[{ icon: 'dns', label: url }, { icon: 'person', label: user }].map((row, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <SFSymbol name={row.icon} size={13} color="var(--sc-text-4)" />
                  <span style={{ fontSize: 12.5, color: 'var(--sc-text-3)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.label}</span>
                  <button onClick={() => setStep(i)} style={{ fontSize: 11, fontWeight: 700, color: 'var(--sc-primary)', background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: 'var(--sc-font)', flexShrink: 0, padding: 0 }}>Edit</button>
                </div>
              ))}
            </div>
          )}

          {/* CTA */}
          <button onClick={next}
            style={{ width: '100%', padding: '15px 0', background: canNext ? 'var(--sc-primary)' : 'var(--sc-hover)',
              color: canNext ? '#fff' : 'var(--sc-text-4)', fontFamily: 'var(--sc-font)',
              fontSize: 15, fontWeight: 700, border: 'none', borderRadius: 14, cursor: canNext ? 'pointer' : 'default',
              boxShadow: canNext ? '0 8px 24px rgba(94,77,187,0.35)' : 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, transition: 'all 200ms' }}>
            {step < 2
              ? <><span>Continue</span><SFSymbol name="arrow_forward" size={15} color={canNext ? '#fff' : 'var(--sc-text-4)'} /></>
              : <><SFSymbol name="lock" size={15} color="#fff" fill /><span>Sign In</span></>}
          </button>
        </div>

        <div style={{ fontSize: 11, color: 'var(--sc-text-4)', textAlign: 'center', lineHeight: 1.6 }}>
          {step === 0 && 'Your server address looks like https://cloud.yourdomain.com'}
          {step === 1 && 'Use the same username you set up on your server.'}
          {step === 2 && 'We never store your password. Sessions stay on this device.'}
        </div>
      </div>
    </div>
  );
}

// ─── DashboardScreen ──────────────────────────────────────────
function DashboardScreen() {
  const app = window.useApp();
  const { NavHeader, TaskRow, QuickAdd, StatCard, FloatingTabBar, SolFloatBtn, Card, SectionHeader, EmptyRow } = window;
  const [scrollY, setScrollY] = useState(0);
  const allTasks = useMemo(() => [
    ...app.tasks,
    ...app.lists.flatMap(l => l.sections.flatMap(s => s.tasks.map(t => ({ ...t, _source: 'list', _listId: l.id, _listName: l.name })))),
  ], [app.tasks, app.lists]);

  const open = allTasks.filter(t => !t.checked);
  const done = allTasks.filter(t => t.checked);
  const today = window.todayIso();
  const dueToday = open.filter(t => t.deadline === today);
  const overdue = open.filter(t => t.deadline && t.deadline < today);
  const pct = allTasks.length ? Math.round((done.length / allTasks.length) * 100) : 0;
  const dateStr = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }).toUpperCase();

  const openTask = t => { app.setSelectedTaskId(t.id); app.setModal('edit-task'); };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--sc-page)', position: 'relative', overflow: 'hidden' }}>
      <div className="sc-scroll" onScroll={e => setScrollY(e.currentTarget.scrollTop)}
        style={{ flex: 1, minHeight: 0, overflowY: 'auto', paddingBottom: 96 }}>
        <NavHeader title="Dashboard" eyebrow={dateStr}
          subtitle={dueToday.length > 0 ? `${dueToday.length} task${dueToday.length > 1 ? 's' : ''} due today${overdue.length > 0 ? ` · ${overdue.length} overdue` : ''}.` : 'No deadlines today — you\'re all clear.'}
          scrollY={scrollY} leading={null} trailing={null} />

        {overdue.length > 0 && (
          <div style={{ margin: '0 22px 14px' }}>
            <div onClick={()=>{app.setTaskFilter('overdue');app.setModal('task-filter');}}
              style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', background: '#ffefeb', border: '0.5px solid #ffdad6', borderRadius: 14, cursor:'pointer' }}
              onMouseEnter={e=>e.currentTarget.style.background='#ffdad6'}
              onMouseLeave={e=>e.currentTarget.style.background='#ffefeb'}>
              <window.SFSymbol name="warning" size={16} color="#ba1a1a" fill />
              <span style={{ flex: 1, fontSize: 13, fontWeight: 600, color: '#8b1414' }}>{overdue.length} task{overdue.length > 1 ? 's' : ''} overdue — tap to view</span>
              <window.SFSymbol name="chevron_right" size={14} color="#ba1a1a" />
            </div>
          </div>
        )}

        <div style={{ padding: '0 22px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 16 }}>
          <StatCard label="Open Tasks" value={open.length} sub={`${allTasks.length} total`} icon="inventory_2" accent="#5e4dbb" index={0} onClick={()=>{app.setTaskFilter('open');app.setModal('task-filter');}}/>
          <StatCard label="Completed" value={done.length} sub={pct > 0 ? `${pct}%` : 'Start!'} icon="check_circle" accent="#10B981" index={1} onClick={()=>{app.setTaskFilter('completed');app.setModal('task-filter');}}/>
          <StatCard label="Due Today" value={dueToday.length} sub={dueToday.length > 0 ? 'Focus' : 'Clear'} icon="today" accent="#ea580c" index={2} onClick={()=>{app.setTaskFilter('today');app.setModal('task-filter');}}/>
          <StatCard label="This Week" value={open.filter(t => { const d = t.deadline; return d && d > today && d <= (() => { const x = new Date(); x.setDate(x.getDate() + 7); return x.toISOString().slice(0, 10); })(); }).length} sub="Upcoming" icon="calendar_month" accent="#1D4ED8" index={3} onClick={()=>{app.setTaskFilter('week');app.setModal('task-filter');}}/>
        </div>

        <div style={{ margin: '0 22px 20px', background: 'var(--sc-card)', border: '0.5px solid var(--sc-border)', borderRadius: 16, padding: 14, animation:'springUp 350ms cubic-bezier(0.34,1.2,0.64,1) 280ms both' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--sc-text-2)' }}>Progress this week</div>
            <div className="sc-mono" style={{ fontSize: 11, color: 'var(--sc-text-3)' }}>{done.length} done · {open.length} open</div>
          </div>
          <div style={{ height: 8, borderRadius: 9999, background: '#ebe6f0', overflow: 'hidden' }}>
            <div style={{ width: `${pct}%`, height: '100%', background: pct === 100 ? '#10B981' : 'linear-gradient(90deg,#9d8dff,#5e4dbb)', borderRadius: 9999, animation:'progressFill 700ms cubic-bezier(0.34,1.2,0.64,1) 500ms both', transition:'width 400ms' }} />
          </div>
        </div>

        <SectionHeader title="Due Today" right={<span style={{ fontSize: 12, fontWeight: 700, color: '#ea580c', background: '#fff7ed', borderRadius: 9999, padding: '2px 9px' }}>{dueToday.length}</span>} />
        <Card>
          {dueToday.length === 0
            ? <EmptyRow text="Nothing due today. 🌿" />
            : dueToday.map((t, i) => <TaskRow key={t.id} task={t} divider={i < dueToday.length - 1} onClick={() => openTask(t)} index={i}/>)}
        </Card>

        <div style={{ padding: '16px 22px 0' }}>
          <QuickAdd onAdd={p => app.addTask({ ...p, deadline: today, _source: 'dash' })} />
        </div>

        <SectionHeader title="All Todos" right={<span style={{ fontSize: 11, color: 'var(--sc-text-4)' }}>{open.length} open</span>} />
        <Card>
          {open.length === 0
            ? <EmptyRow text="No open tasks. Enjoy your day!" />
            : open.slice(0, 7).map((t, i) => <TaskRow key={`${t._listId||'d'}-${t.id}`} task={t} divider={i < Math.min(open.length, 7) - 1} onClick={() => openTask(t)} listBadge={t._listName} index={i}/>)}
          {open.length > 7 && (
            <button onClick={() => { app.setTaskFilter('open'); app.setModal('task-filter'); }}
              style={{ width: '100%', padding: '12px 16px', textAlign: 'center', borderTop: '0.5px solid var(--sc-separator)', background: 'transparent', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, transition: 'background 150ms' }}
              onMouseEnter={e => e.currentTarget.style.background = 'var(--sc-hover)'}
              onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--sc-primary)' }}>+{open.length - 7} more tasks</span>
              <window.SFSymbol name="chevron_right" size={13} color="var(--sc-primary)" />
            </button>
          )}
        </Card>
      </div>
    </div>
  );
}

// ─── ListScreen ───────────────────────────────────────────────
function ListScreen() {
  const app = window.useApp();
  const { NavHeader, TaskRow, QuickAdd, FloatingTabBar, SolFloatBtn, Card } = window;
  const [scrollY, setScrollY] = useState(0);
  const [menu, setMenu] = useState(false);
  const list = app.lists.find(l => l.id === app.currentListId) || app.lists[0];
  if (!list) return null;
  const connected = app.profile.mode === 'server';

  const allTasks = list.sections.flatMap(s => s.tasks);
  const done = allTasks.filter(t => t.checked).length;
  const total = allTasks.length;
  const pct = total ? Math.round((done / total) * 100) : 0;
  const openTask = t => { app.setSelectedTaskId(t.id); app.setModal('edit-task'); };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--sc-page)', position: 'relative', overflow: 'hidden' }}>
      {menu && <div onClick={() => setMenu(false)} style={{ position: 'absolute', inset: 0, zIndex: 18 }} />}
      <div className="sc-scroll" onScroll={e => setScrollY(e.currentTarget.scrollTop)}
        style={{ flex: 1, minHeight: 0, overflowY: 'auto', paddingBottom: 96 }}>
        <NavHeader title={list.name} large={false} scrollY={1}
          leading={
            <button onClick={() => app.setScreen('lists')} style={{ display: 'flex', alignItems: 'center', gap: 2, background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--sc-primary)', padding: '6px 4px' }}>
              <window.SFSymbol name="chevron_left" size={22} color="var(--sc-primary)" weight={500} />
              <span style={{ fontFamily: 'var(--sc-font)', fontSize: 16 }}>Lists</span>
            </button>
          }
          trailing={
            <div style={{ position: 'relative' }}>
              <button onClick={() => setMenu(m => !m)} style={{ width: 32, height: 32, borderRadius: '50%', background: menu ? 'var(--sc-primary)' : 'var(--sc-primary-bg)', border: 'none', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
                <window.SFSymbol name="more_horiz" size={18} color={menu ? '#fff' : 'var(--sc-primary)'} />
              </button>
              {menu && (
                <div style={{ position: 'absolute', right: 0, top: 40, zIndex: 60, background: 'var(--sc-card)', borderRadius: 16, border: '0.5px solid var(--sc-border)', boxShadow: '0 8px 32px rgba(28,27,34,0.16)', minWidth: 180, overflow: 'hidden', animation: 'popIn 180ms cubic-bezier(0.34,1.56,0.64,1) both' }}>
                  {[{ icon: 'tune', label: 'List Settings', fn:()=>{ setMenu(false); app.setModalData({kind:'list',id:list.id}); app.setModal('item-settings'); } }, ...(connected ? [{ icon: 'ios_share', label: 'Share via Link', fn:()=>{ setMenu(false); app.setModalData({kind:'list',id:list.id,tab:'share'}); app.setModal('item-settings'); } }] : []), { icon: 'delete', label: 'Delete List', danger: true, fn:()=>setMenu(false) }].map((item, i) => (
                    <button key={i} onClick={item.fn} style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '13px 16px', background: 'transparent', border: 'none', borderTop: i > 0 ? '0.5px solid var(--sc-separator)' : 'none', cursor: 'pointer', fontFamily: 'var(--sc-font)', fontSize: 14.5, fontWeight: 500, color: item.danger ? 'var(--sc-danger)' : 'var(--sc-text)', textAlign: 'left' }}>
                      <window.SFSymbol name={item.icon} size={16} color={item.danger ? 'var(--sc-danger)' : 'var(--sc-primary)'} />
                      {item.label}
                    </button>
                  ))}
                </div>
              )}
            </div>
          } />

        <div style={{ margin: '10px 22px 18px', padding: 18, background: `linear-gradient(135deg, ${list.colorBg || '#F5F3FF'} 0%, #fff 80%)`, border: '0.5px solid var(--sc-border)', borderRadius: 24, animation:'springUp 400ms cubic-bezier(0.34,1.2,0.64,1) 60ms both' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div>
              <div style={{ fontSize: 36, lineHeight: 1, marginBottom: 8 }}>{list.emoji}</div>
              <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: '-0.015em', color: 'var(--sc-text)' }}>{list.name}</div>
              {list.subtitle && <div style={{ fontSize: 13, color: 'var(--sc-text-3)', marginTop: 3 }}>{list.subtitle}</div>}
              <div style={{ display:'flex', alignItems:'center', gap:6, marginTop:8, flexWrap:'wrap' }}>
                {list.parentTaskId && <span style={{ display:'inline-flex', alignItems:'center', gap:3, fontSize:10, fontWeight:700, color:'#0d9488', background:'rgba(13,148,136,0.10)', borderRadius:9999, padding:'2px 8px' }}><window.SFSymbol name="account_tree" size={11} color="#0d9488"/>Sublist</span>}
                {list.isPublic && connected && <span style={{ display:'inline-flex', alignItems:'center', gap:3, fontSize:10, fontWeight:700, color:'var(--sc-text-3)', background:'var(--sc-hover)', borderRadius:9999, padding:'2px 8px' }}><window.SFSymbol name="public" size={11} color="var(--sc-text-3)"/>Public</span>}
                {list.shareEnabled && connected && <span style={{ display:'inline-flex', alignItems:'center', gap:3, fontSize:10, fontWeight:700, color:'var(--sc-primary)', background:'var(--sc-primary-bg)', borderRadius:9999, padding:'2px 8px' }}><window.SFSymbol name="link" size={11} color="var(--sc-primary)"/>Shared</span>}
              </div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div className="sc-mono" style={{ fontSize: 36, fontWeight: 700, color: list.color || 'var(--sc-primary)', letterSpacing: '-0.03em', lineHeight: 1 }}>{pct}%</div>
              <div style={{ fontSize: 10, color: 'var(--sc-text-3)', marginTop: 4, fontWeight: 700, letterSpacing: '0.07em' }}>COMPLETE</div>
            </div>
          </div>
          <div style={{ height: 6, borderRadius: 9999, background: '#ebe6f0', overflow: 'hidden', marginTop: 16 }}>
            <div style={{ width: `${pct}%`, height: '100%', background: list.color || 'var(--sc-primary)', transition: 'width 400ms', animation:'progressFill 600ms cubic-bezier(0.34,1.2,0.64,1) 300ms both' }} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, fontSize: 11, color: 'var(--sc-text-3)' }}>
            <span className="sc-mono">{done} completed</span><span className="sc-mono">{total - done} remaining</span>
          </div>
        </div>

        {list.sections.map(sec => (
          <div key={sec.id}>
            <div style={{ padding: '14px 26px 6px', display: 'flex', alignItems: 'center', gap: 7 }}>
              {sec.emoji && <span style={{ fontSize: 13 }}>{sec.emoji}</span>}
              <span style={{ fontSize: 10, fontWeight: 700, letterSpacing: '0.09em', color: 'var(--sc-text-3)', textTransform: 'uppercase' }}>{sec.label}</span>
              <div style={{ flex: 1, height: 0.5, background: 'var(--sc-separator)', marginLeft: 6 }} />
              <span style={{ fontSize: 11, color: 'var(--sc-text-4)' }}>{sec.tasks.length}</span>
            </div>
            <Card>
              {sec.tasks.length === 0
                ? <window.EmptyRow text="No tasks yet" />
                : sec.tasks.map((t, i) => <TaskRow key={t.id} task={t} divider={i < sec.tasks.length - 1} onClick={() => openTask(t)} index={i}/>)}
            </Card>
          </div>
        ))}

        <div style={{ padding: '14px 22px 0' }}>
          <QuickAdd placeholder="Add to list…" onAdd={p => app.addTask({ ...p, _listId: list.id, _sectionId: list.sections[0]?.id, _source: 'list' })} />
        </div>
      </div>
    </div>
  );
}

// ─── ScheduledScreen ──────────────────────────────────────────
function ScheduledScreen() {
  const app = window.useApp();
  const { NavHeader, TaskRow, FloatingTabBar, SolFloatBtn, Card, SectionHeader, EmptyRow } = window;
  const [scrollY, setScrollY] = useState(0);
  const [monthOffset, setMonthOffset] = useState(0);
  const now = new Date();
  const view = new Date(now.getFullYear(), now.getMonth() + monthOffset, 1);
  const monthName = view.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
  const daysInMonth = new Date(view.getFullYear(), view.getMonth() + 1, 0).getDate();
  const firstDay = view.getDay();
  const [selDay, setSelDay] = useState(now.getDate());
  const [dragTaskId, setDragTaskId] = useState(null);
  const dragTaskIdRef = useRef(null);
  const [dragOverDay, setDragOverDay] = useState(null);
  const [dropFlash, setDropFlash] = useState(null);

  const allTasks = useMemo(() => [
    ...app.tasks,
    ...app.lists.flatMap(l => l.sections.flatMap(s => s.tasks.map(t => ({ ...t, _listName: l.name })))),
  ], [app.tasks, app.lists]);

  const unscheduled = useMemo(() => allTasks.filter(t => !t.deadline && !t.checked), [allTasks]);

  const byDay = useMemo(() => {
    const m = {};
    allTasks.forEach(t => {
      if (!t.deadline) return;
      const d = new Date(t.deadline + 'T12:00:00');
      if (d.getMonth() !== view.getMonth() || d.getFullYear() !== view.getFullYear()) return;
      const day = d.getDate();
      (m[day] = m[day] || []).push(t);
    });
    return m;
  }, [allTasks, view]);

  const selTasks = byDay[selDay] || [];
  const cells = [];
  for (let i = 0; i < firstDay; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  const PC = { High: '#ea580c', Medium: '#f59e0b', Low: '#787584' };

  const openTask = t => { app.setSelectedTaskId(t.id); app.setModal('edit-task'); };

  const dropOnDay = (d) => {
    const id = dragTaskIdRef.current;
    if (!id) return;
    const y = view.getFullYear();
    const m = String(view.getMonth() + 1).padStart(2, '0');
    const day = String(d).padStart(2, '0');
    app.updateTask(id, { deadline: `${y}-${m}-${day}` });
    setDropFlash(d);
    setTimeout(() => setDropFlash(null), 600);
    setSelDay(d);
    dragTaskIdRef.current = null;
    setDragTaskId(null);
    setDragOverDay(null);
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--sc-page)', position: 'relative', overflow: 'hidden' }}>
      <div className="sc-scroll" onScroll={e => setScrollY(e.currentTarget.scrollTop)}
        style={{ flex: 1, minHeight: 0, overflowY: 'auto', paddingBottom: 96 }}>
        <NavHeader title="Scheduled" subtitle="Drag unscheduled tasks onto a date to plan your week." scrollY={scrollY}
          trailing={<button onClick={() => { setMonthOffset(0); setSelDay(now.getDate()); }} style={{ fontSize: 13, fontWeight: 600, color: 'var(--sc-primary)', background: 'var(--sc-primary-bg)', border: 'none', borderRadius: 9999, padding: '6px 13px', cursor: 'pointer', marginRight: 36 }}>Today</button>} />

        <div style={{ padding: '0 18px 10px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 14, animation: 'springUp 380ms cubic-bezier(0.34,1.2,0.64,1) 80ms both' }}>
          <button onClick={() => setMonthOffset(m => m - 1)} style={{ width: 34, height: 34, borderRadius: 11, background: 'var(--sc-card)', border: '0.5px solid var(--sc-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <window.SFSymbol name="chevron_left" size={18} color="var(--sc-text-2)" />
          </button>
          <div style={{ fontSize: 18, fontWeight: 700, minWidth: 160, textAlign: 'center', color: 'var(--sc-text)' }}>{monthName}</div>
          <button onClick={() => setMonthOffset(m => m + 1)} style={{ width: 34, height: 34, borderRadius: 11, background: 'var(--sc-card)', border: '0.5px solid var(--sc-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <window.SFSymbol name="chevron_right" size={18} color="var(--sc-text-2)" />
          </button>
        </div>

        {/* Calendar grid */}
        <div style={{ padding: '0 14px 16px', animation: 'fadeBlur 340ms cubic-bezier(0.34,1.2,0.64,1) 140ms both' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 3, marginBottom: 4 }}>
            {['S','M','T','W','T','F','S'].map((d, i) => (
              <div key={i} style={{ textAlign: 'center', fontSize: 10, fontWeight: 700, color: 'var(--sc-text-4)', letterSpacing: '0.06em', padding: '4px 0',
                animation: `fadeUp 200ms ease ${120 + i * 18}ms both` }}>{d}</div>
            ))}
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 3 }}>
            {cells.map((d, i) => {
              if (!d) return <div key={i} />;
              const isToday = monthOffset === 0 && d === now.getDate();
              const isSel = d === selDay;
              const isDragOver = dragOverDay === d;
              const isFlash = dropFlash === d;
              const dots = (byDay[d] || []).slice(0, 3);
              const cellDelay = 160 + i * 14;
              return (
                <div key={i}
                  onClick={() => setSelDay(d)}
                  onDragOver={e => { e.preventDefault(); e.dataTransfer.dropEffect = 'move'; setDragOverDay(d); }}
                  onDragLeave={e => { e.preventDefault(); setDragOverDay(null); }}
                  onDrop={e => { e.preventDefault(); if (!dragTaskIdRef.current) { const id = parseInt(e.dataTransfer.getData('text/plain'),10); if (id) dragTaskIdRef.current = id; } dropOnDay(d); }}
                  style={{
                    aspectRatio: '1 / 1', display: 'flex', flexDirection: 'column',
                    alignItems: 'center', justifyContent: 'center', gap: 2, borderRadius: 12,
                    cursor: dragTaskId ? 'copy' : 'pointer',
                    background: isFlash ? '#10B981' : isDragOver ? 'var(--sc-primary)' : isSel ? 'var(--sc-primary)' : isToday ? 'var(--sc-primary-bg-2)' : 'transparent',
                    color: isDragOver || isSel || isFlash ? '#fff' : isToday ? 'var(--sc-primary)' : 'var(--sc-text)',
                    border: isDragOver ? '2px dashed rgba(255,255,255,0.6)' : '2px solid transparent',
                    transition: 'background 140ms ease, transform 140ms ease, box-shadow 140ms ease',
                    transform: isDragOver ? 'scale(1.08)' : 'scale(1)',
                    boxShadow: isDragOver ? '0 4px 14px rgba(94,77,187,0.35)' : 'none',
                    animation: `scIn 280ms cubic-bezier(0.34,1.56,0.64,1) ${cellDelay}ms both`,
                  }}>
                  <span className="sc-mono" style={{ fontSize: 13, fontWeight: isToday || isSel || isDragOver ? 700 : 500 }}>{d}</span>
                  <div style={{ display: 'flex', gap: 2, height: 5 }}>
                    {dots.map((t, j) => (
                      <div key={j} style={{ width: 4, height: 4, borderRadius: '50%', background: isSel || isDragOver ? 'rgba(255,255,255,0.7)' : (PC[t.priority] || 'var(--sc-primary)') }} />
                    ))}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Drag hint */}
        {dragTaskId && (
          <div style={{ margin: '0 18px 12px', padding: '9px 14px', background: 'var(--sc-primary-bg)', border: '1px dashed var(--sc-primary)', borderRadius: 12, display: 'flex', alignItems: 'center', gap: 8, animation: 'pulse 1s ease-in-out infinite' }}>
            <window.SFSymbol name="calendar_month" size={14} color="var(--sc-primary)" />
            <span style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--sc-primary)' }}>Drop on a date to schedule</span>
          </div>
        )}

        {/* Selected day tasks */}
        <div style={{ animation: 'springUp 360ms cubic-bezier(0.34,1.2,0.64,1) 320ms both' }}>
        <SectionHeader title={`${monthOffset === 0 && selDay === now.getDate() ? 'Today · ' : ''}${view.toLocaleDateString('en-US', { weekday: 'long', month: 'long' }).toUpperCase()} ${selDay}`} right={<span style={{ fontSize: 12, color: 'var(--sc-text-4)' }}>{selTasks.length} task{selTasks.length !== 1 ? 's' : ''}</span>} />
        <Card>
          {selTasks.length === 0
            ? <EmptyRow text="No tasks scheduled for this day." />
            : selTasks.map((t, i) => <TaskRow key={`${t._listId || 'd'}-${t.id}`} task={t} divider={i < selTasks.length - 1} listBadge={t._listName} onClick={() => openTask(t)} index={i}/>)}
        </Card>
        </div>

        {/* Unscheduled section */}
        <div style={{ animation: 'springUp 360ms cubic-bezier(0.34,1.2,0.64,1) 420ms both' }}>
        <SectionHeader
          title="Unscheduled"
          right={<span style={{ fontSize: 12, fontWeight: 700, color: 'var(--sc-text-4)', background: 'var(--sc-hover)', borderRadius: 9999, padding: '2px 9px' }}>{unscheduled.length}</span>}
        />
        {unscheduled.length === 0 ? (
          <Card><EmptyRow text="All tasks have a deadline. 🎉" /></Card>
        ) : (
          <div>
            {/* Drag instruction */}
            <div style={{ margin: '0 18px 8px', padding: '8px 12px', background: 'var(--sc-tinted)', border: '0.5px solid var(--sc-border)', borderRadius: 10, display: 'flex', alignItems: 'center', gap: 7 }}>
              <window.SFSymbol name="drag_indicator" size={13} color="var(--sc-text-4)" />
              <span style={{ fontSize: 11.5, color: 'var(--sc-text-4)' }}>Drag a task onto a calendar date to schedule it</span>
            </div>
            <Card>
              {unscheduled.map((t, i) => {
                const BC = { Work:{bg:'#fff5d6',fg:'#6e5e0d'}, Personal:{bg:'#F5F3FF',fg:'#5e4dbb'}, Urgent:{bg:'#ffdad6',fg:'#ba1a1a'}, Tip:{bg:'#eff6ff',fg:'#1D4ED8'} };
                const bc = t.badge ? BC[t.badge] : null;
                const isDragging = dragTaskId === t.id;
                return (
                  <div key={`u-${t.id}`}
                    draggable={true}
                    onDragStart={e => { dragTaskIdRef.current = t.id; setDragTaskId(t.id); e.dataTransfer.setData('text/plain', String(t.id)); e.dataTransfer.effectAllowed = 'move'; }}
                    onDragEnd={() => { dragTaskIdRef.current = null; setDragTaskId(null); setDragOverDay(null); }}
                    onClick={() => openTask(t)}
                    style={{
                      display: 'flex', alignItems: 'center', gap: 11,
                      padding: '11px 16px',
                      borderBottom: i < unscheduled.length - 1 ? '0.5px solid var(--sc-separator)' : 'none',
                      cursor: 'grab', userSelect: 'none',
                      opacity: isDragging ? 0.4 : 1,
                      background: isDragging ? 'var(--sc-primary-bg)' : 'transparent',
                      transition: 'opacity 150ms, background 150ms',
                    }}
                    onMouseEnter={e => { if (!isDragging) e.currentTarget.style.background = 'var(--sc-hover)'; }}
                    onMouseLeave={e => { if (!isDragging) e.currentTarget.style.background = 'transparent'; }}
                  >
                    {/* Drag handle */}
                    <window.SFSymbol name="drag_indicator" size={16} color="var(--sc-text-4)" style={{ flexShrink: 0 }} />
                    {/* Checkbox (visual only) */}
                    <div style={{ width: 22, height: 22, borderRadius: 7, border: '1.5px solid var(--sc-border)', flexShrink: 0 }} />
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: 14, color: 'var(--sc-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{t.title}</div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 3 }}>
                        {t._listName && <span style={{ fontSize: 10, color: 'var(--sc-text-4)' }}>{t._listName}</span>}
                        {bc && <span style={{ fontSize: 10, fontWeight: 600, background: bc.bg, color: bc.fg, borderRadius: 9999, padding: '1px 7px' }}>{t.badge}</span>}
                      </div>
                    </div>
                    {t.priority && <div style={{ width: 7, height: 7, borderRadius: '50%', background: PC[t.priority] || '#ccc', flexShrink: 0 }} />}
                  </div>
                );
              })}
            </Card>
          </div>
        )}
        </div>
      </div>
    </div>
  );
}

// ─── FilesScreen ──────────────────────────────────────────────
function FilesScreen() {
  const app = window.useApp();
  const { NavHeader, FloatingTabBar, SolFloatBtn, FileBadge, StorageBar, Card, SectionHeader, EmptyRow } = window;
  const [scrollY, setScrollY] = useState(0);
  const [copied, setCopied] = useState(null);
  const files = app.files || [];

  const openPreview = f => { app.setCurrentPreviewFile(f); app.setModal('file-preview'); };
  const fmtSize = b => b >= 1e6 ? `${(b / 1e6).toFixed(1)} MB` : `${Math.round(b / 1e3)} KB`;
  const fmtDate = iso => new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

  const copyLink = (f, e) => {
    e && e.stopPropagation();
    setCopied(f.id);
    setTimeout(() => setCopied(null), 1800);
  };

  const toggleVisibility = (f, e) => {
    e && e.stopPropagation();
    app.setFiles(prev => prev.map(x => x.id === f.id ? { ...x, isPublic: !x.isPublic } : x));
  };

  const deleteFile = (f, e) => {
    e && e.stopPropagation();
    app.setFiles(prev => prev.filter(x => x.id !== f.id));
  };

  const MIME_COLOR = mime => mime.includes('pdf') ? '#dc2626' : mime.includes('image') ? '#2563eb' : mime.includes('zip') ? '#d97706' : '#5e4dbb';


  const recent = files.slice(0, 3);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--sc-page)', position: 'relative', overflow: 'hidden' }}>
      <div className="sc-scroll" onScroll={e => setScrollY(e.currentTarget.scrollTop)}
        style={{ flex: 1, minHeight: 0, overflowY: 'auto', paddingBottom: 96 }}>
        <NavHeader title="Files" subtitle="Upload, share and manage your files." scrollY={scrollY} trailing={null}/>

        {/* Storage card */}
        <div style={{ margin: '0 22px 18px', background: 'var(--sc-card)', border: '0.5px solid var(--sc-border)', borderRadius: 18, padding: 16 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: 'var(--sc-primary-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <window.SFSymbol name="storage" size={17} color="var(--sc-primary)" fill />
            </div>
            <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--sc-text)' }}>Storage</div>
            {app.profile.isAdmin && <span style={{ fontSize: 9, fontWeight: 700, color: 'var(--sc-primary)', background: 'var(--sc-primary-bg)', borderRadius: 9999, padding: '2px 7px', textTransform: 'uppercase', letterSpacing: '0.04em', marginLeft: 'auto' }}>Admin · Unlimited</span>}
          </div>
          <StorageBar used={files.reduce((a, f) => a + (f.size || 0), 0) + 2.4e9} total={15e9} isAdmin={app.profile.isAdmin} />
        </div>

        {/* Recent */}
        {recent.length > 0 && (
          <div>
            <SectionHeader title="Recent" right={<span style={{ fontSize: 12, color: 'var(--sc-text-4)' }}>{files.length} files</span>} />
            <div style={{ padding: '0 18px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 4 }}>
              {recent.slice(0, 2).map(f => (
                <div key={f.id} onClick={() => openPreview(f)}
                  style={{ background: 'var(--sc-card)', border: '0.5px solid var(--sc-border)', borderRadius: 18, padding: 14, display: 'flex', flexDirection: 'column', gap: 10, cursor: 'pointer', transition: 'transform 160ms cubic-bezier(0.34,1.56,0.64,1), box-shadow 160ms ease' }}
                  onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 8px 20px rgba(94,77,187,0.14)'; }}
                  onMouseLeave={e => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = 'none'; }}>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    <FileBadge mime={f.mimeType} size={42} />
                    <span style={{ fontSize: 9, fontWeight: 700, color: f.isPublic ? 'var(--sc-primary)' : 'var(--sc-text-4)', background: f.isPublic ? 'var(--sc-primary-bg)' : 'var(--sc-hover)', borderRadius: 9999, padding: '2px 8px', textTransform: 'uppercase' }}>{f.isPublic ? 'Public' : 'Private'}</span>
                  </div>
                  <div style={{ fontSize: 12.5, fontWeight: 600, color: 'var(--sc-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.name}</div>
                  <div style={{ fontSize: 11, color: 'var(--sc-text-4)' }}>{fmtSize(f.size)} · {fmtDate(f.createdAt)}</div>
                  {f.isPublic && (
                    <button onClick={e => copyLink(f, e)} style={{ padding: '7px 0', background: copied === f.id ? '#ecfdf5' : 'var(--sc-primary-bg)', color: copied === f.id ? '#10B981' : 'var(--sc-primary)', border: 'none', borderRadius: 8, fontSize: 12, fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
                      <window.SFSymbol name={copied === f.id ? 'check' : 'link'} size={12} color={copied === f.id ? '#10B981' : 'var(--sc-primary)'} />
                      {copied === f.id ? 'Copied!' : 'Copy Link'}
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Upload drop area */}
        <div style={{ margin: '8px 18px 8px' }}>
          <div style={{ border: '2px dashed rgba(94,77,187,0.35)', borderRadius: 20, padding: '28px 20px',
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, cursor: 'pointer',
            background: 'linear-gradient(160deg, rgba(94,77,187,0.07) 0%, rgba(94,77,187,0.03) 100%)',
            transition: 'all 200ms ease', boxShadow: '0 2px 14px rgba(94,77,187,0.08)' }}
            onMouseEnter={e => { e.currentTarget.style.background='linear-gradient(160deg,rgba(94,77,187,0.13) 0%,rgba(94,77,187,0.06) 100%)'; e.currentTarget.style.borderColor='rgba(94,77,187,0.6)'; e.currentTarget.style.boxShadow='0 4px 20px rgba(94,77,187,0.18)'; }}
            onMouseLeave={e => { e.currentTarget.style.background='linear-gradient(160deg,rgba(94,77,187,0.07) 0%,rgba(94,77,187,0.03) 100%)'; e.currentTarget.style.borderColor='rgba(94,77,187,0.35)'; e.currentTarget.style.boxShadow='0 2px 14px rgba(94,77,187,0.08)'; }}>
            <div style={{ width: 52, height: 52, borderRadius: 16, background: 'var(--sc-primary-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 14px rgba(94,77,187,0.20)' }}>
              <window.SFSymbol name="cloud_upload" size={26} color="var(--sc-primary)" fill />
            </div>
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--sc-primary)' }}>Tap to upload</div>
              <div style={{ fontSize: 12, color: 'var(--sc-text-4)', marginTop: 3 }}>JPEG, PNG, PDF, ZIP · up to 200 MB</div>
            </div>
          </div>
        </div>

        {/* All files list */}
        <SectionHeader title="All Files" />
        <Card>
          {files.length === 0
            ? <EmptyRow text="No files yet. Upload your first file!" />
            : files.map((f, i) => (
              <div key={f.id}
                style={{ display: 'flex', alignItems: 'center', gap: 13, padding: '13px 16px',
                  borderBottom: i < files.length - 1 ? '0.5px solid var(--sc-separator)' : 'none',
                  cursor: 'pointer', transition: 'background 150ms' }}
                onClick={() => openPreview(f)}
                onMouseEnter={e => e.currentTarget.style.background = 'var(--sc-hover)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                <FileBadge mime={f.mimeType} size={40} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13.5, fontWeight: 600, color: 'var(--sc-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.name}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 3 }}>
                    <span style={{ fontSize: 11.5, color: 'var(--sc-text-4)' }}>{fmtSize(f.size)}</span>
                    <span style={{ color: 'var(--sc-separator)' }}>·</span>
                    <span style={{ fontSize: 11.5, color: 'var(--sc-text-4)' }}>{fmtDate(f.createdAt)}</span>
                    {f.hasPassword && <span style={{ fontSize: 10, color: 'var(--sc-text-4)', display: 'flex', alignItems: 'center', gap: 2 }}><window.SFSymbol name="lock" size={9} color="var(--sc-text-4)"/>pw</span>}
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <span style={{ fontSize: 9.5, fontWeight: 700, color: f.isPublic ? 'var(--sc-primary)' : 'var(--sc-text-4)', background: f.isPublic ? 'var(--sc-primary-bg)' : 'var(--sc-hover)', borderRadius: 9999, padding: '2px 7px', textTransform: 'uppercase' }}>{f.isPublic ? 'Public' : 'Private'}</span>
                  <window.SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)" />
                </div>
              </div>
            ))}
        </Card>

      </div>
    </div>
  );
}

// ─── FolderDashboardScreen ────────────────────────────────────
function FolderDashboardScreen() {
  const app = window.useApp();
  const { FloatingTabBar, SolFloatBtn, Card, SectionHeader } = window;
  const folder = (app.folders || []).find(f => f.id === app.currentFolderId) || app.folders?.[0];
  const lists = (app.lists || []).filter(l => l.folderId === (folder?.id));
  if (!folder) return null;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--sc-page)', position: 'relative', overflow: 'hidden' }}>
      <div className="sc-scroll" style={{ flex: 1, minHeight: 0, overflowY: 'auto', paddingBottom: 96 }}>
        <window.NavHeader title={folder.name} large={false} scrollY={1}
          leading={
            <button onClick={() => app.setScreen('dashboard')} style={{ display: 'flex', alignItems: 'center', gap: 2, background: 'transparent', border: 'none', cursor: 'pointer', color: 'var(--sc-primary)', padding: '6px 4px' }}>
              <window.SFSymbol name="chevron_left" size={22} color="var(--sc-primary)" weight={500} />
              <span style={{ fontFamily: 'var(--sc-font)', fontSize: 16 }}>Home</span>
            </button>
          }
          trailing={null}
        />

        <div style={{ margin: '0 22px 20px', padding: '20px 18px', background: `linear-gradient(135deg, ${folder.color}18 0%, #fff 80%)`, border: `0.5px solid ${folder.color}30`, borderRadius: 24 }}>
          <div style={{ fontSize: 42, lineHeight: 1, marginBottom: 10 }}>{folder.emoji}</div>
          <div style={{ fontSize: 24, fontWeight: 700, letterSpacing: '-0.02em', color: folder.color }}>{folder.name}</div>
          <div style={{ fontSize: 13, color: 'var(--sc-text-3)', marginTop: 4 }}>{lists.length} list{lists.length !== 1 ? 's' : ''}</div>
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            {[{ label: 'Total', val: lists.reduce((a, l) => a + l.sections.flatMap(s => s.tasks).length, 0), color: 'var(--sc-primary)' },
              { label: 'Done', val: lists.reduce((a, l) => a + l.sections.flatMap(s => s.tasks).filter(t => t.checked).length, 0), color: '#10B981' },
              { label: 'Open', val: lists.reduce((a, l) => a + l.sections.flatMap(s => s.tasks).filter(t => !t.checked).length, 0), color: '#ea580c' }].map(stat => (
              <div key={stat.label} style={{ flex: 1, background: 'rgba(255,255,255,0.7)', borderRadius: 12, padding: '10px 0', textAlign: 'center' }}>
                <div className="sc-mono" style={{ fontSize: 22, fontWeight: 700, color: stat.color }}>{stat.val}</div>
                <div style={{ fontSize: 10, color: 'var(--sc-text-4)', marginTop: 2, textTransform: 'uppercase', letterSpacing: '0.06em', fontWeight: 600 }}>{stat.label}</div>
              </div>
            ))}
          </div>
        </div>

        <SectionHeader title="Lists in this folder" right={<span style={{ fontSize: 11, color: 'var(--sc-text-4)' }}>{lists.length}</span>} />
        <Card>
          {lists.length === 0
            ? <window.EmptyRow text="No lists in this folder yet." />
            : lists.map((list, i) => {
              const t = list.sections.flatMap(s => s.tasks).length;
              const d = list.sections.flatMap(s => s.tasks).filter(x => x.checked).length;
              const pct = t ? Math.round((d / t) * 100) : 0;
              return (
                <button key={list.id} onClick={() => { app.setCurrentListId(list.id); app.setScreen('list'); }}
                  style={{ width: '100%', display: 'flex', alignItems: 'center', gap: 13, padding: '15px 16px', background: 'transparent', border: 'none', borderBottom: i < lists.length - 1 ? '0.5px solid var(--sc-separator)' : 'none', cursor: 'pointer', textAlign: 'left' }}>
                  <div style={{ width: 44, height: 44, borderRadius: 13, background: list.colorBg || 'var(--sc-primary-bg)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 22 }}>{list.emoji}</div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontSize: 15, fontWeight: 600, color: 'var(--sc-text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{list.name}</div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 5 }}>
                      <div style={{ flex: 1, height: 4, background: '#ebe6f0', borderRadius: 9999, overflow: 'hidden' }}>
                        <div style={{ width: `${pct}%`, height: '100%', background: list.color || 'var(--sc-primary)', borderRadius: 9999 }} />
                      </div>
                      <span className="sc-mono" style={{ fontSize: 11, color: 'var(--sc-text-3)', flexShrink: 0 }}>{pct}%</span>
                    </div>
                  </div>
                  <window.SFSymbol name="chevron_right" size={16} color="var(--sc-text-4)" />
                </button>
              );
            })}
        </Card>

        <div style={{ padding: '16px 22px 0' }}>
          <button onClick={() => app.setModal('add-list')} style={{ width: '100%', padding: '13px 0', background: 'transparent', color: 'var(--sc-primary)', border: `1.5px solid var(--sc-primary)`, borderRadius: 14, fontSize: 14, fontWeight: 600, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7 }}>
            <window.SFSymbol name="add" size={16} color="var(--sc-primary)" weight={600} />Add List to Folder
          </button>
        </div>
      </div>
    </div>
  );
}

// ─── ListsScreen ──────────────────────────────────────────────
function ListsScreen() {
  const app = window.useApp();
  const { NavHeader, Card, SectionHeader, EmptyRow, SFSymbol } = window;
  const [scrollY, setScrollY] = useState(0);
  const [collapsedFolders, setCollapsedFolders] = useState({});

  const folders = app.folders || [];
  const allLists = app.lists || [];
  const standalone = allLists.filter(l => !l.folderId);

  const goToList = id => { app.setCurrentListId(id); app.setScreen('list'); };
  const goToFolder = id => { app.setCurrentFolderId(id); app.setScreen('folder'); };

  const totalOpen = allLists.reduce((a, l) => a + l.sections.flatMap(s => s.tasks).filter(t => !t.checked).length, 0);
  const totalDone = allLists.reduce((a, l) => a + l.sections.flatMap(s => s.tasks).filter(t => t.checked).length, 0);
  const connected = app.profile.mode === 'server';
  const ws = (app.workspaces||[]).find(w => w.id === app.currentWorkspaceId);
  const timelines = app.timelines || [];

  const ListCard = ({ list, index = 0 }) => {
    const tasks = list.sections.flatMap(s => s.tasks);
    const done = tasks.filter(t => t.checked).length;
    const pct = tasks.length ? Math.round((done / tasks.length) * 100) : 0;
    return (
      <button onClick={() => goToList(list.id)} style={{
        width:'100%', display:'flex', alignItems:'center', gap:13,
        padding:'14px 16px', background:'transparent', border:'none',
        borderBottom:'0.5px solid var(--sc-separator)', cursor:'pointer', textAlign:'left',
        animation:`rowSlideIn 300ms cubic-bezier(0.34,1.2,0.64,1) ${index*50}ms both`,
      }}
        onMouseEnter={e=>e.currentTarget.style.background='var(--sc-hover)'}
        onMouseLeave={e=>e.currentTarget.style.background='transparent'}
      >
        <div style={{
          width:46, height:46, borderRadius:14, flexShrink:0, fontSize:22,
          background: list.colorBg || 'var(--sc-primary-bg)',
          display:'flex', alignItems:'center', justifyContent:'center',
        }}>{list.emoji}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontSize:15, fontWeight:600, color:'var(--sc-text)', overflow:'hidden', textOverflow:'ellipsis', whiteSpace:'nowrap'}}>{list.name}</div>
          <div style={{display:'flex', alignItems:'center', gap:8, marginTop:5}}>
            <div style={{flex:1, height:4, background:'#ebe6f0', borderRadius:9999, overflow:'hidden'}}>
              <div style={{width:`${pct}%`, height:'100%', background:list.color||'var(--sc-primary)', borderRadius:9999, transition:'width 400ms'}}/>
            </div>
            <span className="sc-mono" style={{fontSize:11, color:'var(--sc-text-3)', flexShrink:0, fontWeight:500}}>
              {done}/{tasks.length}
            </span>
          </div>
        </div>
        <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
      </button>
    );
  };

  return (
    <div style={{display:'flex', flexDirection:'column', height:'100%', background:'var(--sc-page)', position:'relative', overflow:'hidden'}}>
      <div className="sc-scroll" onScroll={e => setScrollY(e.currentTarget.scrollTop)}
        style={{flex:1, minHeight:0, overflowY:'auto', paddingBottom:96}}>
        <NavHeader title="Lists" subtitle="Organise tasks into focused lists and folders." scrollY={scrollY}/>

        {/* Workspace switcher (server only) */}
        {connected && ws && (
          <div style={{ margin:'0 22px 14px', animation:'springUp 340ms cubic-bezier(0.34,1.2,0.64,1) 40ms both' }}>
            <button onClick={()=>app.setModal('workspace-switcher')} style={{ width:'100%', display:'flex', alignItems:'center', gap:12, padding:'12px 14px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16, cursor:'pointer', textAlign:'left' }}
              onMouseEnter={e=>e.currentTarget.style.background='var(--sc-hover)'}
              onMouseLeave={e=>e.currentTarget.style.background='var(--sc-card)'}>
              <div style={{ width:38, height:38, borderRadius:11, background:'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center', fontSize:20, flexShrink:0 }}>{ws.emoji}</div>
              <div style={{ flex:1, minWidth:0 }}>
                <div style={{ fontSize:9.5, fontWeight:700, color:'var(--sc-text-4)', letterSpacing:'0.08em', textTransform:'uppercase' }}>Workspace</div>
                <div style={{ fontSize:15, fontWeight:700, color:'var(--sc-text)' }}>{ws.name}</div>
              </div>
              <div style={{ display:'flex', alignItems:'center', gap:4, color:'var(--sc-primary)', fontSize:12.5, fontWeight:600 }}>Switch<SFSymbol name="unfold_more" size={16} color="var(--sc-primary)"/></div>
            </button>
          </div>
        )}

        {/* Summary strip */}
        <div style={{
          margin:'0 22px 18px', display:'flex', gap:10,
          animation:'springUp 350ms cubic-bezier(0.34,1.2,0.64,1) 60ms both',
        }}>
          {[
            {label:'Lists', val:allLists.length, icon:'list_alt', color:'#5e4dbb', action:null},
            {label:'Open',  val:totalOpen,        icon:'radio_button_unchecked', color:'#ea580c', action:()=>{app.setTaskFilter('open');app.setModal('task-filter');}},
            {label:'Done',  val:totalDone,        icon:'check_circle',           color:'#10B981', action:()=>{app.setTaskFilter('completed');app.setModal('task-filter');}},
          ].map((s,i) => (
            <button key={s.label} onClick={s.action||undefined} style={{
              flex:1, background:'var(--sc-card)', border:'0.5px solid var(--sc-border)',
              borderRadius:16, padding:'12px 0', textAlign:'center', cursor:s.action?'pointer':'default',
              animation:`springUp 350ms cubic-bezier(0.34,1.2,0.64,1) ${80+i*60}ms both`,
              transition:'transform 160ms cubic-bezier(0.34,1.56,0.64,1), box-shadow 160ms ease',
            }}
              onMouseEnter={e=>{ if(s.action){ e.currentTarget.style.transform='translateY(-2px)'; e.currentTarget.style.boxShadow=`0 6px 18px ${s.color}22`; }}}
              onMouseLeave={e=>{ e.currentTarget.style.transform='translateY(0)'; e.currentTarget.style.boxShadow='none'; }}
            >
              <SFSymbol name={s.icon} size={18} color={s.color} fill style={{marginBottom:4}}/>
              <div className="sc-mono" style={{fontSize:20, fontWeight:700, color:'var(--sc-text)', lineHeight:1}}>{s.val}</div>
              <div style={{fontSize:10, color:'var(--sc-text-4)', marginTop:3, fontWeight:600, textTransform:'uppercase', letterSpacing:'0.06em'}}>{s.label}</div>
            </button>
          ))}
        </div>

        {/* Timelines entry */}
        <button onClick={()=>app.setScreen('timelines')} style={{
          width:'calc(100% - 44px)', margin:'0 22px 6px', display:'flex', alignItems:'center', gap:13,
          padding:'14px 16px', background:'var(--sc-card)', border:'0.5px solid var(--sc-border)', borderRadius:16,
          cursor:'pointer', textAlign:'left', animation:'springUp 360ms cubic-bezier(0.34,1.2,0.64,1) 120ms both' }}
          onMouseEnter={e=>{ e.currentTarget.style.transform='translateY(-2px)'; e.currentTarget.style.boxShadow='0 6px 18px rgba(94,77,187,0.14)'; }}
          onMouseLeave={e=>{ e.currentTarget.style.transform='translateY(0)'; e.currentTarget.style.boxShadow='none'; }}>
          <div style={{ width:44, height:44, borderRadius:13, background:'var(--sc-primary-bg)', display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>
            <SFSymbol name="timeline" size={22} color="var(--sc-primary)" fill/>
          </div>
          <div style={{ flex:1, minWidth:0 }}>
            <div style={{ fontSize:15, fontWeight:600, color:'var(--sc-text)' }}>Timelines</div>
            <div style={{ fontSize:12.5, color:'var(--sc-text-3)', marginTop:2 }}>{timelines.length} timeline{timelines.length!==1?'s':''} · milestones &amp; plans</div>
          </div>
          <SFSymbol name="chevron_right" size={15} color="var(--sc-text-4)"/>
        </button>

        {/* Folders */}
        {folders.map((folder, fi) => {
          const folderLists = allLists.filter(l => l.folderId === folder.id);
          const col = collapsedFolders[folder.id];
          return (
            <div key={folder.id} style={{animation:`springUp 380ms cubic-bezier(0.34,1.2,0.64,1) ${160+fi*80}ms both`}}>
              <div style={{display:'flex', alignItems:'center', gap:8, padding:'14px 26px 6px'}}>
                <button onClick={() => setCollapsedFolders(p => ({...p,[folder.id]:!p[folder.id]}))}
                  style={{background:'transparent', border:'none', cursor:'pointer', padding:0, display:'flex'}}>
                  <SFSymbol name={col ? 'chevron_right' : 'expand_more'} size={17} color={folder.color||'var(--sc-text-3)'}
                    style={{transition:'transform 200ms ease'}}/>
                </button>
                <button onClick={() => goToFolder(folder.id)}
                  style={{display:'flex', alignItems:'center', gap:8, background:'transparent', border:'none', cursor:'pointer'}}>
                  <span style={{fontSize:17}}>{folder.emoji}</span>
                  <span style={{fontSize:12, fontWeight:700, color:folder.color||'var(--sc-text-2)', letterSpacing:'0.06em', textTransform:'uppercase'}}>{folder.name}</span>
                </button>
                <span style={{fontSize:11, color:'var(--sc-text-4)', background:'var(--sc-hover)', borderRadius:9999, padding:'1px 8px', fontWeight:600}}>{folderLists.length}</span>
              </div>
              {!col && (
                <Card>
                  {folderLists.length === 0
                    ? <EmptyRow text="No lists in this folder"/>
                    : folderLists.map((l,i) => <ListCard key={l.id} list={l} index={i}/>)}
                </Card>
              )}
            </div>
          );
        })}

        {/* Standalone lists */}
        {standalone.length > 0 && (
          <div style={{animation:`springUp 380ms cubic-bezier(0.34,1.2,0.64,1) ${folders.length > 0 ? 280 : 160}ms both`}}>
            {folders.length > 0 && <SectionHeader title="Other Lists"/>}
            <Card>
              {standalone.map((l, i) => <ListCard key={l.id} list={l} index={i}/>)}
            </Card>
          </div>
        )}

        {allLists.length === 0 && (
          <div style={{padding:'60px 22px', textAlign:'center'}}>
            <div style={{fontSize:48, marginBottom:12}}>📋</div>
            <div style={{fontSize:17, fontWeight:600, color:'var(--sc-text-3)', marginBottom:6}}>No lists yet</div>
            <div style={{fontSize:13, color:'var(--sc-text-4)'}}>Tap + to create your first list.</div>
          </div>
        )}
      </div>
    </div>
  );
}

// ─── AppShell ─────────────────────────────────────────────────
const SCREEN_RANK = { welcome:-2, login:-1, dashboard:0, scheduled:1, files:2, lists:3, list:3, folder:3, timelines:4, timeline:4 };
const CHROME_SCREENS = new Set(['dashboard','scheduled','files','lists','list','folder','timelines']);

function AppShell() {
  const app = window.useApp();
  const [screenKey, setScreenKey] = useState(0);
  const [direction, setDirection] = useState('right');
  const prevScreen = useRef(app.screen);

  useEffect(() => {
    if (app.screen !== prevScreen.current) {
      const prevRank = SCREEN_RANK[prevScreen.current] ?? 0;
      const newRank  = SCREEN_RANK[app.screen]         ?? 0;
      setDirection(newRank >= prevRank ? 'right' : 'left');
      prevScreen.current = app.screen;
      setScreenKey(k => k + 1);
    }
  }, [app.screen]);

  const SCREENS = {
    welcome:   window.WelcomeScreen,
    login:     window.LoginScreen,
    dashboard: window.DashboardScreen,
    list:      window.ListScreen,
    scheduled: window.CalendarScreen,
    files:     window.FilesScreen,
    folder:    window.FolderDashboardScreen,
    lists:     window.ListsScreen,
    timelines: window.TimelinesScreen,
    timeline:  window.TimelineScreen,
  };
  const SHEETS = {
    'file-preview':  window.FilePreviewSheet,
    'task-filter':  window.TaskFilterSheet,
    'task-detail':  window.TaskDetailSheet,
    'edit-task':    window.EditTaskSheet,
    'add-task':     () => <window.EditTaskSheet creating={true}/>,
    'settings':     window.SettingsSheet,
    'lists-drawer': window.ListsDrawerSheet,
    'add-choice':   window.AddChoiceSheet,
    'add-folder':   window.AddFolderSheet,
    'add-list':     window.AddListSheet,
    'ai-chat':      window.AIAssistantSheet,
    'trash':        window.TrashSheet,
    'add-timeline':       window.AddTimelineSheet,
    'meeting':            window.MeetingSheet,
    'day-add':            window.DayAddChooserSheet,
    'milestone-editor':   window.MilestoneEditorSheet,
    'workspace-switcher': window.WorkspaceSwitcherSheet,
    'workspace-wizard':   window.WorkspaceWizardSheet,
    'item-settings':      window.ItemSettingsSheet,
    'two-fa':             window.TwoFASheet,
  };

  const Screen = SCREENS[app.screen] || window.DashboardScreen;
  const Sheet  = app.modal ? SHEETS[app.modal] : null;
  const showChrome  = CHROME_SCREENS.has(app.screen);
  const showProfile = ['dashboard','scheduled','files','lists','timelines'].includes(app.screen);
  const chromeHidden = !!app.modal;
  const enterAnim  = direction === 'right'
    ? 'slideFromRight 260ms cubic-bezier(0.32,0.72,0,1) both'
    : 'slideFromLeft  260ms cubic-bezier(0.32,0.72,0,1) both';

  return (
    <div style={{height:'100%', background:'var(--sc-page)', position:'relative', overflow:'hidden'}}>
      {/* ── Screen (slides on change, blurs when sheet open) ── */}
      <div key={screenKey} style={{
        height:'100%', animation: enterAnim,
        filter:    app.modal ? 'blur(7px)' : 'none',
        transform: app.modal ? 'scale(0.96)' : 'scale(1)',
        transition:'filter 320ms ease, transform 320ms cubic-bezier(0.32,0.72,0,1)',
        pointerEvents: app.modal ? 'none' : 'all',
        overflow: app.modal ? 'hidden' : 'visible',
      }}>
        <Screen/>
      </div>

      {/* ── Persistent chrome — stays mounted, fades out when sheet open ── */}
      {showChrome && (
        <div style={{opacity: chromeHidden?0:1, pointerEvents: chromeHidden?'none':'all', transition:'opacity 180ms ease'}}>
          <window.FloatingTabBar/>
          <window.AddFloatBtn/>
          <window.SolFloatBtn/>
        </div>
      )}
      {showProfile && (
        <div style={{opacity: chromeHidden?0:1, pointerEvents: chromeHidden?'none':'all', transition:'opacity 180ms ease'}}>
          <window.ProfileBtn/>
        </div>
      )}

      {/* ── Sheet overlay ── */}
      {Sheet && (
        <div style={{position:'absolute', inset:0, zIndex:200}}>
          <div onClick={() => app.setModal(null)} style={{
            position:'absolute', inset:0,
            background:'rgba(0,0,0,0.38)',
            backdropFilter:'blur(2px)', WebkitBackdropFilter:'blur(2px)',
            animation:'overlayIn 240ms ease both',
          }}/>
          <div key={app.modal} style={{
            position:'absolute', bottom:0, left:0, right:0,
            background:'var(--sc-card)', borderRadius:'26px 26px 0 0',
            maxHeight:'92%', overflow:'hidden',
            display:'flex', flexDirection:'column',
            animation:'sheetIn 380ms cubic-bezier(0.22,1.0,0.36,1) both',
            boxShadow:'0 -24px 60px rgba(0,0,0,0.22), 0 -1px 0 rgba(255,255,255,0.08)',
          }}>
            <div style={{display:'flex', justifyContent:'center', padding:'10px 0 2px', flexShrink:0}}>
              <div style={{width:38, height:4, borderRadius:100, background:'var(--sc-separator)'}}/>
            </div>
            <div className="sc-scroll" style={{flex:1, overflowY:'auto'}}>
              <Sheet/>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Exports ──────────────────────────────────────────────────
Object.assign(window, {
  WelcomeScreen, LoginScreen, DashboardScreen, ListScreen, ListsScreen,
  ScheduledScreen, FilesScreen, FolderDashboardScreen, AppShell,
});
