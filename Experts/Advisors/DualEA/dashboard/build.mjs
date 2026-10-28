import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {root,validate} from './validate.mjs';
validate();const output=path.resolve(root,'dist');fs.mkdirSync(path.join(output,'data'),{recursive:true});
const assets=['index.html','styles.css','app.js','policy.json','data/status.json'];
if(fs.existsSync(path.join(root,'data/calendar.json')))assets.push('data/calendar.json');
for(const name of assets)fs.copyFileSync(path.join(root,name),path.join(output,name));
fs.writeFileSync(path.join(output,'.nojekyll'),'');
const manifest={built_utc:new Date().toISOString(),commit:process.env.GITHUB_SHA||null,assets:assets.map(file=>({file,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(output,file))).digest('hex')}))};
fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2));console.log(`Built ${assets.length} verified static assets in ${output}`);
