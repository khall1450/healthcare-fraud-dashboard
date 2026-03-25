$file = 'C:/Users/khall/HealthcareFraudDashboard/www/index.html'
$h = Get-Content $file -Raw -Encoding UTF8

# ── 1. Refresh button → triggerRefresh ──────────────────────────────────────
$h = $h -replace '<button class="btn btn-refresh" id="refreshBtn" onclick="openUpdateInstructions\(\)">',
    '<button class="btn btn-refresh" id="refreshBtn" onclick="triggerRefresh()">'

# ── 2. Remove dollar-sign icon from card-amount ──────────────────────────────
$h = $h -replace '<div class="card-amount d-none"><i class="fa-solid fa-dollar-sign me-1"></i><span></span></div>',
    '<div class="card-amount d-none"><span></span></div>'

# ── 3. Fix stat bar: replace entire row with correct 6-card layout ───────────
$oldStats = '<div class="row g-3 py-3">[\s\S]*?</div>\s*</div>\s*</div>\s*<!-- FILTER BAR'
$newStats = @'
    <div class="row g-3 py-3">
      <div class="col-6 col-md">
        <div class="stat-card stat-card-money" onclick="showStatDetail('audit')" style="cursor:pointer;" title="Click to see breakdown">
          <div class="stat-number" id="statAudit">&mdash;</div>
          <div class="stat-label">Total Improper Payments Identified &mdash; All Agency Audits</div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="stat-card stat-card-money" onclick="showStatDetail('criminal')" style="cursor:pointer;" title="Click to see breakdown">
          <div class="stat-number" id="statCriminal">&mdash;</div>
          <div class="stat-label">Fraud Alleged &mdash; Criminal Cases</div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="stat-card stat-card-money" onclick="showStatDetail('convicted')" style="cursor:pointer;" title="Click to see breakdown">
          <div class="stat-number" id="statConvicted">&mdash;</div>
          <div class="stat-label">Total Fraud Confirmed &mdash; Pleas &amp; Convictions</div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="stat-card stat-card-money" onclick="showStatDetail('civil')" style="cursor:pointer;" title="Click to see breakdown">
          <div class="stat-number" id="statCivil">&mdash;</div>
          <div class="stat-label">Civil Settlements &amp; Recoveries</div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="stat-card stat-card-money" onclick="showStatDetail('largest')" style="cursor:pointer;" title="Click to see breakdown">
          <div class="stat-number" id="statLargest">&mdash;</div>
          <div class="stat-label">Largest Single Enforcement Action</div>
        </div>
      </div>
      <div class="col-6 col-md">
        <div class="stat-card stat-card-money" onclick="showStatDetail('cms')" style="cursor:pointer;" title="Click to see breakdown">
          <div class="stat-number" id="statCMS">&mdash;</div>
          <div class="stat-label">CMS Program Integrity &mdash; Improper Payments Identified or Prevented</div>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- FILTER BAR
'@
$h = [regex]::Replace($h, $oldStats, $newStats, [System.Text.RegularExpressions.RegexOptions]::Singleline)

# ── 4. Replace entire JS section (everything from updateStats through end) ───
$jsStart = $h.IndexOf('function updateStats(actions)')
$scriptEnd = $h.LastIndexOf('</script>')
$before = $h.Substring(0, $jsStart)
$after  = $h.Substring($scriptEnd)

$newJS = @'
const CONVICTED_RE = /plead|guilty|convict|sentenc/i;

function updateStats(actions) {
  const crimTotal = actions
    .filter(a => a.type === 'Criminal Enforcement')
    .reduce((s, a) => s + (a.amount_numeric || 0), 0);

  const convictedTotal = actions
    .filter(a => a.type === 'Criminal Enforcement' && (a.amount_numeric || 0) > 0 && CONVICTED_RE.test(a.title))
    .reduce((s, a) => s + (a.amount_numeric || 0), 0);

  const civilTotal = actions
    .filter(a => a.type === 'Civil Action')
    .reduce((s, a) => s + (a.amount_numeric || 0), 0);

  const largestCriminal = actions
    .filter(a => a.type === 'Criminal Enforcement' && (a.amount_numeric || 0) > 0)
    .reduce((max, a) => Math.max(max, a.amount_numeric), 0);

  const cmsTotal = actions
    .filter(a => a.agency === 'CMS' && a.type === 'Administrative Action' && (a.amount_numeric || 0) > 0)
    .reduce((sum, a) => sum + (a.amount_numeric || 0), 0);

  const auditTotal = actions
    .filter(a => a.type === 'Audit' && (a.amount_numeric || 0) > 0)
    .reduce((sum, a) => sum + (a.amount_numeric || 0), 0);

  document.getElementById('statAudit').textContent     = auditTotal > 0 ? formatMoney(auditTotal) : '\u2014';
  document.getElementById('statCriminal').textContent  = crimTotal > 0 ? formatMoney(crimTotal) : '\u2014';
  document.getElementById('statConvicted').textContent = convictedTotal > 0 ? formatMoney(convictedTotal) : '\u2014';
  document.getElementById('statCivil').textContent     = civilTotal > 0 ? formatMoney(civilTotal) : '\u2014';
  document.getElementById('statLargest').textContent   = largestCriminal > 0 ? formatMoney(largestCriminal) : '\u2014';
  document.getElementById('statCMS').textContent       = cmsTotal > 0 ? formatMoney(cmsTotal) : '\u2014';
}

