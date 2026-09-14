import {Ionicons} from '@expo/vector-icons';
import {router, useLocalSearchParams} from 'expo-router';
import React, {useState} from 'react';
import {Alert, StyleSheet, Text, View} from 'react-native';
import {AccountGate} from '@/components/AuthFlow';
import {Muted, PrimaryButton, Screen, Title} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {colors, spacing} from '@/theme';

export default function InviteScreen(){return <AccountGate><Invite/></AccountGate>}
function Invite(){const {token}=useLocalSearchParams<{token:string}>();const app=useApp();const[busy,setBusy]=useState(false);const join=async()=>{if(!token)return;try{setBusy(true);const id=await app.acceptCircleInvite(token);router.replace(`/circles/${id}` as never)}catch(error){Alert.alert('Invite unavailable',error instanceof Error?error.message:String(error))}finally{setBusy(false)}};return <Screen style={styles.center}><View style={styles.mark}><Ionicons name="people" size={42} color={colors.green}/></View><Title>You’re invited to a Circle</Title><Muted style={styles.copy}>Join to see the Circle name, members, and private spots. Membership is checked every time content loads.</Muted><PrimaryButton title={busy?'Joining…':'Accept invite'} icon="lock-open" disabled={busy||!token} onPress={join}/><Text style={styles.fine}>Only join links from someone you trust. You can leave at any time.</Text></Screen>}
const styles=StyleSheet.create({center:{flexGrow:1,justifyContent:'center',alignItems:'center'},mark:{width:82,height:82,borderRadius:41,backgroundColor:'rgba(107,153,97,.16)',alignItems:'center',justifyContent:'center'},copy:{textAlign:'center',maxWidth:330},fine:{color:colors.subtle,fontSize:12,textAlign:'center',marginTop:spacing.sm}});
