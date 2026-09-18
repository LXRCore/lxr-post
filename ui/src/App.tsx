/* LXR-POST — the desk and the reader | © 2026 iBoss21 / LXRCore
   open { payload: { office, me, inbox[], sent[], boxes[], rates, cash, date } } · reader { payload: info } · close
   callbacks: find { q } · send { kind, address, toName, subject, body } · read { id } · collect { id } · burn { id } · close · closeReader */
import { useEffect, useMemo, useState } from 'react';
import { onMessage, applyChrome, makeT, post, money, pad, type Msg } from './nui';

type Mail = { id: number; from: string; to: string; box?: string; kind: 'letter' | 'telegram'; subject: string; body?: string | null; dated: string; arrived: boolean; arrivesIn: number; read: boolean };
type Sent = { id: number; to: string; kind: string; subject: string; dated: string; arrived: boolean; arrivesIn: number };
type Book = { office: { id: string; label: string }; me: string; inbox: Mail[]; sent: Sent[]; boxes: { address: string; label: string }[]; rates: { stamp: number; deliveryMinutes: number; perWord: number; minimum: number; maxWords: number; maxChars: number; subjectMax: number }; cash: number; date: string };
type Info = { from: string; to: string; subject: string; body: string; dated: string; kind: string };

const words = (s: string) => (s.trim().match(/\S+/g) || []).length;

