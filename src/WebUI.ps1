# LEVEL51-TUNE :: dashboard HTML (single page, no external assets)
# ถูกใช้โดย Level51Tune.Web.ps1 — คืน HTML ทั้งหน้าเป็น string เดียว

function Get-L51DashboardHtml {
    return @'
<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LEVEL51-TUNE · Dashboard</title>
<style>
:root{--bg:#0d1117;--panel:#151c26;--panel2:#1a2330;--border:#243040;--text:#d8e0ea;--muted:#8b98a9;--accent:#4cc2a0;--warn:#f0b429;--danger:#ef6b73;--ok:#4cc2a0}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:"Noto Sans Thai","Segoe UI",system-ui,sans-serif;font-size:15px;line-height:1.6}
.wrap{max-width:1180px;margin:0 auto;padding:22px 20px 60px}
header{display:flex;align-items:center;gap:14px;flex-wrap:wrap;padding-bottom:16px;border-bottom:1px solid var(--border);margin-bottom:20px}
.logo{width:42px;height:42px;border-radius:11px;background:linear-gradient(135deg,#4cc2a0,#2b7a67);color:#04120e;font-weight:700;display:grid;place-items:center;font-size:15px}
h1{font-size:19px;margin:0}
.sub{color:var(--muted);font-size:12.5px}
.badges{margin-left:auto;display:flex;gap:8px;flex-wrap:wrap}
.badge{font-size:12px;padding:4px 10px;border-radius:999px;border:1px solid var(--border);background:var(--panel);color:var(--muted)}
.badge.ok{color:#0b1a14;background:var(--ok);border-color:transparent;font-weight:600}
.badge.warn{color:#1d1500;background:var(--warn);border-color:transparent;font-weight:600}
.grid{display:grid;gap:14px}
.cols{grid-template-columns:repeat(auto-fit,minmax(215px,1fr))}
.card{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:14px 16px}
.card h2{font-size:12px;letter-spacing:.6px;text-transform:uppercase;color:var(--muted);margin:0 0 8px;font-weight:600}
.kv{display:flex;justify-content:space-between;gap:10px;font-size:13.5px;padding:2px 0}
.kv span:first-child{color:var(--muted)}
.section{margin-top:26px}
.section h3{font-size:15px;margin:0 0 12px;color:#e8eef6}
.profile{display:flex;flex-direction:column;gap:8px;background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:14px 16px}
.profile.active{border-color:var(--accent);box-shadow:0 0 0 1px rgba(76,194,160,.25) inset}
.profile .name{font-weight:700;font-size:15px}
.profile .meta{font-size:12.5px;color:var(--muted)}
.profile .desc{font-size:13px;color:#b9c6d6}
.btns{display:flex;gap:8px;margin-top:6px;flex-wrap:wrap}
button{font-family:inherit;font-size:13px;padding:7px 13px;border-radius:8px;border:1px solid var(--border);background:var(--panel2);color:var(--text);cursor:pointer;transition:.15s}
button:hover:not(:disabled){border-color:var(--accent);color:var(--accent)}
button:disabled{opacity:.45;cursor:not-allowed}
button.primary{background:var(--accent);border-color:var(--accent);color:#04120e;font-weight:700}
button.primary:hover:not(:disabled){filter:brightness(1.08);color:#04120e}
button.danger:hover:not(:disabled){border-color:var(--danger);color:var(--danger)}
.toolbar{display:flex;gap:9px;flex-wrap:wrap;align-items:center;margin:22px 0 0}
.status{padding:16px;border-radius:12px;background:var(--panel);border:1px solid var(--border);margin-top:18px}
.status pre{margin:0;white-space:pre-wrap;font-family:"JetBrains Mono",Consolas,monospace;font-size:12.5px;color:#b9c8d8;max-height:240px;overflow:auto}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{border-bottom:1px solid var(--border);padding:7px 9px;text-align:left}
th{color:var(--muted);font-weight:600;font-size:11.5px;text-transform:uppercase;letter-spacing:.5px}
td.yes{color:var(--ok);font-weight:600}
td.no{color:var(--muted)}
td.na{color:var(--warn)}
td.OK{color:var(--ok)}
td.WARN{color:var(--warn)}
td.FAIL{color:var(--danger)}
td.SKIP{color:var(--muted)}
.toast{position:fixed;right:18px;bottom:18px;padding:11px 16px;border-radius:10px;background:#12312a;border:1px solid var(--accent);color:#c8f5e5;font-size:13px;opacity:0;transform:translateY(8px);transition:.2s;pointer-events:none;max-width:360px}
.toast.show{opacity:1;transform:none}
.toast.err{background:#331519;border-color:var(--danger);color:#ffd9dc}
.hint{color:var(--muted);font-size:12.5px}
.spin{display:inline-block;width:12px;height:12px;border:2px solid rgba(255,255,255,.25);border-top-color:var(--accent);border-radius:50%;animation:sp .7s linear infinite;vertical-align:-1px}
@keyframes sp{to{transform:rotate(360deg)}}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="logo">L51</div>
    <div>
      <h1>LEVEL51-TUNE</h1>
      <div class="sub" id="machine">กำลังโหลด…</div>
    </div>
    <div class="badges">
      <span class="badge" id="badge-scheme">scheme: –</span>
      <span class="badge" id="badge-admin">admin: –</span>
      <a class="badge" href="/docs/index.html" target="_blank" style="text-decoration:none">เอกสาร</a>
    </div>
  </header>

  <div class="grid cols" id="hw"></div>

  <div class="section">
    <h3>โปรไฟล์</h3>
    <div class="grid cols" id="profiles"></div>
    <p class="hint" style="margin-top:10px">ปุ่ม “Dry run” ไม่แก้อะไรเลย · ปุ่ม “Apply” ต้องรันหน้านี้จาก PowerShell แบบ Administrator</p>
  </div>

  <div class="toolbar">
    <button onclick="loadStatus()">↻ รีเฟรชสถานะ</button>
    <button onclick="runAudit()">ตรวจ audit (performance)</button>
    <button onclick="runBench()">วัดประสิทธิภาพ (bench)</button>
    <button onclick="runLatency()">วัด latency (DPC)</button>
    <button class="danger" onclick="doRestore()">ย้อนกลับ (restore)</button>
    <span class="hint" id="busy"></span>
  </div>

  <div class="section" id="result-section" style="display:none">
    <h3 id="result-title">ผลลัพธ์</h3>
    <div class="card" style="padding:0;overflow:hidden"><div id="result"></div></div>
  </div>

  <div class="status">
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
      <strong style="font-size:13px">Log ล่าสุด</strong>
      <button onclick="loadLog()" style="padding:4px 10px;font-size:12px">โหลดใหม่</button>
    </div>
    <pre id="log">—</pre>
  </div>
</div>

<div class="toast" id="toast"></div>

<script>
const TOKEN = "__TOKEN__";

function toast(msg, isErr){
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.className = 'toast show' + (isErr ? ' err' : '');
  clearTimeout(window._t);
  window._t = setTimeout(() => { el.className = 'toast'; }, 4200);
}

async function api(path, body){
  const opt = { headers: { 'X-L51-Token': TOKEN, 'Content-Type': 'application/json' } };
  if (body !== undefined){ opt.method = 'POST'; opt.body = JSON.stringify(body); }
  const res = await fetch(path, opt);
  const data = await res.json().catch(() => ({ error: 'invalid json' }));
  if (!res.ok) throw new Error(data.error || ('HTTP ' + res.status));
  return data;
}

function busy(on, text){
  document.getElementById('busy').textContent = on ? text : '';
  document.querySelectorAll('button').forEach(b => { if (!b.dataset.keep) b.disabled = on; });
}

function esc(s){ return String(s == null ? '' : s).replace(/[&<>]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[c])); }

async function loadStatus(){
  busy(true, 'กำลังอ่านสถานะ…');
  try {
    const d = await api('/api/status');
    document.getElementById('machine').textContent =
      d.model + ' · ' + d.os + ' · ' + d.computer;
    const scheme = d.state && d.state.scheme ? d.state.scheme.slice(0,8) + '…' : 'default';
    const bs = document.getElementById('badge-scheme');
    bs.textContent = d.state ? 'scheme: ' + d.state.profile : 'scheme: –';
    bs.className = 'badge ' + (d.state ? 'ok' : '');
    const ba = document.getElementById('badge-admin');
    ba.textContent = 'admin: ' + (d.admin ? 'ใช่' : 'ไม่');
    ba.className = 'badge ' + (d.admin ? 'ok' : 'warn');

    const g = d.gpu;
    const hw = [
      { t: 'CPU', a: esc(d.cpu.replace(/\(R\)|\(TM\)|CPU @/g,'')), b: d.cores + 'C / ' + d.threads + 'T' },
      { t: 'RAM', a: d.ram.toFixed(1) + ' GB', b: 'ว่าง ' + d.ramFree.toFixed(1) + ' GB' },
      { t: 'GPU', a: g ? esc(g.name) : '—', b: g ? (g.clock + ' MHz · ' + g.temp + '°C · ' + g.power + ' W') : '' },
      { t: 'ดิสก์', a: d.disks.length ? esc(d.disks[0].name).slice(0,28) : '—', b: d.disks.length ? (d.disks[0].gb + ' GB · ' + d.disks[0].bus) : '' },
      { t: 'โปรไฟล์ล่าสุด', a: d.state ? esc(d.state.profile) : 'ยังไม่ apply', b: d.state ? new Date(d.state.appliedAt).toLocaleString('th-TH') : '—' }
    ];
    document.getElementById('hw').innerHTML = hw.map(x =>
      '<div class="card"><h2>' + x.t + '</h2><div class="kv"><span>' + x.a + '</span><span>' + x.b + '</span></div></div>'
    ).join('');

    document.getElementById('profiles').innerHTML = d.profiles.map(p => {
      const active = d.state && d.state.profile === p.id ? ' active' : '';
      return '<div class="profile' + active + '">' +
        '<div class="name">' + esc(p.titleTh) + ' <span class="meta">(' + p.id + ')</span></div>' +
        '<div class="desc">' + esc(p.summary) + '</div>' +
        '<div class="meta">' + p.tweaks + ' tweaks' + (p.high ? ' · high risk ' + p.high : '') + '</div>' +
        '<div class="btns">' +
          '<button onclick="applyProfile(\'' + p.id + '\', true)">Dry run</button>' +
          '<button class="primary" onclick="applyProfile(\'' + p.id + '\', false)">Apply</button>' +
        '</div></div>';
    }).join('');
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

function showResult(title, html){
  document.getElementById('result-title').textContent = title;
  document.getElementById('result').innerHTML = html;
  document.getElementById('result-section').style.display = 'block';
}

async function applyProfile(profile, dry){
  const msg = dry ? 'Dry run' : 'Apply';
  if (!dry && !confirm('Apply โปรไฟล์ ' + profile + ' ?\n\nจะมีการสำรองสถานะก่อนทุกครั้ง และย้อนกลับได้ด้วยปุ่ม restore')) return;
  busy(true, msg + ' ' + profile + '…');
  try {
    const d = await api('/api/apply', { profile: profile, dryRun: dry, includeHigh: false });
    const rows = d.results.map(r =>
      '<tr><td>' + esc(r.id) + '</td><td class="' + r.status + '">' + r.status + '</td><td class="hint">' + esc(r.detail) + '</td></tr>'
    ).join('');
    const counts = d.results.reduce((a, r) => (a[r.status] = (a[r.status] || 0) + 1, a), {});
    showResult(msg + ' · ' + profile + (d.backup ? ' · backup: ' + d.backup.split('\\').pop() : ''),
      '<table><thead><tr><th>Tweak</th><th>สถานะ</th><th>รายละเอียด</th></tr></thead><tbody>' + rows + '</tbody></table>' +
      '<div style="padding:10px 12px" class="hint">' + Object.keys(counts).map(k => k + ': ' + counts[k]).join(' · ') + '</div>');
    toast(msg + ' เสร็จ: ' + JSON.stringify(counts));
    loadStatus(); loadLog();
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function runAudit(){
  busy(true, 'กำลังตรวจ audit…');
  try {
    const d = await api('/api/audit', { profile: 'performance' });
    const rows = d.rows.map(r =>
      '<tr><td>' + esc(r.id) + '</td><td>' + esc(r.category) + '</td><td>' + esc(r.risk) + '</td>' +
      '<td class="' + (r.applied === 'YES' ? 'yes' : r.applied === '?' ? 'na' : 'no') + '">' + r.applied + '</td>' +
      '<td class="hint">' + esc(r.title) + '</td></tr>'
    ).join('');
    showResult('Audit · performance — ปรับแล้ว ' + d.done + ' / ' + d.total,
      '<table><thead><tr><th>Tweak</th><th>หมวด</th><th>Risk</th><th>สถานะ</th><th>รายละเอียด</th></tr></thead><tbody>' + rows + '</tbody></table>');
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function runBench(){
  busy(true, 'กำลังวัด (ประมาณ 20 วินาที)…');
  try {
    const d = await api('/api/bench', { seconds: 3, label: 'web' });
    showResult('Benchmark · ' + d.label,
      '<table><thead><tr><th>ตัวชี้วัด</th><th>ค่า</th></tr></thead><tbody>' +
      '<tr><td>CPU 1 thread</td><td>' + d.cpuSingle + ' MB/s</td></tr>' +
      '<tr><td>CPU ' + d.cores + ' threads</td><td>' + d.cpuMulti + ' MB/s</td></tr>' +
      '<tr><td>Memory copy</td><td>' + d.mem + ' MB/s</td></tr>' +
      '<tr><td>Disk write</td><td>' + d.diskWrite + ' MB/s</td></tr>' +
      '<tr><td>Disk read</td><td>' + d.diskRead + ' MB/s</td></tr>' +
      '</tbody></table>');
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function runLatency(){
  busy(true, 'กำลังเก็บตัวอย่าง latency…');
  try {
    const d = await api('/api/latency', { seconds: 10 });
    const rows = d.rows.map(r => '<tr><td>' + esc(r.counter) + '</td><td>' + r.avg + '</td><td>' + r.max + '</td></tr>').join('');
    showResult('Latency · scheme ' + esc(d.scheme || '—'),
      '<table><thead><tr><th>Counter</th><th>Avg</th><th>Max</th></tr></thead><tbody>' + rows + '</tbody></table>' +
      '<div style="padding:10px 12px" class="hint">DPC ' + d.dpc + '% · interrupt ' + d.isr + '% — ตัวเลขต่ำลงคือ jitter น้อยลง</div>');
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function doRestore(){
  if (!confirm('ย้อนกลับค่าทั้งหมดจาก backup ล่าสุด?')) return;
  busy(true, 'กำลัง restore…');
  try {
    const d = await api('/api/restore', {});
    const rows = d.results.map(r => '<tr><td>' + esc(r.id) + '</td><td class="' + esc(r.status) + '">' + esc(r.status) + '</td></tr>').join('');
    showResult('Restore', '<table><thead><tr><th>Tweak</th><th>สถานะ</th></tr></thead><tbody>' + rows + '</tbody></table>');
    toast('restore เสร็จ');
    loadStatus();
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function loadLog(){
  try {
    const d = await api('/api/log');
    document.getElementById('log').textContent = d.log || '—';
  } catch(e){ /* เงียบ */ }
}

/* ปุ่มพวกนี้ไม่ถูก disable ระหว่างงาน */
document.querySelectorAll('button').forEach(b => { if (b.textContent.includes('โหลดใหม่')) b.dataset.keep = '1'; });

loadStatus();
loadLog();
setInterval(loadLog, 15000);
</script>
</body>
</html>
'@
}