function applyFilters() {
  const search   = document.getElementById('searchInput').value.trim().toLowerCase();
  const agency   = document.getElementById('agencyFilter').value;
  const type     = document.getElementById('typeFilter').value;
  const state    = document.getElementById('stateFilter').value;
  const dateFrom = document.getElementById('dateFrom').value;
  const dateTo   = document.getElementById('dateTo').value;

  let filtered = allActions.filter(a => {
    if (agency !== 'all' && a.agency !== agency) return false;
    if (type   !== 'all' && a.type   !== type)   return false;
    if (state  !== 'all' && a.state  !== state)  return false;
    if (dateFrom && a.date < dateFrom) return false;
    if (dateTo   && a.date > dateTo)   return false;
    if (search) {
      const hay = [a.title, a.description, a.agency, a.type,
                   (a.tags||[]).join(' '), (a.officials||[]).join(' '),
                   (a.social_posts||[]).map(p=>p.post_text).join(' ')].join(' ').toLowerCase();
      if (!hay.includes(search)) return false;
    }
    return true;
  });

  filtered.sort((a,b) => (b.date||'').localeCompare(a.date||''));
  renderCards(filtered);

  const countEl = document.getElementById('resultCount');
  countEl.textContent = filtered.length === allActions.length
    ? allActions.length + ' actions'
    : filtered.length + ' of ' + allActions.length + ' actions';
}

function clearFilters() {
  document.getElementById('searchInput').value = '';
  document.getElementById('agencyFilter').value = 'all';
  document.getElementById('typeFilter').value   = 'all';
  document.getElementById('stateFilter').value  = 'all';
  document.getElementById('dateFrom').value = '';
  document.getElementById('dateTo').value   = '';
  applyFilters();
}

function populateStateDropdown(actions) {
  const sel = document.getElementById('stateFilter');
  const states = [...new Set(actions.map(a => a.state).filter(Boolean))];
  states.sort((a, b) => (STATE_NAMES[a] || a).localeCompare(STATE_NAMES[b] || b));
  states.forEach(abbr => {
    const opt = document.createElement('option');
    opt.value = abbr;
    opt.textContent = STATE_NAMES[abbr] || abbr;
    sel.appendChild(opt);
  });
}

async function loadData() {
  try {
    const resp = await fetch('data/actions.json?t=' + Date.now());
    if (!resp.ok) throw new Error('Failed to fetch');
    const data = await resp.json();
    allActions = data.actions || [];
    updateLastUpdated(data.metadata && data.metadata.last_updated);
    updateStats(allActions);
    populateStateDropdown(allActions);
    applyFilters();
  } catch (err) {
    console.error('Failed to load data:', err);
    document.getElementById('cardsGrid').innerHTML =
      '<div class="col-12"><div class="alert alert-danger">Could not load data. Make sure the server is running.</div></div>';
  }
}

async function triggerRefresh() {
  const btn = document.getElementById('refreshBtn');
  const icon = btn.querySelector('i');
  btn.disabled = true;
  icon.classList.add('spinning');
  try {
    const resp = await fetch('/api/refresh', { method: 'POST' });
    if (resp.ok) {
      const result = await resp.json();
      await loadData();
      showToast(result.new_actions > 0 ? result.new_actions + ' new action(s) added!' : 'Data is up to date.', result.new_actions > 0 ? 'success' : 'info');
    } else {
      showToast('Refresh failed. Check server.', 'warning');
    }
  } catch {
    await loadData();
    showToast('Reloaded local data.', 'info');
  } finally {
    btn.disabled = false;
    icon.classList.remove('spinning');
  }
}

function showToast(msg, type) {
  const colors = { success: '#1B5E20', info: '#1a3a6b', warning: '#e65100' };
  const toast = document.createElement('div');
  toast.style.cssText = 'position:fixed;bottom:24px;right:24px;z-index:9999;background:' + (colors[type] || colors.info) + ';color:white;padding:12px 20px;border-radius:8px;font-size:0.875rem;box-shadow:0 4px 16px rgba(0,0,0,0.25);max-width:320px;';
  toast.textContent = msg;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 4000);
}