export function App() {
  const [B, setB] = useState<Book | null>(null);
  const [reader, setReader] = useState<Info | null>(null);
  const [L, setL] = useState<Record<string, string>>({});
  const [tab, setTab] = useState<'inbox' | 'write' | 'sent'>('inbox');
  const [pick, setPick] = useState<number | null>(null);
  const [kind, setKind] = useState<'letter' | 'telegram'>('letter');
  const [q, setQ] = useState('');
  const [people, setPeople] = useState<{ citizenid: string; name: string }[]>([]);
  const [to, setTo] = useState<{ address: string; name: string } | null>(null);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  const t = makeT(L);

  useEffect(() => onMessage((m: Msg) => {
    applyChrome(m);
    if (m.locale) setL(m.locale);
    if (m.action === 'open') { setB(m.payload); setReader(null); setTab(m.payload && m.payload.inbox.some((x: Mail) => x.arrived && !x.read) ? 'inbox' : 'inbox'); setPick(null); setTo(null); setSubject(''); setBody(''); setQ(''); setPeople([]); }
    if (m.action === 'reader') setReader(m.payload);
    if (m.action === 'close') { setB(null); setReader(null); }
  }), []);
  useEffect(() => { const k = (e: KeyboardEvent) => { if (e.key === 'Escape') { if (reader && !B) post('closeReader'); else if (B) post('close'); } }; document.addEventListener('keydown', k); return () => document.removeEventListener('keydown', k); }, [reader, B]);
  useEffect(() => { if (q.trim().length < 3) { setPeople([]); return; } const h = setTimeout(async () => { const r = await post<{ ok: boolean; people: any[] }>('find', { q }); setPeople(r.ok ? r.people : []); }, 250); return () => clearTimeout(h); }, [q]);

  const mail = useMemo(() => B && pick != null ? B.inbox.find((m) => m.id === pick) || null : null, [B, pick]);
  const cost = useMemo(() => { if (!B) return 0; if (kind === 'letter') return body.trim().length ? B.rates.stamp : 0; const w = words(body); return w ? Math.max(B.rates.minimum, Math.round(w * B.rates.perWord * 100) / 100) : 0; }, [B, kind, body]);
  const valid = B && to && body.trim().length > 0 && (kind === 'letter' ? body.length <= B.rates.maxChars : words(body) <= B.rates.maxWords) && cost <= B.cash;
  const call = async (name: string, data?: any) => { if (busy) return; setBusy(true); const r = await post<{ ok: boolean; data?: Book }>(name, data); setBusy(false); if (r.ok && r.data) setB(r.data); return r.ok; };
  const openMail = async (m: Mail) => { setPick(m.id); if (m.arrived && !m.read) { await post('read', { id: m.id }); setB((b) => b ? { ...b, inbox: b.inbox.map((x) => x.id === m.id ? { ...x, read: true } : x) } : b); } };

  /* ── the reader (a letter item opened from the satchel) ── */
  if (!B && reader) {
    return (
      <div className="po-paper-wrap"><div className={'po-paper lxr-hit' + (reader.kind === 'telegram' ? ' po-paper--wire' : '')}>
        <div className="po-paper__head lxr-mono"><span>{t('ui.from')} {reader.from}</span><span className="lxr-grow" /><span>{reader.dated}</span></div>
        <div className="po-paper__subject lxr-cut">{reader.subject}</div>
        <div className="po-paper__body">{reader.body}</div>
        <div className="po-paper__foot"><button className="lxr-btn lxr-btn-ghost lxr-btn-sm" onClick={() => post('closeReader')}>{t('ui.reader_close')}</button></div>
      </div></div>
    );
  }
  if (!B) return null;
  const unread = B.inbox.filter((m) => m.arrived && !m.read).length;

  return (
    <div id="app">
      <header className="po-top lxr-hit">
        <div className="po-brand"><img className="po-logo" src="img/lxrcore-logo.png" alt="" /><div><span className="lxr-mono lxr-t-ash">{t('ui.kicker')} · {B.date}</span><h1 className="lxr-cut po-title">{B.office.label}</h1></div></div>
        <span className="lxr-grow" />
        <div className="po-cash"><span className="lxr-mono lxr-t-smoke">{t('ui.cash')}</span><span className="lxr-num">{money(B.cash)}</span></div>
        <span className="po-hint lxr-mono lxr-t-smoke"><span className="lxr-key">Esc</span> {t('ui.hint_close')}</span>
      </header>
      <nav className="po-tabs lxr-hit">
        <button className={'po-tab' + (tab === 'inbox' ? ' is-on' : '')} onClick={() => setTab('inbox')}>{t('ui.inbox')}{unread > 0 && <span className="po-tab__n">{pad(unread)}</span>}</button>
        <button className={'po-tab' + (tab === 'write' ? ' is-on' : '')} onClick={() => setTab('write')}>{t('ui.write')}</button>
        <button className={'po-tab' + (tab === 'sent' ? ' is-on' : '')} onClick={() => setTab('sent')}>{t('ui.sent')}</button>
      </nav>

      {tab === 'inbox' && (
        <>
          <section className="po-list lxr-hit">
            {B.inbox.length === 0 && <div className="po-empty lxr-t-smoke">{t('ui.nothing')}</div>}
            {B.inbox.map((m, i) => (
              <div key={m.id} className={'po-mail' + (pick === m.id ? ' is-on' : '') + (m.arrived && !m.read ? ' is-unread' : '') + (m.arrived ? '' : ' is-road')} onClick={() => m.arrived && openMail(m)}>
                <span className="lxr-row-index">{pad(i + 1)}</span>
                <div className="po-mail__body">
                  <div className="po-mail__subject">{m.subject || '—'}</div>
                  <div className="po-mail__meta lxr-mono">{t('ui.' + m.kind)} · {t('ui.from')} {m.from}{m.box ? ' · ' + t('ui.box_of', { box: m.box }) : ''} · {m.dated}</div>
                </div>
                <span className="lxr-grow" />
                <span className="po-mail__state lxr-mono">{!m.arrived ? t('ui.arrives', { m: Math.ceil(m.arrivesIn / 60) }) : !m.read ? t('ui.unread') : ''}</span>
              </div>
            ))}
          </section>
          <aside className={'po-read lxr-hit' + (mail ? '' : ' is-empty')}>
            {!mail && <div className="po-empty lxr-t-smoke">{t('ui.read')} —</div>}
            {mail && (
              <div className={'po-paper' + (mail.kind === 'telegram' ? ' po-paper--wire' : '')}>
                <div className="po-paper__head lxr-mono"><span>{t('ui.from')} {mail.from}</span><span className="lxr-grow" /><span>{mail.dated}</span></div>
                <div className="po-paper__subject lxr-cut">{mail.subject}</div>
                <div className="po-paper__body">{mail.body}</div>
                <div className="po-paper__foot">
                  {!mail.box && <button className="lxr-btn lxr-btn-sm" disabled={busy} onClick={async () => { if (await call('collect', { id: mail.id })) setPick(null); }}>{t('ui.collect')}</button>}
                  {!mail.box && <button className="lxr-btn lxr-btn-ghost lxr-btn-sm" disabled={busy} onClick={async () => { if (await call('burn', { id: mail.id })) setPick(null); }}>{t('ui.burn')}</button>}
                </div>
              </div>
            )}
          </aside>
        </>
      )}

      {tab === 'write' && (
        <section className="po-write lxr-hit">
          <div className="po-write__row">
            <div className="po-seg"><button className="lxr-chip" aria-pressed={kind === 'letter'} onClick={() => setKind('letter')}>{t('ui.letter')}</button><button className="lxr-chip" aria-pressed={kind === 'telegram'} onClick={() => setKind('telegram')}>{t('ui.telegram')}</button></div>
            <span className="lxr-mono lxr-t-smoke">{kind === 'letter' ? t('ui.delivery', { n: B.rates.deliveryMinutes }) : t('ui.at_once')}</span>
          </div>
          <div className="po-write__row">
            <span className="lxr-mono lxr-t-smoke po-k">{t('ui.to')}</span>
            {to ? <span className="lxr-chip is-on" onClick={() => setTo(null)}>{to.name} ✕</span> : <input className="lxr-input" placeholder={t('ui.to_hint')} value={q} onChange={(e) => setQ(e.target.value)} />}
          </div>
          {!to && (people.length > 0 || B.boxes.length > 0) && (
            <div className="po-people">
              {people.map((p) => <button key={p.citizenid} className="lxr-chip" onClick={() => { setTo({ address: p.citizenid, name: p.name }); setQ(''); }}>{p.name}</button>)}
              {q.trim().length < 3 && B.boxes.map((b) => <button key={b.address} className="lxr-chip" onClick={() => setTo({ address: b.address, name: b.label })}>{t('ui.box')} · {b.label}</button>)}
            </div>
          )}
          <div className="po-write__row"><span className="lxr-mono lxr-t-smoke po-k">{t('ui.subject')}</span><input className="lxr-input" maxLength={B.rates.subjectMax} value={subject} onChange={(e) => setSubject(e.target.value)} /></div>
          <textarea className={'lxr-input po-body' + (kind === 'telegram' ? ' po-body--wire' : '')} placeholder={t('ui.body')} value={body} onChange={(e) => setBody(kind === 'telegram' ? e.target.value.toUpperCase() : e.target.value)} />
          <div className="po-write__row">
            <span className="lxr-mono lxr-t-smoke">{kind === 'letter' ? t('ui.chars', { n: body.length, max: B.rates.maxChars }) : t('ui.words', { n: words(body) }) + ' / ' + B.rates.maxWords}</span>
            <span className="lxr-grow" />
            <span className="lxr-mono lxr-t-smoke">{t('ui.cost')}</span><span className="lxr-num po-cost">{money(cost)}</span>
            <button className="lxr-btn" disabled={!valid || busy} onClick={async () => { if (to && await call('send', { kind, address: to.address, toName: to.name, subject, body })) { setBody(''); setSubject(''); setTo(null); setTab('sent'); } }}>{t('ui.send')}</button>
          </div>
        </section>
      )}

      {tab === 'sent' && (
        <section className="po-list po-list--wide lxr-hit">
          {B.sent.length === 0 && <div className="po-empty lxr-t-smoke">{t('ui.nothing_sent')}</div>}
          {B.sent.map((m, i) => <div key={m.id} className="po-mail"><span className="lxr-row-index">{pad(i + 1)}</span><div className="po-mail__body"><div className="po-mail__subject">{m.subject || '—'}</div><div className="po-mail__meta lxr-mono">{t('ui.' + m.kind)} · {t('ui.to')} {m.to} · {m.dated}</div></div><span className="lxr-grow" /><span className="po-mail__state lxr-mono">{m.arrived ? '' : t('ui.arrives', { m: Math.ceil(m.arrivesIn / 60) })}</span></div>)}
        </section>
      )}
    </div>
  );
}
