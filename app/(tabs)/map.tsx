import {Ionicons} from '@expo/vector-icons';
import {router} from 'expo-router';
import React, {useMemo, useRef, useState} from 'react';
import {Image, Pressable, ScrollView, StyleSheet, Text, View} from 'react-native';
import MapView, {Marker, PROVIDER_GOOGLE} from 'react-native-maps';
import {SafeAreaView} from 'react-native-safe-area-context';
import {spotImage} from '@/components/SpotCard';
import {useLocation} from '@/hooks/useLocation';
import {distanceMeters} from '@/lib/geo';
import {useApp} from '@/store/AppContext';
import {colors, radius, spacing} from '@/theme';

const NYC = {latitude: 40.7128, longitude: -74.006, latitudeDelta: .13, longitudeDelta: .13};
export default function ExploreMap() {
  const {spots, saves} = useApp(); const {location, request} = useLocation(); const map = useRef<MapView>(null); const [selected, setSelected] = useState<string>();
  const mappable = spots.filter(s => s.latitude && s.longitude); const saved = useMemo(() => mappable.filter(s => saves.some(v => v.spot_id === s.id && v.list === 'saved') && (!location || distanceMeters(location, s) <= 25_000)), [mappable, saves, location]);
  const center = async () => { const current = await request(); if (current) map.current?.animateToRegion({...current, latitudeDelta: .06, longitudeDelta: .06}); };
  return <SafeAreaView style={styles.screen} edges={['top']}><View style={styles.titleRow}><Text style={styles.title}>Explore</Text><Pressable style={styles.locate} onPress={center}><Ionicons name="locate" size={22} color={colors.text}/></Pressable></View>
    <MapView ref={map} provider={process.env.EXPO_OS === 'android' ? PROVIDER_GOOGLE : undefined} style={StyleSheet.absoluteFill} initialRegion={location ? {...location, latitudeDelta: .1, longitudeDelta: .1} : NYC} showsUserLocation>
      {mappable.map(spot => <Marker key={spot.id} coordinate={spot} title={spot.title} pinColor={saves.some(x => x.spot_id === spot.id) ? colors.green : colors.orange} onPress={() => setSelected(spot.id)}/>) }
    </MapView>
    <View pointerEvents="box-none" style={StyleSheet.absoluteFill}><SafeAreaView pointerEvents="box-none" style={styles.overlay} edges={['top']}><View style={styles.titleRow}><Text style={styles.title}>Explore</Text><Pressable style={styles.locate} onPress={center}><Ionicons name="locate" size={22} color={colors.text}/></Pressable></View><View style={{flex: 1}}/>
      {!!saved.length && <View><Text style={styles.savedTitle}><Ionicons name="bookmark"/> Saved nearby</Text><ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.savedRow}>{saved.map(spot => <Pressable key={spot.id} onPress={() => router.push(`/spot/${spot.id}`)} style={styles.mini}><Image source={spotImage(spot)} style={styles.miniImage}/><View style={styles.miniInfo}><Text numberOfLines={1} style={styles.miniTitle}>{spot.title}</Text><Text style={styles.miniSubtitle}>{spot.neighborhood || 'Saved spot'}</Text></View></Pressable>)}</ScrollView></View>}
      {selected && <Pressable onPress={() => router.push(`/spot/${selected}`)} style={styles.callout}><Image source={spotImage(mappable.find(s => s.id === selected)!)} style={styles.calloutImage}/><View style={{flex: 1}}><Text style={styles.miniTitle}>{mappable.find(s => s.id === selected)?.title}</Text><Text style={styles.miniSubtitle}>{mappable.find(s => s.id === selected)?.neighborhood}</Text></View><Ionicons name="chevron-forward" size={22} color={colors.muted}/></Pressable>}
    </SafeAreaView></View>
  </SafeAreaView>;
}
const styles = StyleSheet.create({screen: {flex: 1, backgroundColor: colors.background}, overlay: {flex: 1, paddingBottom: 90}, titleRow: {zIndex: 2, margin: spacing.lg, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center'}, title: {fontFamily: 'serif', fontSize: 34, fontWeight: '700', color: colors.cream, textShadowColor: '#000', textShadowRadius: 8}, locate: {width: 44, height: 44, borderRadius: 22, backgroundColor: colors.surface, alignItems: 'center', justifyContent: 'center'}, savedTitle: {color: colors.text, fontWeight: '800', marginHorizontal: spacing.lg, marginBottom: spacing.sm}, savedRow: {paddingHorizontal: spacing.lg, gap: spacing.sm}, mini: {width: 205, flexDirection: 'row', borderRadius: radius.control, overflow: 'hidden', backgroundColor: colors.surface}, miniImage: {width: 70, height: 70}, miniInfo: {flex: 1, justifyContent: 'center', padding: 10}, miniTitle: {color: colors.text, fontWeight: '700'}, miniSubtitle: {color: colors.muted, fontSize: 12, marginTop: 3}, callout: {margin: spacing.lg, padding: spacing.sm, borderRadius: radius.card, backgroundColor: colors.surface, flexDirection: 'row', alignItems: 'center', gap: 12}, calloutImage: {width: 64, height: 64, borderRadius: 14}});
