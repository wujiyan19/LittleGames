/* Independent search over plate rectangles and colored screw heads. No game-model imports. */
function solve(plates, screws, capacity) {
  const n=screws.length,full=(1<<n)-1,plateMasks=new Map();
  for(let i=0;i<n;i++)plateMasks.set(screws[i].owner,(plateMasks.get(screws[i].owner)||0)|(1<<i));
  const blockers=screws.map(s=>plates.filter(p=>p.id>s.owner&&s.x+s.r>p.x&&s.x-s.r<p.x+p.w&&s.y+s.r>p.y&&s.y-s.r<p.y+p.h)
    .reduce((mask,p)=>mask|plateMasks.get(p.id),0));
  const seen=new Set(),route=[];let visited=0;
  function search(removed){
    if(removed===full)return true;
    if(seen.has(removed))return false;
    seen.add(removed);visited++;
    const counts=[0,0,0,0,0,0];for(let i=0;i<n;i++)if(removed&(1<<i))counts[screws[i].color]++;
    const holding=counts.map(v=>v%3),used=holding.reduce((sum,v)=>sum+v,0);
    if(used>=capacity)return false;
    const choices=[];
    for(let i=0;i<n;i++)if(!(removed&(1<<i))&&(removed&blockers[i])===blockers[i]&&
      (used+1<capacity||holding[screws[i].color]===2))choices.push(i);
    choices.sort((a,b)=>holding[screws[b].color]-holding[screws[a].color]||screws[b].owner-screws[a].owner);
    for(const i of choices){route.push(screws[i].id);if(search(removed|(1<<i)))return true;route.pop();}
    return false;
  }
  return {route:search(0)?route:null,visited};
}
module.exports={solve};
