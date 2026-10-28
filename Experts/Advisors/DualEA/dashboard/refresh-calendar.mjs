import fs from 'node:fs';import path from 'node:path';import {root} from './validate.mjs';
const source='https://nfs.faireconomy.media/ff_calendar_thisweek.json';
const response=await fetch(source,{signal:AbortSignal.timeout(20000)});
if(!response.ok)throw new Error(`Calendar HTTP ${response.status}; retain last successful deployment`);
const events=await response.json();
if(!Array.isArray(events) || !events.length || events.some(e=>!e.title || !e.country || !Number.isFinite(Date.parse(e.date))))throw new Error('Calendar schema changed');
fs.mkdirSync(path.join(root,'data'),{recursive:true});fs.writeFileSync(path.join(root,'data/calendar.json'),JSON.stringify({source_url:source,observed_utc:new Date().toISOString(),events},null,2));
console.log(`Refreshed ${events.length} official calendar events; no actual values or surprises invented`);
