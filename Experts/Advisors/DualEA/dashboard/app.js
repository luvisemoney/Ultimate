let snapshot = null;
let policy = null;
const $ = id => document.getElementById(id);
const number = value => typeof value === 'number' && Number.isFinite(value);
const money = value => number(value) ? new Intl.NumberFormat('en-CA', {style:'currency', currency:'USD'}).format(value) : '—';
const sum = (rows, key) => rows.reduce((total, row) => total + (number(row[key]) ? row[key] : 0), 0);
const stamp = value => value ? new Date(typeof value === 'number' ? value * 1000 : value).toLocaleString('en-CA', {timeZone:'America/Toronto', timeZoneName:'short'}) : 'Unknown';
function text(tag, value, className) { const e = document.createElement(tag); e.textContent = value; if(className) e.className = className; return e; }
function cell(row, value, className) { row.append(text('td', value, className)); }
function filtered(rows) { return (rows || []).filter(row => $('symbol').value === '*' || row.symbol === $('symbol').value); }
function empty(body, columns, message) { const row = document.createElement('tr'); const c=text('td',message,'empty');c.colSpan=columns;row.append(c);body.append(row); }
function renderExecution() {
  const benchmark = filtered(snapshot.benchmark?.rows), paper = filtered(snapshot.paper?.rows);
  const b=$('benchmark-table'), p=$('paper-table'), chart=$('profit-chart');b.replaceChildren();p.replaceChildren();chart.replaceChildren();
  for(const item of paper) {const row=document.createElement('tr');cell(row,item.symbol);cell(row,item.trades);cell(row,money(item.net_profit),item.net_profit<0?'negative':'positive');cell(row,number(item.profit_factor)?item.profit_factor.toFixed(2):'—');p.append(row);}
  if(!paper.length) empty(p,4,'No actual EA result for this selection.');
  const limit=Math.max(1,...benchmark.flatMap(row=>[Math.abs(row.net_profit||0),Math.abs(row.net_after_stress_costs||0)]));
  for(const item of benchmark) {
    const row=document.createElement('tr');cell(row,item.symbol);cell(row,item.entries_filled);cell(row,item.wins);cell(row,money(item.net_profit),item.net_profit<0?'negative':'positive');cell(row,money(item.net_after_stress_costs),item.net_after_stress_costs<0?'negative':'positive');cell(row,number(item.equity_drawdown_pct)?`${item.equity_drawdown_pct.toFixed(2)}%`:'—');cell(row,item.request_failures);b.append(row);
    const line=text('div','', 'chart-row');line.append(text('span',item.symbol));const track=text('div','','chart-track');
    for(const [key,cl] of [['net_profit','first'],['net_after_stress_costs','second']]) { const value=item[key];if(!number(value))continue;const bar=text('span','',`chart-bar ${cl}`);const width=Math.abs(value)/limit*48;bar.style.width=`${width}%`;bar.style.left=`${value<0?50-width:50}%`;bar.title=`${item.symbol}: ${money(value)}`;track.append(bar); }
    line.append(track,text('span',money(item.net_profit),'chart-value'));chart.append(line);
  }
  if(!benchmark.length) {empty(b,7,'No benchmark evidence for this selection.');chart.append(text('p','No result loaded.','empty'));}
}
function renderNews() {
  const body=$('news-table');body.replaceChildren();const query=$('news-search').value.trim().toLowerCase();
  const rows=(snapshot.news||[]).filter(row=>`${row.headline} ${row.target}`.toLowerCase().includes(query)).sort((a,b)=>b.published_utc-a.published_utc);
  for(const item of rows) {
    const row=document.createElement('tr');cell(row,item.target);const c=text('td','','headline');
    try {const url=new URL(item.source_url);if(url.protocol!=='https:')throw new Error();const link=text('a',item.headline);link.href=url.href;link.target='_blank';link.rel='noopener noreferrer';c.append(link,text('small',`${url.hostname} · ${stamp(item.published_utc)}`));} catch {c.append(text('span',item.headline));}
    row.append(c);cell(row,['Unknown','Low','Medium','High'][item.impact]||'Unknown');cell(row,number(item.rule_score)?item.rule_score.toFixed(2):'—');const fresh=item.expires_utc>Date.now()/1000;const state=text('td','');state.append(text('span',fresh?'Fresh':'Expired',`pill ${fresh?'green':'amber'}`));row.append(state);body.append(row);
  }
  if(!rows.length) empty(body,5,'No matching timestamped headline context.');
}
function render() {
  const model=snapshot.model||{}, v=model.verification||{}, b=snapshot.benchmark?.rows||[], p=snapshot.paper?.rows||[];
  $('model-contract').textContent=v.feature_count?`${v.feature_count} inputs`:'Unknown';$('model-detail').textContent=v.symbol_count?`${v.symbol_count} symbols · H1 · native ONNX`:'No model proof loaded';
  $('model-state').textContent=v.native_parity==='PASS'?'Native parity passed':'Not verified';$('model-state').className=`pill ${v.native_parity==='PASS'?'green':'amber'}`;
  $('paper-trades').textContent=p.length?sum(p,'trades').toLocaleString():'—';$('paper-net').textContent=p.length?`${money(sum(p,'net_profit'))} across independent EA tests`:'No actual EA test result';
  $('benchmark-net').textContent=b.length?`${money(sum(b,'net_profit'))} across ${b.length} benchmark runs`:'No benchmark result';$('profit-state').textContent=b.length&&sum(b,'net_profit')<0?'Negative test result':'Not established';$('profit-state').className=b.length&&sum(b,'net_profit')<0?'negative':'';
  const live=(snapshot.live_observations||[]).filter(row=>row.complete).at(-1);$('latency').textContent=live?`${live.max_handler_ms.toFixed(3)} ms`:'Unmeasured';$('latency-detail').textContent=live?`${live.symbol} · ${live.handler_samples} callbacks · ${stamp(live.collected_utc)}`:'No completed demo observation';
  $('updated').textContent=`Snapshot exported ${stamp(snapshot.exported_utc)} · timezone: Ottawa / Toronto`;
  const age=Date.now()-Date.parse(snapshot.exported_utc);$('freshness').textContent=age>30*60*1000?'Older snapshot':'Snapshot loaded';$('freshness').className=`pill ${age>30*60*1000?'amber':'green'}`;
  const oldSelection=$('symbol').value;const symbols=[...new Set([...b,...p].map(row=>row.symbol))].sort();$('symbol').replaceChildren(new Option('All symbols','*'),...symbols.map(symbol=>new Option(symbol,symbol)));if(symbols.includes(oldSelection))$('symbol').value=oldSelection;
  const ff=snapshot.forex_factory?.verification||{};$('feed-counts').replaceChildren(...[['Calendar',ff.calendar_rows],['FF headlines',ff.news_rows],['Forum excerpts',ff.forum_rows],['Public activity',ff.activity_rows],['Positioning',ff.positioning_rows]].map(([name,value])=>text('span',`${name}: ${number(value)?value:'unknown'}`)));
  const policies=policy?.policies||policy?.slices||[];$('policy-count').textContent=`${policies.length} policy entries · read only`;$('policy-json').textContent=JSON.stringify(policy,null,2);
  const evidence=[['Model SHA-256',v.model_sha256||'Unknown'],['Current EA build',model.tested_ea_matches?'Matches integration proof':'Not matched to current integration proof'],['Integration classifications',model.integration?.classification_events??'Unknown'],['Feed delivery latency','UNMEASURED'],['Profitability','NOT PROVEN'],['Calendar coverage',`${ff.calendar_rows??'Unknown'} exported events; no invented actual/forecast surprises`],['Collector verification',ff.verified_utc?stamp(ff.verified_utc):'Unknown'],['Policy source timestamp',policy?.snapshot_meta?.source_modified_utc?stamp(policy.snapshot_meta.source_modified_utc):'Unknown']];
  $('evidence-list').replaceChildren(...evidence.flatMap(([key,value])=>[text('dt',key),text('dd',String(value))]));renderExecution();renderNews();
}
async function refresh() {
  $('refresh').disabled=true;$('error').hidden=true;
  try {
    const responses=await Promise.all(['./data/status.json','./policy.json'].map(path=>fetch(new URL(path,document.baseURI),{cache:'no-store'})));
    if(responses.some(response=>!response.ok))throw new Error('Published data could not be fetched. Check the deployment and data paths.');
    [snapshot,policy]=await Promise.all(responses.map(response=>response.json()));
    if(snapshot.schema_version!==1 || !snapshot.exported_utc)throw new Error('Unsupported snapshot schema.');render();
  } catch(error) {$('error').textContent=error.message;$('error').hidden=false;$('freshness').textContent='Unavailable';$('freshness').className='pill red';}
  finally {$('refresh').disabled=false;}
}
$('refresh').addEventListener('click',refresh);$('symbol').addEventListener('change',renderExecution);$('news-search').addEventListener('input',()=>snapshot&&renderNews());
$('copy-policy').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(new URL('./policy.json',document.baseURI).href);$('copy-policy').textContent='URL copied';setTimeout(()=>$('copy-policy').textContent='Copy policy URL',1800);}catch{$('copy-policy').textContent='Use Open policy.json to copy its URL';}});
document.querySelectorAll('nav a').forEach(link=>link.addEventListener('click',()=>{document.querySelectorAll('nav a').forEach(a=>a.classList.remove('active'));link.classList.add('active');}));
refresh();setInterval(refresh,60000);
