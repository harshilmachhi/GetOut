import {Ionicons} from '@expo/vector-icons';
import {router} from 'expo-router';
import React, {useState} from 'react';
import {Alert, Modal, Pressable, StyleSheet, Text, View} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {AccountGate} from '@/components/AuthFlow';
import {Card, Field, Muted, PrimaryButton, Screen, Title} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {colors, spacing} from '@/theme';

export default function CirclesScreen() { return <AccountGate><Circles/></AccountGate>; }

function Circles() {
  const app = useApp(); const [showCreate, setShowCreate] = useState(false); const [name, setName] = useState(''); const [description, setDescription] = useState(''); const [busy, setBusy] = useState(false);
  const create = async () => {
    if (!name.trim()) return Alert.alert('Name your Circle', 'Choose a short name your friends will recognize.');
    try { setBusy(true); const circle = await app.createCircle(name, description); setShowCreate(false); setName(''); setDescription(''); router.push(`/circles/${circle.id}` as never); }
    catch (error) { Alert.alert('Could not create Circle', error instanceof Error ? error.message : String(error)); }
    finally { setBusy(false); }
  };
  return <Screen>
    <View style={styles.heading}><View style={{flex: 1}}><Title>Circles</Title><Muted>Private maps for the people you trust.</Muted></View><Pressable accessibilityLabel="Create a Circle" onPress={() => setShowCreate(true)} style={styles.add}><Ionicons name="add" size={24} color={colors.text}/></Pressable></View>
    <Card style={styles.privacy}><View style={styles.lock}><Ionicons name="lock-closed" size={20} color={colors.green}/></View><View style={{flex: 1}}><Text style={styles.privacyTitle}>Locations stay inside the Circle</Text><Muted>Only current members can see its spots, photos, and exact locations.</Muted></View></Card>
    {!app.circles.length && <View style={styles.empty}><Ionicons name="people-circle-outline" size={68} color={colors.subtle}/><Text style={styles.emptyTitle}>Make a map with your people</Text><Muted style={styles.center}>Create a Circle for close friends, climbing partners, date-night finds—whoever you explore with.</Muted><PrimaryButton title="Create your first Circle" icon="add" onPress={() => setShowCreate(true)}/></View>}
    {app.circles.map(circle => {
      const members = app.circleMembers.filter(member => member.circle_id === circle.id);
      const spots = app.spots.filter(spot => spot.circle_ids.includes(circle.id));
      return <Pressable key={circle.id} onPress={() => router.push(`/circles/${circle.id}` as never)}><Card style={styles.circleCard}><View style={[styles.circleIcon, {backgroundColor: circle.color}]}><Ionicons name="people" size={23} color={colors.text}/></View><View style={{flex: 1}}><Text style={styles.circleName}>{circle.name}</Text><Muted>{members.length} member{members.length === 1 ? '' : 's'} · {spots.length} spot{spots.length === 1 ? '' : 's'}</Muted></View><Ionicons name="chevron-forward" size={20} color={colors.subtle}/></Card></Pressable>;
    })}
    <Modal animationType="slide" transparent visible={showCreate} onRequestClose={() => setShowCreate(false)}><View style={styles.scrim}><SafeAreaView style={styles.sheet} edges={['bottom']}><View style={styles.handle}/><Text style={styles.sheetTitle}>New Circle</Text><Muted>A private place map for a group you trust.</Muted><Field value={name} onChangeText={setName} maxLength={40} placeholder="Circle name" autoFocus/><Field value={description} onChangeText={setDescription} maxLength={160} placeholder="What do you explore together?" multiline/><PrimaryButton title={busy ? 'Creating…' : 'Create Circle'} disabled={busy} onPress={create}/><Pressable onPress={() => setShowCreate(false)}><Text style={styles.cancel}>Cancel</Text></Pressable></SafeAreaView></View></Modal>
  </Screen>;
}

const styles = StyleSheet.create({heading:{flexDirection:'row',alignItems:'center',gap:spacing.md},add:{width:46,height:46,borderRadius:23,backgroundColor:colors.green,alignItems:'center',justifyContent:'center'},privacy:{padding:spacing.md,flexDirection:'row',alignItems:'center',gap:spacing.md},lock:{width:42,height:42,borderRadius:21,backgroundColor:'rgba(107,153,97,.16)',alignItems:'center',justifyContent:'center'},privacyTitle:{color:colors.text,fontWeight:'800',marginBottom:3},empty:{alignItems:'center',gap:spacing.md,paddingHorizontal:spacing.lg,paddingVertical:spacing.xl},emptyTitle:{color:colors.text,fontSize:20,fontWeight:'800'},center:{textAlign:'center'},circleCard:{padding:spacing.md,flexDirection:'row',alignItems:'center',gap:spacing.md},circleIcon:{width:50,height:50,borderRadius:17,alignItems:'center',justifyContent:'center'},circleName:{color:colors.text,fontSize:17,fontWeight:'800',marginBottom:4},scrim:{flex:1,backgroundColor:'rgba(0,0,0,.55)',justifyContent:'flex-end'},sheet:{backgroundColor:colors.surface,borderTopLeftRadius:28,borderTopRightRadius:28,padding:spacing.lg,gap:spacing.md},handle:{width:38,height:5,borderRadius:3,backgroundColor:colors.subtle,alignSelf:'center'},sheetTitle:{fontFamily:'serif',fontSize:28,fontWeight:'700',color:colors.cream},cancel:{color:colors.muted,fontWeight:'700',textAlign:'center',paddingVertical:spacing.sm}});