// ── Stat detail popup ──────────────────────────────────────────────────────
const STAT_FILTERS = {
  audit:     { fn: a => a.type === 'Audit',                                                                               label: 'Total Improper Payments Identified — All Agency Audits' },
  criminal:  { fn: a => a.type === 'Criminal Enforcement',                                                                label: 'Fraud Alleged — Criminal Cases' },
  convicted: { fn: a => a.type === 'Criminal Enforcement' && (a.amount_numeric || 0) > 0 && CONVICTED_RE.test(a.title),  label: 'Total Fraud Confirmed — Pleas & Convictions' },
  civil:     { fn: a => a.type === 'Civil Action',                                                                        label: 'Civil Settlements & Recoveries' },
  largest:   { fn: (a, all) => { const max = all.filter(x => x.type === 'Criminal Enforcement' && (x.amount_numeric||0) > 0).reduce((m,x) => x.amount_numeric > m.amount_numeric ? x : m, {amount_numeric:0}); return a === max; }, label: 'Largest Single Enforcement Action' },
  cms:       { fn: a => a.agency === 'CMS' && a.type === 'Administrative Action',                                         label: 'CMS Program Integrity — Improper Payments Identified or Prevented' },
};

function showStatDetail(filterId) {
  const def = STAT_FILTERS[filterId];
  if (!def) return;
  const entries = allActions.filter(a => def.fn(a, allActions)).sort((a, b) => (b.date||'').localeCompare(a.date||''));
  document.getElementById('statModalTitle').textContent = def.label;
  const body = document.getElementById('statModalBody');
  if (entries.length === 0) {
    body.innerHTML = '<p class="text-muted py-3">No entries currently match this calculation.</p>';
  } else {
    const total = entries.reduce((s, a) => s + (a.amount_numeric || 0), 0);
    body.innerHTML =
      (total > 0
        ? '<div style="font-size:0.8rem;color:#666;margin-bottom:12px;">' + entries.length + ' entr' + (entries.length===1?'y':'ies') + ' &bull; Total: <strong>' + formatMoney(total) + '</strong></div>'
        : '<div style="font-size:0.8rem;color:#666;margin-bottom:12px;">' + entries.length + ' entr' + (entries.length===1?'y':'ies') + '</div>') +
      entries.map(a =>
        '<div style="border-bottom:1px solid #eee;padding:12px 0;">' +
          '<div style="display:flex;justify-content:space-between;align-items:flex-start;gap:16px;">' +
            '<div style="min-width:0;">' +
              '<div style="font-weight:600;font-family:\'Bona Nova\',Georgia,serif;font-size:0.95rem;">' + escHtml(a.title||'Untitled') + '</div>' +
              '<div style="font-size:0.78rem;color:#888;margin-top:3px;">' + formatDate(a.date) + '&ensp;&bull;&ensp;' + escHtml(a.agency||'') + '&ensp;&bull;&ensp;' + escHtml(a.type||'') + '</div>' +
              (a.description ? '<div style="font-size:0.82rem;color:#555;margin-top:6px;line-height:1.5;">' + escHtml(a.description.length>250?a.description.substring(0,250)+'…':a.description) + '</div>' : '') +
              (a.link ? '<a href="' + escHtml(a.link) + '" target="_blank" rel="noopener" style="font-size:0.78rem;color:#00A6CF;margin-top:6px;display:inline-block;">View Source \u2197</a>' : '') +
            '</div>' +
            (a.amount ? '<div style="font-weight:700;color:#002E6D;white-space:nowrap;font-size:1rem;flex-shrink:0;">' + escHtml(a.amount) + '</div>' : '') +
          '</div>' +
        '</div>'
      ).join('');
  }
  new bootstrap.Modal(document.getElementById('statModal')).show();
}

// Init
document.addEventListener('DOMContentLoaded', loadData);
'@

$h = $before + $newJS + $after

# ── 5. Add modal HTML and Bootstrap JS before </body> ────────────────────────
$modal = @'

<!-- STAT DETAIL MODAL -->
<div class="modal fade" id="statModal" tabindex="-1" aria-hidden="true">
  <div class="modal-dialog modal-lg modal-dialog-scrollable">
    <div class="modal-content" style="border:none;border-radius:0.3rem;overflow:hidden;">
      <div class="modal-header" style="background:#002E6D;color:white;border:none;">
        <h5 class="modal-title" id="statModalTitle" style="font-family:'Bona Nova',Georgia,serif;font-size:1rem;"></h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body" id="statModalBody" style="padding:16px 20px;"></div>
      <div class="modal-footer" style="border-top:1px solid #eee;">
        <button type="button" class="btn btn-sm btn-secondary" data-bs-dismiss="modal">Close</button>
      </div>
    </div>
  </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
'@
$h = $h -replace '</body>', "$modal`n</body>"

Set-Content $file -Value $h -Encoding UTF8

# Verify
$checks = @('showStatDetail','statModal','bootstrap.bundle','STAT_FILTERS','triggerRefresh','loadData','statConvicted')
foreach ($c in $checks) {
    $found = $h -match [regex]::Escape($c)
    Write-Host "$c : $(if ($found){'OK'}else{'MISSING'})" -ForegroundColor $(if ($found){'Green'}else{'Red'})
}
Write-Host "`nDone." -ForegroundColor Green
