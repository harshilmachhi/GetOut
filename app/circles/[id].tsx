import {Ionicons} from '@expo/vector-icons';
import * as Linking from 'expo-linking';
import {router, useLocalSearchParams} from 'expo-router';
import React, {useMemo, useState} from 'react';
import {Alert, Image, Pressable, Share, StyleSheet, Text, View} from 'react-native';
import {AccountGate} from '@/components/AuthFlow';
import {spotImage} from '@/components/SpotCard';
import {Card, Muted, PrimaryButton, Screen, SectionTitle, Title} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {colors, radius, spacing} from '@/theme';

export default function CircleDetailScreen() { return <AccountGate><CircleDetail/></AccountGate>; }

function CircleDetail() {
  const {id} = useLocalSearchParams<{id: string}>(); const app = useApp(); const [busy, setBusy] = useState(false);
  const circle = app.circles.find(item => item.id === id); const membership = app.circleMembers.find(item => item.circle_id === id && item.user_id === app.profile?.id);
  const members = useMemo(() => app.circleMembers.filter(item => item.circle_id === id), [app.circleMembers, id]);
  const spots = useMemo(() => app.spots.filter(item => item.circle_ids.includes(id)), [app.spots, id]);
  if (!circle) return <Screen><Title>Circle unavailable</Title><Muted>You may no longer be a member, or this Circle was deleted.</Muted></Screen>;
  const canManage = membership?.role === 'owner' || membership?.role === 'admin';
  const invite = async () => { try { setBusy(true); const token = await app.createCircleInvite(circle.id); const url = Linking.createURL(`invite/${token}`); await Share.share({title:`Join ${circle.name} on GetOut`,message:`Join my private ${circle.name} Circle on GetOut. This invite expires in 7 days.\n\n${url}`,url}); } catch (error) { Alert.alert('Could not create invite', error instanceof Error ? error.message : String(error)); } finally { setBusy(false); } };
  const remove = (userId: string, label: string) => Alert.alert(`Remove ${label}?`, 'They will immediately lose access to every private spot in this Circle.', [{text:'Cancel'},{text:'Remove',style:'destructive',onPress:()=>app.removeCircleMember(circle.id,userId).catch(error=>Alert.alert('Could not remove member',String(error)))}]);
  const leave = () => Alert.alert(`Leave ${circle.name}?`, 'You will immediately lose access to its private spots.', [{text:'Cancel'},{text:'Leave',style:'destructive',onPress:()=>app.leaveCircle(circle.id).then(()=>router.back()).catch(error=>Alert.alert('Could not leave',String(error)))}]);
  const destroy = () => Alert.alert(`Delete ${circle.name}?`, 'Members will lose access. Spots shared only here will remain private to their creators.', [{text:'Cancel'},{text:'Delete Circle',style:'destructive',onPress:()=>app.deleteCircle(circle.id).then(()=>router.back()).catch(error=>Alert.alert('Could not delete',String(error)))}]);
  return <Screen>
    <View style={styles.hero}><View style={[styles.icon,{backgroundColor:circle.color}]}><Ionicons name="people" size={30} color={colors.text}/></View><View style={{flex:1}}><Title>{circle.name}</Title><Muted>{circle.description || 'A private map for your people.'}</Muted></View></View>
    {canManage && (
      <PrimaryButton title={busy ? 'Making secure link…' : 'Invite people'} icon="person-add" disabled={busy} onPress={invite}/>
    )}
    <Card style={styles.note}><Ionicons name="timer-outline" size={20} color={colors.green}/><Muted style={{flex:1}}>Invite links expire after 7 days and 25 joins. You can revoke every active link at any time.</Muted></Card>
    <View style={styles.row}><SectionTitle>Spots</SectionTitle><Muted>{spots.length}</Muted></View>
    {!spots.length && <Card style={styles.empty}><Ionicons name="map-outline" size={30} color={colors.subtle}/><Muted>No spots yet. Choose this Circle when you add your next find.</Muted></Card>}
    <View style={styles.grid}>{spots.map(spot => <Pressable key={spot.id} onPress={()=>router.push(`/spot/${spot.id}`)} style={styles.tile}><Image source={spotImage(spot)} style={styles.photo}/><View style={styles.tileCopy}><Text numberOfLines={1} style={styles.spotName}>{spot.title}</Text><View style={styles.visibility}><Ionicons name={spot.is_public?'earth':'lock-closed'} size={12} color={spot.is_public?colors.orange:colors.green}/><Text style={styles.visibilityText}>{spot.is_public?'Public + Circle':'Circle only'}</Text></View></View></Pressable>)}</View>
    <View style={styles.row}><SectionTitle>Members</SectionTitle><Muted>{members.length}</Muted></View>
    {members.map(member => { const label=member.profiles?.display_name || member.profiles?.username || 'Member'; const removable=canManage&&member.role!=='owner'&&member.user_id!==app.profile?.id; return <Card key={member.user_id} style={styles.member}><View style={styles.avatar}><Ionicons name="person" size={18} color={colors.muted}/></View><View style={{flex:1}}><Text style={styles.memberName}>{label}</Text><Muted>{member.role[0].toUpperCase()+member.role.slice(1)}{member.profiles?.username?` · @${member.profiles.username}`:''}</Muted></View>{removable&&<Pressable accessibilityLabel={`Remove ${label}`} onPress={()=>remove(member.user_id,label)}><Ionicons name="close-circle-outline" size={24} color={colors.red}/></Pressable>}</Card>; })}
    {canManage && <Pressable onPress={()=>app.revokeCircleInvites(circle.id).then(()=>Alert.alert('Links revoked','All previous invite links are now invalid.')).catch(error=>Alert.alert('Could not revoke links',String(error)))}><Text style={styles.dangerLink}>Revoke all invite links</Text></Pressable>}
    {membership?.role==='owner'?<Pressable onPress={destroy}><Text style={styles.dangerLink}>Delete Circle</Text></Pressable>:<Pressable onPress={leave}><Text style={styles.dangerLink}>Leave Circle</Text></Pressable>}
  </Screen>;
}

const styles=StyleSheet.create({hero:{flexDirection:'row',alignItems:'center',gap:spacing.md},icon:{width:62,height:62,borderRadius:21,alignItems:'center',justifyContent:'center'},note:{padding:spacing.md,flexDirection:'row',alignItems:'center',gap:spacing.sm},row:{flexDirection:'row',alignItems:'center',justifyContent:'space-between'},empty:{padding:spacing.lg,alignItems:'center',gap:spacing.sm},grid:{gap:spacing.sm},tile:{backgroundColor:colors.surface,borderRadius:radius.control,overflow:'hidden',flexDirection:'row'},photo:{width:88,height:88},tileCopy:{flex:1,justifyContent:'center',padding:spacing.md},spotName:{color:colors.text,fontWeight:'800',fontSize:16},visibility:{flexDirection:'row',alignItems:'center',gap:5,marginTop:6},visibilityText:{color:colors.muted,fontSize:12,fontWeight:'600'},member:{padding:spacing.md,flexDirection:'row',alignItems:'center',gap:spacing.md},avatar:{width:42,height:42,borderRadius:21,backgroundColor:colors.surface2,alignItems:'center',justifyContent:'center'},memberName:{color:colors.text,fontWeight:'800'},dangerLink:{color:colors.red,fontWeight:'700',textAlign:'center',paddingVertical:spacing.sm}});
