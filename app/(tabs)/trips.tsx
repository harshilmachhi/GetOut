import {Ionicons} from '@expo/vector-icons';
import {router} from 'expo-router';
import React, {useState} from 'react';
import {Alert, Pressable, StyleSheet, Text, View} from 'react-native';
import {AccountGate} from '@/components/AuthFlow';
import {Card, Field, Muted, PrimaryButton, Screen, Title} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {colors, spacing} from '@/theme';

export default function Trips() { return <AccountGate><TripList/></AccountGate>; }
function TripList() {
  const {trips, tripStops, createTrip} = useApp(); const [creating, setCreating] = useState(false); const [title, setTitle] = useState(''); const [summary, setSummary] = useState('');
  const submit = async () => { if (!title.trim()) return; try { const trip = await createTrip({title: title.trim(), summary: summary.trim(), start_date: new Date().toISOString(), end_date: new Date(Date.now()+86400000).toISOString()}); setCreating(false); setTitle(''); setSummary(''); router.push(`/trip/${trip.id}`); } catch(e) { Alert.alert('Could not create trip', String(e)); } };
  return <Screen><Title>Trips</Title>{!trips.length && !creating && <View style={styles.empty}><Ionicons name="briefcase" size={54} color={colors.green}/><Text style={styles.heading}>Plan your next trip</Text><Muted>Save spots into a trip, invite friends, and get an itinerary.</Muted></View>}{creating ? <Card style={styles.form}><Field value={title} onChangeText={setTitle} placeholder="Trip name"/><Field value={summary} onChangeText={setSummary} placeholder="What kind of trip?" multiline/><PrimaryButton title="Create trip" onPress={submit}/><Pressable onPress={() => setCreating(false)}><Text style={styles.cancel}>Cancel</Text></Pressable></Card> : <PrimaryButton title="New Trip" icon="add" onPress={() => setCreating(true)}/>} {trips.map(trip => <Pressable key={trip.id} onPress={() => router.push(`/trip/${trip.id}`)}><Card style={styles.trip}><View style={styles.tripIcon}><Ionicons name="briefcase" size={24} color={colors.green}/></View><View style={{flex:1}}><Text style={styles.tripTitle}>{trip.title}</Text><Muted>{trip.start_date ? new Date(trip.start_date).toLocaleDateString() : 'Dates flexible'} · {tripStops.filter(x => x.trip_id === trip.id).length} spots</Muted></View><Ionicons name="chevron-forward" size={22} color={colors.muted}/></Card></Pressable>)}</Screen>;
}
const styles=StyleSheet.create({empty:{alignItems:'center',paddingVertical:32,gap:12},heading:{fontSize:22,fontWeight:'800',color:colors.text},form:{padding:spacing.md,gap:spacing.md},cancel:{color:colors.muted,textAlign:'center'},trip:{padding:spacing.md,flexDirection:'row',alignItems:'center',gap:12},tripIcon:{width:48,height:48,borderRadius:14,backgroundColor:'rgba(107,153,97,.18)',alignItems:'center',justifyContent:'center'},tripTitle:{fontSize:18,fontWeight:'800',color:colors.text,marginBottom:4}});
