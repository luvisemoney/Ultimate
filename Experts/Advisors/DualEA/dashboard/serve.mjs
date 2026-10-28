import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {root} from './validate.mjs';
const port=Number(process.env.PORT||8010),folder=fs.existsSync(path.join(root,'dist/index.html'))?path.join(root,'dist'):root;
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8'};
http.createServer((req,res)=>{
 if(req.method!=='GET'){res.writeHead(405);res.end();return;}
 let name;try{name=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\/Ultimate(?=\/|$)/,'');}catch{res.writeHead(400);res.end();return;}
 if(name==='/' || name==='')name='/index.html';const file=path.resolve(folder,'.'+name);
 if(!file.startsWith(folder+path.sep) || !types[path.extname(file)] || !fs.existsSync(file) || !fs.statSync(file).isFile()){res.writeHead(404);res.end();return;}
 res.writeHead(200,{'Content-Type':types[path.extname(file)],'Cache-Control':'no-store'});fs.createReadStream(file).pipe(res);
}).listen(port,'127.0.0.1',()=>console.log(`Dashboard preview http://127.0.0.1:${port}/Ultimate/`));
