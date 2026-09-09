import {Ionicons} from '@expo/vector-icons';
import {useLocalSearchParams, router} from 'expo-router';
import React, {useMemo, useState} from 'react';
import {Alert, Pressable, StyleSheet, Text, View} from 'react-native';
import {SpotCard} from '@/components/SpotCard';
import {Card, Chip, Muted, PrimaryButton, Screen, SectionTitle, Title} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {colors, spacing} from '@/theme';

export default function TripDetail() {
  const {id} = useLocalSearchParams<{id:string}>(); const app = useApp(); const trip = app.trips.find(x => x.id === id); const [adding, setAdding] = useState(false);
  const stops = useMemo(() => app.tripStops.filter(x => x.trip_id === id).sort((a,b) => a.day_index-b.day_index || a.sort_order-b.sort_order), [app.tripStops,id]);
  if (!trip) return <Screen><Muted>Trip not found.</Muted></Screen>;
  const generate = async () => { const sorted = [...stops].sort((a,b) => { const sa=app.spots.find(s=>s.id===a.spot_id), sb=app.spots.find(s=>s.id===b.spot_id); return (sa?.visit_hour ?? 12)-(sb?.visit_hour ?? 12); }); await Promise.all(sorted.map((stop,index)=>app.updateStop({...stop,day_index:Math.floor(index/4),sort_order:index%4}))); await app.updateTrip({...trip,plan_summary:'Balanced by the best visit time, with nearby stops kept together where possible.'}); };
  return <Screen><Title>{trip.title}</Title><Muted>{trip.start_date ? new Date(trip.start_date).toLocaleDateString() : 'Dates flexible'}</Muted>{!!trip.summary && <Text style={styles.summary}>{trip.summary}</Text>}<View style={styles.actions}><PrimaryButton title={adding?'Done':'Add spots'} icon="add" onPress={()=>setAdding(!adding)}/><PrimaryButton title="Generate plan" icon="sparkles" disabled={!stops.length} onPress={()=>generate().catch(e=>Alert.alert('Planning failed',String(e)))}/></View>
    {!!trip.plan_summary && <Card style={styles.plan}><SectionTitle>Why this plan</SectionTitle><Muted>{trip.plan_summary}</Muted></Card>}
    {adding && <View style={styles.picker}><SectionTitle>Choose spots</SectionTitle>{app.spots.filter(s=>!stops.some(x=>x.spot_id===s.id)).map(s=><Pressable key={s.id} onPress={()=>app.addStop(trip.id,s.id)}><Card style={styles.row}><Text style={styles.name}>{s.title}</Text><Ionicons name="add-circle" size={24} color={colors.green}/></Card></Pressable>)}</View>}
    {!stops.length && !adding && <Muted>Add spots to start building your itinerary.</Muted>}
    {[...new Set(stops.map(s=>s.day_index))].map(day=><View key={day} style={styles.day}><SectionTitle>Day {day+1}</SectionTitle>{stops.filter(s=>s.day_index===day).map(stop=>{const spot=app.spots.find(s=>s.id===stop.spot_id); return spot&&<View key={stop.id}><SpotCard spot={spot}/><View style={styles.stopActions}><View style={styles.dayChips}>{[0,1,2].map(d=><Chip key={d} label={`Day ${d+1}`} selected={d===stop.day_index} onPress={()=>app.updateStop({...stop,day_index:d})}/>)}</View><Pressable onPress={()=>app.removeStop(stop.id)}><Text style={styles.remove}>Remove</Text></Pressable></View></View>})}</View>)}
    <PrimaryButton danger title="Delete trip" icon="trash" onPress={()=>Alert.alert('Delete trip?',undefined,[{text:'Cancel'},{text:'Delete',style:'destructive',onPress:()=>app.deleteTrip(trip.id).then(()=>router.back())}])}/>
  </Screen>;
}
const styles=StyleSheet.create({summary:{color:colors.text,fontSize:16,lineHeight:23},actions:{gap:spacing.sm},plan:{padding:spacing.md,gap:spacing.sm},picker:{gap:spacing.sm},row:{padding:spacing.md,flexDirection:'row',justifyContent:'space-between'},name:{color:colors.text,fontWeight:'700'},day:{gap:spacing.md},stopActions:{marginTop:-8,flexDirection:'row',alignItems:'center',justifyContent:'space-between'},dayChips:{flexDirection:'row',gap:4},remove:{color:colors.red,fontWeight:'700'}});
