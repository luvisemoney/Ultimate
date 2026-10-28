import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
export const root=path.dirname(fileURLToPath(import.meta.url));
export function validate(folder=root) {
 const read=name=>JSON.parse(fs.readFileSync(path.join(folder,name),'utf8').replace(/^\uFEFF/,''));
 const status=read('data/status.json'),policy=read('policy.json');
 if(status.schema_version!==1 || !Number.isFinite(Date.parse(status.exported_utc)))throw new Error('Invalid status metadata');
 if(!Array.isArray(status.benchmark?.rows) || !Array.isArray(status.paper?.rows) || !Array.isArray(status.news))throw new Error('Snapshot collections must be arrays');
 for(const row of [...status.benchmark.rows,...status.paper.rows])if(!row.symbol || !Number.isFinite(row.net_profit) || !Number.isInteger(row.trades) || row.trades<0)throw new Error('Invalid performance evidence');
 for(const row of status.news) {
  if(!row.headline || !row.target || !(row.published_utc<=row.observed_utc && row.observed_utc<row.expires_utc))throw new Error('Invalid headline chronology');
  if(!Number.isFinite(row.rule_score) || Math.abs(row.rule_score)>1 || new URL(row.source_url).protocol!=='https:')throw new Error('Invalid headline context');
 }
 if(!Array.isArray(policy.policies) && !Array.isArray(policy.slices))throw new Error('No real policy entries');
 const check=(value,key='')=>{
  if(/^(password|passwd|api_key|access_token|private_key|account_number|account_id|login)$/i.test(key))throw new Error('Private field in publication');
  if(typeof value==='number' && !Number.isFinite(value))throw new Error('Non-finite JSON number');
  if(typeof value==='string' && /gh[pousr]_[A-Za-z0-9_]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|C:\\Users\\/i.test(value))throw new Error('Credential or machine path in publication');
  if(value && typeof value==='object')for(const [name,item]of Object.entries(value))check(item,name);
 };
 check(status);check(policy);
 if(status.model?.performance_status!=='NOT_PROVEN_PROFITABLE')throw new Error('Unsupported profitability claim');
 return {status:'PASS',benchmark_symbols:status.benchmark.rows.length,paper_symbols:status.paper.rows.length,news_rows:status.news.length};
}
if(process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url))console.log(JSON.stringify(validate(process.argv[2]||root)));
