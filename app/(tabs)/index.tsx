import {Ionicons} from '@expo/vector-icons';
import {router} from 'expo-router';
import React, {useMemo, useState} from 'react';
import {Alert, ImageBackground, Pressable, ScrollView, StyleSheet, Text, View} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {SpotCard} from '@/components/SpotCard';
import {Muted} from '@/components/ui';
import {useCannabisAccess} from '@/hooks/useCannabisAccess';
import {rankSpots} from '@/lib/geo';
import {useApp} from '@/store/AppContext';
import {categoryMeta, colors, spacing} from '@/theme';

const fallbackHero = require('../../GetOut/Resources/Assets.xcassets/home_morning_scenic.imageset/home_morning_scenic.png');

export default function Discover() {
  const app = useApp();
  const {location, canAccessCannabis} = useCannabisAccess();
  const [category, setCategory] = useState('nearby');
  const visible = useMemo(() => app.spots.filter(spot => !spot.contains_cannabis || canAccessCannabis), [app.spots, canAccessCannabis]);
  const ranked = useMemo(() => rankSpots(visible, location, app.profile?.preferred_categories, app.profile?.preferred_tags).filter(item => category === 'nearby' || item.spot.category === category), [visible, location, app.profile, category]);
  const like = (id: string) => app.session ? app.toggleLike(id).catch(error => Alert.alert('Could not update like', String(error))) : router.push('/(tabs)/profile');
  const hero = ranked[0]?.spot.photo_urls?.[0] ? {uri: ranked[0].spot.photo_urls[0]} : fallbackHero;

  return <View style={styles.screen}><ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.content}>
    <ImageBackground source={hero} style={styles.hero} imageStyle={styles.heroImage}>
      <View style={styles.heroTint}/>
      <SafeAreaView edges={['top']} style={styles.heroInner}>
        <View style={styles.header}><Text style={styles.greeting}>Good morning, {app.profile?.display_name ?? 'Explorer'}</Text><Pressable accessibilityLabel="Account settings" onPress={() => router.push('/settings')} style={styles.avatar}><Ionicons name="person" size={18} color="rgba(0,0,0,.7)"/></Pressable></View>
        <View style={{flex: 1}}/>
        <View style={styles.searchRow}><Pressable onPress={() => router.push('/search')} style={styles.search}><Ionicons name="search" size={20} color="#777"/><Text style={styles.searchText}>Where to next?</Text></Pressable><Pressable accessibilityLabel="Search filters" onPress={() => router.push('/search')} style={styles.filter}><Ionicons name="options" size={21} color={colors.text}/></Pressable></View>
      </SafeAreaView>
    </ImageBackground>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.categories}>{Object.entries(categoryMeta).map(([key, item]) => <Pressable key={key} onPress={() => setCategory(key)} style={styles.categoryWrap}><View style={[styles.category, category === key && styles.selectedCategory]}><Ionicons name={item.icon as never} size={22} color={category === key ? colors.text : '#222'}/></View><Text style={styles.categoryText}>{item.label}</Text></Pressable>)}</ScrollView>
    <View style={styles.sectionRow}><View style={styles.sectionName}><Ionicons name="sparkles" size={20} color={colors.green}/><Text style={styles.sectionTitle}>For you nearby</Text></View><Pressable onPress={() => router.push('/search')} style={styles.viewAll}><Text style={styles.viewAllText}>View all</Text></Pressable></View>
    {!ranked.length && <View style={styles.pad}><Muted>No spots match this category yet.</Muted></View>}
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.cards}>{ranked.slice(0, 20).map(({spot, distance}) => <SpotCard compact key={spot.id} spot={spot} subtitle={[distance != null ? `${(distance / 1609).toFixed(1)} mi` : '', spot.neighborhood].filter(Boolean).join(' · ')} liked={app.likes.some(item => item.spot_id === spot.id)} onLike={() => like(spot.id)}/>)}</ScrollView>
  </ScrollView></View>;
}

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: colors.background}, content: {paddingBottom: 120}, hero: {height: 330}, heroImage: {borderBottomLeftRadius: 28, borderBottomRightRadius: 28},
  heroTint: {...StyleSheet.absoluteFill, backgroundColor: 'rgba(245,210,185,.20)', borderBottomLeftRadius: 28, borderBottomRightRadius: 28}, heroInner: {flex: 1, paddingHorizontal: spacing.md, paddingBottom: spacing.lg},
  header: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingTop: spacing.sm}, greeting: {fontSize: 14, fontWeight: '600', color: 'rgba(0,0,0,.72)'}, avatar: {width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(255,255,255,.86)', alignItems: 'center', justifyContent: 'center'},
  searchRow: {flexDirection: 'row', gap: spacing.sm}, search: {flex: 1, height: 52, borderRadius: 26, paddingHorizontal: spacing.md, flexDirection: 'row', alignItems: 'center', gap: spacing.sm, backgroundColor: colors.cream}, searchText: {fontSize: 16, color: '#777'}, filter: {width: 52, height: 52, borderRadius: 26, backgroundColor: 'rgba(0,0,0,.78)', alignItems: 'center', justifyContent: 'center'},
  categories: {gap: spacing.md, paddingHorizontal: spacing.md, paddingTop: spacing.lg, paddingBottom: spacing.xs}, categoryWrap: {alignItems: 'center', gap: spacing.sm}, category: {width: 64, height: 64, borderRadius: 20, backgroundColor: colors.cream, alignItems: 'center', justifyContent: 'center'}, selectedCategory: {backgroundColor: colors.green}, categoryText: {fontSize: 12, color: colors.muted},
  sectionRow: {marginTop: spacing.lg, marginBottom: spacing.md, paddingHorizontal: spacing.md, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between'}, sectionName: {flexDirection: 'row', alignItems: 'center', gap: spacing.sm}, sectionTitle: {fontSize: 17, letterSpacing: -0.2, fontWeight: '700', color: colors.text}, viewAll: {borderWidth: StyleSheet.hairlineWidth, borderColor: 'rgba(247,245,237,.48)', borderRadius: 20, paddingHorizontal: spacing.md, paddingVertical: 7}, viewAllText: {color: colors.text, fontSize: 12, fontWeight: '600'}, cards: {paddingHorizontal: spacing.md, gap: spacing.md, paddingBottom: spacing.sm}, pad: {paddingHorizontal: spacing.md},
});
