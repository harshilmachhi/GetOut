export const suggestedTags = ['sunset','scenic','quiet','cozy','hidden-gem','waterfront','local-favorite','late-night','picnic','date-night','family-friendly','outdoors'];

export function normalizeTag(value: string) {
  return value.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').trim().toLocaleLowerCase().replace(/^#+/, '').replace(/['’]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function editDistance(a: string, b: string) {
  const row = Array.from({length:b.length+1},(_,index)=>index);
  for(let i=1;i<=a.length;i++){let previous=row[0];row[0]=i;for(let j=1;j<=b.length;j++){const next=row[j];row[j]=Math.min(row[j]+1,row[j-1]+1,previous+(a[i-1]===b[j-1]?0:1));previous=next;}}
  return row[b.length];
}

export function similarTags(query: string, existing: string[], selected: string[] = []) {
  const normalized = normalizeTag(query);
  if (!normalized) return [];
  const pool = [...new Set([...suggestedTags,...existing].map(normalizeTag).filter(Boolean))];
  return pool.filter(value=>!selected.includes(value)&&(value.includes(normalized)||normalized.includes(value)||editDistance(value,normalized)<=Math.max(1,Math.floor(normalized.length/4)))).sort((a,b)=>a.startsWith(normalized)?-1:b.startsWith(normalized)?1:a.localeCompare(b)).slice(0,5);
}
