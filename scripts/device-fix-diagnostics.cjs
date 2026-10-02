process.env.LITTLEGAMES_DEVICE_CHECKPOINT='mate60-fix-progress.json';
process.env.LITTLEGAMES_DEVICE_LOG='mate60-fix-actions.jsonl';
const c=require('./device-acceptance-core.cjs');
const query=(...args)=>{try{return {ok:true,output:c.shell(...args).trim()};}catch(e){return {ok:false,output:e.message};}};
const p=JSON.parse(c.fs.readFileSync('docs/device-acceptance/mate60-fix-progress.json'));
const pidResult=query('pidof','com.littlegames.collection'),pid=pidResult.output.match(/^\d+$/)?.[0];
const faultRecords=query('hidumper','-e','--list','com.littlegames.collection','-n','10');
const memory=pid?query('hidumper','--mem',pid):{ok:false,output:'No app PID'};
const cpu=pid?query('hidumper','--cpuusage',pid):{ok:false,output:'No app PID'};
const result={at:new Date().toISOString(),target:c.target,packageHash:p.packageHash,bundle:'com.littlegames.collection',pid:pid||null,faultRecords,memory,cpu,
  interpretation:{faultRecords:/no records found/i.test(faultRecords.output)?'此次查询未返回应用故障记录；不等于全时段无故障的证明。':'以原始查询结果为准。',memory:'仅单次采样，没有泄漏、帧率、功耗或温升结论。'}};
c.fs.writeFileSync('docs/device-acceptance/mate60-fix-diagnostics-2026-09-30.json',JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({pid:result.pid,faultRecords:result.interpretation.faultRecords}));
