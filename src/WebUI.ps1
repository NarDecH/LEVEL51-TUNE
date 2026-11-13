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
:root{--bg:#0d1117;--panel:#151c26;--panel2:#1a2330;--border:#243040;--text:#d8e0ea;--muted:#8b98a9;--accent:#4cc2a0;--warn:#f0b429;--danger:#ef6b73;--ok:#4cc2a0;--blue:#63a8f0;--violet:#a78bfa}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:"Noto Sans Thai","Segoe UI",system-ui,sans-serif;font-size:15px;line-height:1.6}
.wrap{max-width:1180px;margin:0 auto;padding:22px 20px 60px}
header{display:flex;align-items:center;gap:14px;flex-wrap:wrap;padding-bottom:16px;border-bottom:1px solid var(--border);margin-bottom:16px}
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
td.pos{color:var(--ok)}
td.neg{color:var(--danger)}
.toast{position:fixed;right:18px;bottom:18px;padding:11px 16px;border-radius:10px;background:#12312a;border:1px solid var(--accent);color:#c8f5e5;font-size:13px;opacity:0;transform:translateY(8px);transition:.2s;pointer-events:none;max-width:380px}
.toast.show{opacity:1;transform:none}
.toast.err{background:#331519;border-color:var(--danger);color:#ffd9dc}
.hint{color:var(--muted);font-size:12.5px}
.spin{display:inline-block;width:12px;height:12px;border:2px solid rgba(255,255,255,.25);border-top-color:var(--accent);border-radius:50%;animation:sp .7s linear infinite;vertical-align:-1px}
@keyframes sp{to{transform:rotate(360deg)}}
.tabs{display:flex;gap:6px;flex-wrap:wrap;margin:0 0 4px}
.tab{padding:7px 15px;border-radius:9px 9px 0 0;border:1px solid transparent;border-bottom:none;background:transparent;color:var(--muted);font-size:13.5px}
.tab.active{background:var(--panel);border-color:var(--border);color:var(--text);font-weight:600}
.view{display:none}
.view.active{display:block}
.searchbar{display:flex;gap:9px;flex-wrap:wrap;align-items:center;margin-bottom:12px}
.searchbar input[type=text],.searchbar select{font-family:inherit;font-size:13px;padding:7px 11px;border-radius:8px;border:1px solid var(--border);background:var(--panel2);color:var(--text);min-width:180px}
.twlist{background:var(--panel);border:1px solid var(--border);border-radius:12px;overflow:hidden;max-height:520px;overflow-y:auto}
.catrow{position:sticky;top:0;background:var(--panel2);padding:7px 14px;font-size:11.5px;letter-spacing:.6px;text-transform:uppercase;color:var(--muted);border-bottom:1px solid var(--border);z-index:1}
.tw{display:flex;gap:11px;align-items:flex-start;flex-wrap:wrap;padding:9px 14px;border-bottom:1px solid rgba(36,48,64,.6);cursor:pointer}
.tw:hover{background:#181f2a}
.tw input{margin-top:4px;width:16px;height:16px;accent-color:var(--accent);cursor:pointer}
.tw .t{font-size:13.5px}
.tw .d{font-size:12px;color:var(--muted);font-family:"JetBrains Mono",Consolas,monospace;max-width:70%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tw .r{font-size:10.5px;padding:1px 7px;border-radius:999px;border:1px solid var(--border);margin-left:6px;color:var(--muted)}
.tw .r.High{color:var(--danger);border-color:var(--danger)}
.tw .r.Medium{color:var(--warn);border-color:var(--warn)}
.chartgrid{display:grid;gap:14px;grid-template-columns:repeat(auto-fit,minmax(260px,1fr))}
.chart{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:12px 14px}
.chart .top{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:6px}
.chart .name{font-size:12px;letter-spacing:.5px;text-transform:uppercase;color:var(--muted)}
.chart .val{font-size:17px;font-weight:700;font-family:"JetBrains Mono",Consolas,monospace}
canvas{width:100%;height:70px;display:block}
.selinfo{font-size:13px;color:var(--muted);margin:10px 0 0}
.restartbar{display:flex;gap:10px;align-items:flex-start;margin:16px 0 0;padding:12px 14px;border-radius:12px;border:1px solid var(--warn);background:#33280f;color:#ffe7b3;font-size:13px;line-height:1.5}
.restartbar b{color:#ffd684}
.restartbar code{font-family:"JetBrains Mono",Consolas,monospace;font-size:12px}
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

  <div class="restartbar" id="restart-banner" style="display:none"></div>

  <div class="tabs">
    <button class="tab active" data-view="overview" onclick="switchView('overview')">ภาพรวม</button>
    <button class="tab" data-view="settings" onclick="switchView('settings')">ตั้งค่า tweak</button>
    <button class="tab" data-view="live" onclick="switchView('live')">กราฟสด</button>
    <button class="tab" data-view="backups" onclick="switchView('backups')">ประวัติ/ย้อนกลับ</button>
    <button class="tab" data-view="gpu" onclick="switchView('gpu')">GPU ต่อแอป</button>
  </div>

  <div class="view active" id="view-overview">
    <div class="grid cols" id="hw"></div>

    <div class="section" id="advice-section" style="display:none">
      <h3>คำแนะนำสำหรับเครื่องนี้</h3>
      <div class="card" id="advice"></div>
    </div>

    <div class="section">
      <h3>โปรไฟล์</h3>
      <div class="grid cols" id="profiles"></div>
      <p class="hint" style="margin-top:10px">ปุ่ม “Dry run” ไม่แก้อะไรเลย · ปุ่ม “Apply” ต้องรันหน้านี้จาก PowerShell แบบ Administrator</p>
    </div>

    <div class="toolbar">
      <button onclick="loadStatus()">↻ รีเฟรชสถานะ</button>
      <button onclick="runAudit()">ตรวจ audit (performance)</button>
      <button onclick="runBench()">วัดประสิทธิภาพ (bench)</button>
      <button onclick="runCompare()">วัด + เทียบกับครั้งก่อน</button>
      <button onclick="runLatency()">วัด latency (DPC)</button>
      <button onclick="checkUpdate()">ตรวจอัปเดต</button>
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

  <div class="view" id="view-settings">
    <div class="searchbar">
      <input type="text" id="search" placeholder="ค้นหา tweak (id หรือชื่อ)…" oninput="renderTweaks()">
      <select id="catfilter" onchange="renderTweaks()"><option value="">ทุกหมวด</option></select>
      <select id="preset" onchange="applyPreset(this.value)">
        <option value="">— เลือกตามโปรไฟล์ —</option>
        <option value="balanced">สมดุล (balanced)</option>
        <option value="performance">ประสิทธิภาพ (performance)</option>
        <option value="gaming">เกมมิ่ง (gaming)</option>
        <option value="max">สูงสุด (max)</option>
        <option value="battery">ประหยัดแบต (battery)</option>
      </select>
      <button onclick="selectAll(true)">เลือกทั้งหมดที่แสดง</button>
      <button onclick="selectAll(false)">ล้าง</button>
      <label class="hint" style="display:flex;gap:6px;align-items:center;margin-left:auto">
        <input type="checkbox" id="includeHigh" style="accent-color:var(--warn)"> รวม High risk
      </label>
    </div>
    <div class="twlist" id="twlist"></div>
    <p class="selinfo" id="selinfo">เลือกแล้ว 0 รายการ</p>
    <div class="toolbar" style="margin-top:12px">
      <button onclick="saveSelection()">บันทึกที่เลือก</button>
      <button onclick="auditSelection()">ตรวจสถานะที่เลือก</button>
      <button onclick="applySelection(true)">Dry run ที่เลือก</button>
      <button class="primary" onclick="applySelection(false)">Apply ที่เลือก</button>
      <button onclick="loadTweaks()">โหลดใหม่</button>
      <span class="hint">บันทึกแล้วใช้ CLI: <code>.\Level51Tune.ps1 apply -Custom</code></span>
    </div>
  </div>

  <div class="view" id="view-live">
    <div class="chartgrid">
      <div class="chart"><div class="top"><span class="name">CPU load</span><span class="val" id="v-cpu">–</span></div><canvas id="c-cpu"></canvas></div>
      <div class="chart"><div class="top"><span class="name">CPU clock</span><span class="val" id="v-clock">–</span></div><canvas id="c-clock"></canvas></div>
      <div class="chart"><div class="top"><span class="name">GPU temp</span><span class="val" id="v-temp">–</span></div><canvas id="c-temp"></canvas></div>
      <div class="chart"><div class="top"><span class="name">GPU power</span><span class="val" id="v-power">–</span></div><canvas id="c-power"></canvas></div>
      <div class="chart"><div class="top"><span class="name">RAM used</span><span class="val" id="v-ram">–</span></div><canvas id="c-ram"></canvas></div>
      <div class="chart"><div class="top"><span class="name">GPU clock</span><span class="val" id="v-gclock">–</span></div><canvas id="c-gclock"></canvas></div>
    </div>
    <p class="hint" style="margin-top:10px">อัปเดตทุก 2 วินาที · เก็บย้อนหลัง 60 จุด (~2 นาที) · ข้อมูลจาก performance counter และ nvidia-smi</p>
  </div>

  <div class="view" id="view-backups">
    <p class="hint">ทุกครั้งที่ apply ระบบจะเขียน snapshot ไว้ใน <code>backups/</code> — เลือกไฟล์เพื่อย้อนกลับเฉพาะครั้งนั้น (เฉพาะไฟล์ <code>*_apply-*.json</code> ที่ย้อนกลับได้)</p>
    <div class="twlist" style="max-height:440px" id="backlist"></div>
    <div class="toolbar"><button onclick="loadBackups()">↻ โหลดใหม่</button></div>
  </div>

  <div class="view" id="view-gpu">
    <div class="searchbar">
      <input type="text" id="gpu-path" list="proclist" placeholder="C:\Program Files\Game\game.exe" style="min-width:340px">
      <datalist id="proclist"></datalist>
      <select id="gpu-mode">
        <option value="dgpu">ใช้ GTX 1060 (dgpu)</option>
        <option value="igpu">ใช้ UHD 630 (igpu)</option>
        <option value="auto">ให้ Windows เลือก (auto)</option>
      </select>
      <button class="primary" onclick="addGpuPref()">ตั้งค่า</button>
      <button onclick="loadProcesses()">รายการโปรเซส</button>
    </div>
    <div class="twlist" style="max-height:440px" id="gpulist"></div>
    <p class="hint">เขียนที่ <code>HKCU\Software\Microsoft\DirectX\UserGpuPreferences</code> (ผู้ใช้ปัจจุบัน ไม่ต้อง admin) · มีผลหลังปิด-เปิดแอปนั้น</p>
  </div>
</div>

<div class="toast" id="toast"></div>

<script>
const TOKEN = "__TOKEN__";
let TW = [];
const SEL = new Set();

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

function switchView(name){
  document.querySelectorAll('.view').forEach(v => v.classList.toggle('active', v.id === 'view-' + name));
  document.querySelectorAll('.tab').forEach(t => t.classList.toggle('active', t.dataset.view === name));
  if (name === 'live') loadLive();
  if (name === 'settings' && TW.length === 0) loadTweaks();
  if (name === 'backups') loadBackups();
  if (name === 'gpu') loadGpuPrefs();
}

async function loadStatus(){
  busy(true, 'กำลังอ่านสถานะ…');
  try {
    const d = await api('/api/status');
    document.getElementById('machine').textContent =
      d.model + ' · ' + d.os + ' · ' + d.computer;
    const bs = document.getElementById('badge-scheme');
    bs.textContent = d.state ? 'scheme: ' + d.state.profile : 'scheme: –';
    bs.className = 'badge ' + (d.state ? 'ok' : '');
    const ba = document.getElementById('badge-admin');
    ba.textContent = 'admin: ' + (d.admin ? 'ใช่' : 'ไม่');
    ba.className = 'badge ' + (d.admin ? 'ok' : 'warn');

    const rbar = document.getElementById('restart-banner');
    if (d.state && d.state.rebootPending) {
      rbar.style.display = 'flex';
      rbar.innerHTML = '<span>⚠</span><span><b>ต้องรีสตาร์ทเครื่อง</b> ค่าบางรายการจะยังไม่เต็มที่จนกว่าจะ restart: <code>' +
        esc((d.state.rebootTweaks || []).join(', ')) + '</code><br><span class="hint">รัน <code>Restart-Computer</code> ใน PowerShell — ถ้าปิดเครื่องแล้วค่าไม่ติด ให้ปิด Fast Startup ก่อน</span></span>';
    } else { rbar.style.display = 'none'; rbar.innerHTML = ''; }

    const g = d.gpu;
    const hw = [
      { t: 'CPU', a: esc(d.cpu.replace(/\(R\)|\(TM\)|CPU @/g,'')), b: d.cores + 'C / ' + d.threads + 'T' },
      { t: 'RAM', a: d.ram.toFixed(1) + ' GB', b: 'ว่าง ' + d.ramFree.toFixed(1) + ' GB' },
      { t: 'GPU', a: g ? esc(g.name) : '—', b: g ? (g.clock + ' MHz · ' + g.temp + '°C · ' + g.power + ' W') : '' },
      { t: 'ดิสก์', a: d.disks.length ? esc(d.disks[0].name).slice(0,28) : '—', b: d.disks.length ? (d.disks[0].gb + ' GB · ' + d.disks[0].bus) : '' },
      { t: 'โปรไฟล์ล่าสุด', a: d.state ? esc(d.state.profile) : 'ยังไม่ apply', b: d.state ? new Date(d.state.appliedAt).toLocaleString('th-TH') : '—' }
    ];
    const adv = d.advice;
    if (adv){
      let li = '';
      (adv.warnings || []).forEach(w => { li += '<div class="kv" style="color:var(--warn)"><span>!</span><span>' + esc(w) + '</span></div>'; });
      (adv.notes || []).forEach(n => { li += '<div class="kv"><span>•</span><span>' + esc(n) + '</span></div>'; });
      document.getElementById('advice').innerHTML =
        '<div class="kv" style="margin-bottom:6px"><span>โปรไฟล์ที่แนะนำ</span><span style="color:var(--accent);font-weight:600">' +
        esc(adv.profile) + ' — ' + esc(adv.profileTitle) + '</span></div>' + li;
      document.getElementById('advice-section').style.display = 'block';
    }

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

function resultTable(d, title, note){
  const rows = d.results.map(r =>
    '<tr><td>' + esc(r.id) + '</td><td class="' + r.status + '">' + r.status + '</td><td class="hint">' + esc(r.detail) + '</td></tr>'
  ).join('');
  const counts = d.results.reduce((a, r) => (a[r.status] = (a[r.status] || 0) + 1, a), {});
  showResult(title + (d.backup ? ' · backup: ' + d.backup.split('\\').pop() : ''),
    '<table><thead><tr><th>Tweak</th><th>สถานะ</th><th>รายละเอียด</th></tr></thead><tbody>' + rows + '</tbody></table>' +
    '<div style="padding:10px 12px" class="hint">' + Object.keys(counts).map(k => k + ': ' + counts[k]).join(' · ') + (note ? ' — ' + note : '') + '</div>');
  return counts;
}

async function applyProfile(profile, dry){
  const msg = dry ? 'Dry run' : 'Apply';
  if (!dry && !confirm('Apply โปรไฟล์ ' + profile + ' ?\n\nจะมีการสำรองสถานะก่อนทุกครั้ง และย้อนกลับได้ด้วยปุ่ม restore')) return;
  busy(true, msg + ' ' + profile + '…');
  try {
    const d = await api('/api/apply', { profile: profile, dryRun: dry, includeHigh: false });
    const counts = resultTable(d, msg + ' · ' + profile);
    toast(msg + ' เสร็จ: ' + JSON.stringify(counts));
    if (d.restartRequired && d.restartRequired.length) {
      toast('ต้องรีสตาร์ทเครื่อง: ' + d.restartRequired.join(', '), true);
    }
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

async function runCompare(){
  busy(true, 'กำลังวัดและเทียบกับครั้งก่อน…');
  try {
    const d = await api('/api/compare', { seconds: 3 });
    if (!d.pairs || d.pairs.length === 0){
      showResult('เทียบผล', '<div style="padding:12px" class="hint">ต้องมีผลอย่างน้อย 2 ครั้งในประวัติ — กด “วัดประสิทธิภาพ” อีกครั้งแล้วลองใหม่</div>');
      toast('ยังมีผลไม่พอสำหรับการเทียบ', true);
      return;
    }
    const rows = d.pairs.map(p => {
      const cls = p.delta > 1 ? 'pos' : (p.delta < -1 ? 'neg' : '');
      return '<tr><td>' + esc(p.metric) + '</td><td>' + p.a + '</td><td>' + p.b + '</td>' +
        '<td class="' + cls + '">' + (p.delta > 0 ? '+' : '') + p.delta + '%</td></tr>';
    }).join('');
    const from = d.pairs[0].from, to = d.pairs[0].to;
    showResult('เทียบ · ' + esc(from) + ' → ' + esc(to),
      '<table><thead><tr><th>ตัวชี้วัด</th><th>ก่อน</th><th>หลัง</th><th>Δ</th></tr></thead><tbody>' + rows + '</tbody></table>' +
      '<div style="padding:10px 12px" class="hint">noise ±3-5% — ตัวเลขที่ต่างน้อยกว่านั้นถือว่าไม่ต่าง</div>');
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

async function checkUpdate(){
  busy(true, 'กำลังตรวจเวอร์ชันบน GitHub…');
  try {
    const d = await api('/api/update');
    if (d.error){
      showResult('ตรวจอัปเดต', '<div style="padding:12px" class="hint">ตรวจไม่ได้: ' + esc(d.error) + '<br>คำสั่งอื่นทั้งหมดทำงานแบบ offline — ต้องต่ออินเทอร์เน็ตเพื่อตรวจเวอร์ชัน</div>');
      toast('ตรวจอัปเดตไม่ได้ (ออฟไลน์?)', true);
      return;
    }
    const rows = '<tr><td>เวอร์ชันในเครื่อง</td><td>' + esc(d.local) + '</td></tr>' +
      '<tr><td>ล่าสุดบน GitHub</td><td>' + esc(d.latest || '—') + '</td></tr>' +
      '<tr><td>เผยแพร่</td><td>' + (d.publishedAt ? new Date(d.publishedAt).toLocaleString('th-TH') : '—') + '</td></tr>';
    const tail = d.upToDate
      ? '<div class="hint" style="padding:10px 12px;color:var(--ok)">เป็นเวอร์ชันล่าสุดแล้ว</div>'
      : '<div style="padding:10px 12px" class="hint">มีเวอร์ชันใหม่: <a href="' + esc(d.url || '#') + '" target="_blank" rel="noopener">' + esc(d.url || '') + '</a></div>';
    showResult('ตรวจอัปเดต', '<table><thead><tr><th>รายการ</th><th>ค่า</th></tr></thead><tbody>' + rows + '</tbody></table>' + tail);
    toast(d.upToDate ? 'เป็นเวอร์ชันล่าสุด' : 'มีเวอร์ชันใหม่บน GitHub');
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function loadLog(){
  try {
    const d = await api('/api/log');
    document.getElementById('log').textContent = d.log || '—';
  } catch(e){ /* เงียบ */ }
}

/* ---------------- settings (tweak รายตัว) ---------------- */

async function loadTweaks(){
  try {
    const d = await api('/api/tweaks');
    TW = d.rows;
    SEL.clear();
    (d.saved || []).forEach(id => SEL.add(id));
    const cats = Array.from(new Set(TW.map(t => t.category))).sort();
    const sel = document.getElementById('catfilter');
    sel.innerHTML = '<option value="">ทุกหมวด</option>' + cats.map(c => '<option value="' + esc(c) + '">' + esc(c) + '</option>').join('');
    renderTweaks();
  } catch(e){ toast(e.message, true); }
}

function visibleTweaks(){
  const q = document.getElementById('search').value.trim().toLowerCase();
  const cat = document.getElementById('catfilter').value;
  return TW.filter(t => {
    if (cat && t.category !== cat) return false;
    if (!q) return true;
    return (t.id + ' ' + t.title + ' ' + t.titleTh + ' ' + t.notes).toLowerCase().includes(q);
  });
}

function renderTweaks(){
  const list = visibleTweaks();
  let html = '', lastCat = '';
  list.forEach(t => {
    if (t.category !== lastCat){
      html += '<div class="catrow">' + esc(t.category) + '</div>';
      lastCat = t.category;
    }
    const checked = SEL.has(t.id) ? ' checked' : '';
    html += '<label class="tw">' +
      '<input type="checkbox"' + checked + ' onchange="toggle(\'' + t.id + '\', this.checked)">' +
      '<span><span class="t">' + esc(t.titleTh || t.title) + '</span>' +
      '<span class="r ' + t.risk + '">' + t.risk + '</span>' +
      (t.reboot ? '<span class="r">reboot</span>' : '') + '</span>' +
      '<span class="d" style="margin-left:auto">' + esc(t.id) + '</span>' +
      '</label>';
  });
  document.getElementById('twlist').innerHTML = html || '<div style="padding:14px" class="hint">ไม่พบ tweak ที่ตรงกับคำค้น</div>';
  updateSelInfo();
}

function updateSelInfo(){
  const high = TW.filter(t => SEL.has(t.id) && t.risk === 'High').length;
  document.getElementById('selinfo').textContent =
    'เลือกแล้ว ' + SEL.size + ' รายการ' + (high ? ' (High risk ' + high + ' — ต้องติ๊ก “รวม High risk” ตอน apply)' : '');
}

function toggle(id, on){
  if (on) { SEL.add(id); } else { SEL.delete(id); }
  updateSelInfo();
}

function selectAll(on){
  if (on) { visibleTweaks().forEach(t => SEL.add(t.id)); }
  else { SEL.clear(); }
  renderTweaks();
}

function applyPreset(profile){
  if (!profile) return;
  SEL.clear();
  TW.filter(t => (t.profiles || []).includes(profile) && t.risk !== 'High').forEach(t => SEL.add(t.id));
  renderTweaks();
  toast('เลือก tweaks ของโปรไฟล์ ' + profile + ' แล้ว (' + SEL.size + ' รายการ)');
}

async function saveSelection(){
  try {
    const d = await api('/api/settings', { tweakIds: Array.from(SEL) });
    toast('บันทึกแล้ว ' + d.count + ' รายการ (state/custom.json)');
  } catch(e){ toast(e.message, true); }
}

async function applySelection(dry){
  const ids = Array.from(SEL);
  if (ids.length === 0) { toast('ยังไม่ได้เลือก tweak', true); return; }
  const high = document.getElementById('includeHigh').checked;
  if (!dry && !confirm('Apply ' + ids.length + ' tweaks ที่เลือก?' + (high ? '\n\nรวม High risk ด้วย — อาจต้อง reboot' : ''))) return;
  busy(true, (dry ? 'Dry run' : 'Apply') + ' ' + ids.length + ' tweaks…');
  try {
    const d = await api('/api/apply', { tweakIds: ids, dryRun: dry, includeHigh: high });
    switchView('overview');
    const counts = resultTable(d, (dry ? 'Dry run' : 'Apply') + ' · ที่เลือกเอง (' + ids.length + ')');
    toast((dry ? 'Dry run' : 'Apply') + ' เสร็จ: ' + JSON.stringify(counts));
    if (d.restartRequired && d.restartRequired.length) {
      toast('ต้องรีสตาร์ทเครื่อง: ' + d.restartRequired.join(', '), true);
    }
    loadStatus(); loadLog();
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

async function auditSelection(){
  const ids = Array.from(SEL);
  if (ids.length === 0) { toast('ยังไม่ได้เลือก tweak', true); return; }
  busy(true, 'กำลังตรวจสถานะ ' + ids.length + ' tweaks…');
  try {
    const d = await api('/api/audit', { tweakIds: ids });
    const rows = d.rows.map(r =>
      '<tr><td>' + esc(r.id) + '</td><td>' + esc(r.category) + '</td><td>' + esc(r.risk) + '</td>' +
      '<td class="' + (r.applied === 'YES' ? 'yes' : r.applied === '?' ? 'na' : 'no') + '">' + r.applied + '</td>' +
      '<td class="hint">' + esc(r.title) + '</td></tr>'
    ).join('');
    switchView('overview');
    showResult('สถานะ tweaks ที่เลือก — ปรับแล้ว ' + d.done + ' / ' + d.total,
      '<table><thead><tr><th>Tweak</th><th>หมวด</th><th>Risk</th><th>สถานะ</th><th>รายละเอียด</th></tr></thead><tbody>' + rows + '</tbody></table>');
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

/* ---------------- backups / rollback ---------------- */

let BACKUPS = [];

async function loadBackups(){
  const box = document.getElementById('backlist');
  try {
    const d = await api('/api/backups');
    BACKUPS = d.rows || [];
    if (BACKUPS.length === 0){
      box.innerHTML = '<div style="padding:14px" class="hint">ยังไม่มี backup — จะถูกสร้างอัตโนมัติเมื่อ apply ครั้งแรก</div>';
      return;
    }
    box.innerHTML = BACKUPS.map((b, i) =>
      '<div class="tw" style="cursor:default">' +
        '<span class="t">' + esc(b.profile || 'snapshot') +
        (b.restorable ? '' : '<span class="r">อ่านอย่างเดียว</span>') + '</span>' +
        '<span class="d" style="margin-left:auto">' + new Date(b.created).toLocaleString('th-TH') +
          ' · ' + b.tweaks + ' tweaks · ' + b.sizeKB + ' KB</span>' +
        (b.restorable ? '<button style="margin-left:12px" onclick="restoreBackup(' + i + ')">ย้อนกลับ</button>' : '') +
      '</div>'
    ).join('');
  } catch(e){ toast(e.message, true); }
}

async function restoreBackup(i){
  const b = BACKUPS[i];
  if (!b) return;
  const info = b.profile + ' · ' + new Date(b.created).toLocaleString('th-TH') + ' · ' + b.file;
  if (!confirm('ย้อนกลับจาก backup นี้? ' + info)) return;
  busy(true, 'กำลัง restore…');
  try {
    const d = await api('/api/restore', { backupPath: b.path });
    const rows = d.results.map(r => '<tr><td>' + esc(r.id) + '</td><td class="' + esc(r.status) + '">' + esc(r.status) + '</td><td class="hint">' + esc(r.detail) + '</td></tr>').join('');
    switchView('overview');
    showResult('Restore · ' + esc(b.file), '<table><thead><tr><th>Tweak</th><th>สถานะ</th><th>รายละเอียด</th></tr></thead><tbody>' + rows + '</tbody></table>');
    toast('restore เสร็จ');
    loadStatus(); loadLog();
  } catch(e){ toast(e.message, true); }
  finally { busy(false); }
}

/* ---------------- per-app GPU preference ---------------- */

let GPUP = [];

async function loadGpuPrefs(){
  const box = document.getElementById('gpulist');
  try {
    const d = await api('/api/gpu-prefs');
    GPUP = d.rows || [];
    if (GPUP.length === 0){
      box.innerHTML = '<div style="padding:14px" class="hint">ยังไม่มีรายการ — ใส่ path ของ .exe ด้านบนหรือกด “รายการโปรเซส”</div>';
      return;
    }
    box.innerHTML = GPUP.map((r, i) => {
      const name = r.path.split('\\').pop();
      return '<div class="tw" style="cursor:default">' +
        '<span class="t">' + esc(name) + '<span class="r ' + (r.mode === 'dgpu' ? 'Medium' : '') + '">' + r.mode + '</span></span>' +
        '<span class="d" style="margin-left:auto">' + esc(r.path) + '</span>' +
        '<button style="margin-left:12px" onclick="removeGpuPref(' + i + ')">ลบ</button>' +
      '</div>';
    }).join('');
  } catch(e){ toast(e.message, true); }
}

async function addGpuPref(){
  const p = document.getElementById('gpu-path').value.trim();
  const m = document.getElementById('gpu-mode').value;
  if (!p) { toast('ใส่ path ของไฟล์ .exe ก่อน', true); return; }
  try {
    const d = await api('/api/gpu-prefs', { action: 'set', path: p, mode: m });
    toast('ตั้งค่าแล้ว: ' + d.path.split('\\').pop() + ' → ' + d.mode);
    document.getElementById('gpu-path').value = '';
    loadGpuPrefs();
  } catch(e){ toast(e.message, true); }
}

async function removeGpuPref(i){
  const r = GPUP[i];
  if (!r) return;
  if (!confirm('ลบการตั้งค่า GPU ของ ' + r.path + ' ?')) return;
  try {
    await api('/api/gpu-prefs', { action: 'remove', path: r.path });
    toast('ลบแล้ว');
    loadGpuPrefs();
  } catch(e){ toast(e.message, true); }
}

async function loadProcesses(){
  try {
    const d = await api('/api/processes');
    document.getElementById('proclist').innerHTML = (d.rows || []).map(p =>
      '<option value="' + esc(p.path) + '">' + esc(p.name) + '</option>').join('');
    toast('โหลด ' + (d.rows || []).length + ' โปรเซส — พิมพ์ในช่องเพื่อเลือก');
  } catch(e){ toast(e.message, true); }
}

/* ---------------- live charts ---------------- */

const HIST = { cpu: [], clock: [], temp: [], power: [], ram: [], gclock: [] };
const MAXPTS = 60;

function push(arr, v){ arr.push(v == null || isNaN(v) ? null : Number(v)); if (arr.length > MAXPTS) arr.shift(); }

function drawChart(id, arr, color, unit){
  const c = document.getElementById(id);
  if (!c) return;
  const dpr = window.devicePixelRatio || 1;
  const w = c.clientWidth || 260, h = c.clientHeight || 70;
  if (c.width !== Math.round(w * dpr)) { c.width = Math.round(w * dpr); c.height = Math.round(h * dpr); }
  const ctx = c.getContext('2d');
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, w, h);
  const vals = arr.filter(v => v != null);
  ctx.strokeStyle = 'rgba(139,152,169,.18)';
  ctx.lineWidth = 1;
  for (let i = 1; i < 4; i++){
    const y = (h / 4) * i;
    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
  }
  if (vals.length < 2) return;
  let min = Math.min.apply(null, vals), max = Math.max.apply(null, vals);
  if (max - min < 1e-6) { max = min + 1; }
  const pad = (max - min) * 0.15;
  min -= pad; max += pad;
  const stepX = arr.length > 1 ? w / (MAXPTS - 1) : w;
  const x0 = w - (arr.length - 1) * stepX;
  ctx.beginPath();
  let started = false;
  arr.forEach((v, i) => {
    if (v == null) { started = false; return; }
    const x = x0 + i * stepX;
    const y = h - ((v - min) / (max - min)) * h;
    if (!started) { ctx.moveTo(x, y); started = true; } else { ctx.lineTo(x, y); }
  });
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.8;
  ctx.lineJoin = 'round';
  ctx.stroke();
  const lastIdx = arr.length - 1;
  if (arr[lastIdx] != null){
    const x = x0 + lastIdx * stepX;
    const y = h - ((arr[lastIdx] - min) / (max - min)) * h;
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(x, y, 2.6, 0, Math.PI * 2); ctx.fill();
  }
}

function setVal(id, v, unit){
  document.getElementById(id).textContent = (v == null || isNaN(v)) ? '–' : (Math.round(v * 10) / 10) + (unit || '');
}

async function loadLive(){
  try {
    const d = await api('/api/live');
    const g = d.gpu || {};
    push(HIST.cpu, d.cpuLoadPct);
    push(HIST.clock, d.cpuClockMHz);
    push(HIST.temp, g.temp);
    push(HIST.power, g.power);
    push(HIST.ram, d.ramUsedGB);
    push(HIST.gclock, g.clockMHz);
    setVal('v-cpu', d.cpuLoadPct, '%');
    setVal('v-clock', d.cpuClockMHz, ' MHz');
    setVal('v-temp', g.temp, '°C');
    setVal('v-power', g.power, ' W');
    setVal('v-ram', d.ramUsedGB, ' GB');
    setVal('v-gclock', g.clockMHz, ' MHz');
    drawChart('c-cpu', HIST.cpu, '#4cc2a0', '%');
    drawChart('c-clock', HIST.clock, '#63a8f0', 'MHz');
    drawChart('c-temp', HIST.temp, '#f0b429', '°C');
    drawChart('c-power', HIST.power, '#ef6b73', 'W');
    drawChart('c-ram', HIST.ram, '#a78bfa', 'GB');
    drawChart('c-gclock', HIST.gclock, '#7dd3fc', 'MHz');
  } catch(e){ /* เงียบ — อย่ารบกวนผู้ใช้ทุก 2 วินาที */ }
}

/* ปุ่มพวกนี้ไม่ถูก disable ระหว่างงาน */
document.querySelectorAll('button').forEach(b => { if (b.textContent.includes('โหลดใหม่')) b.dataset.keep = '1'; });

loadStatus();
loadLog();
setInterval(loadLog, 15000);
setInterval(() => { if (document.getElementById('view-live').classList.contains('active')) loadLive(); }, 2000);
</script>
</body>
</html>
'@
}
