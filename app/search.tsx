import {Ionicons} from '@expo/vector-icons';
import React, {useMemo, useState} from 'react';
import {StyleSheet, Text, View} from 'react-native';
import {SpotCard} from '@/components/SpotCard';
import {Chip, Field, Muted, Screen} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {useCannabisAccess} from '@/hooks/useCannabisAccess';
import type {Category} from '@/types';
import {colors, spacing} from '@/theme';

const categories: Category[] = ['views', 'coffee', 'food', 'nature', 'nightlife'];
export default function Search() {
  const {spots} = useApp(); const {canAccessCannabis} = useCannabisAccess(); const [query, setQuery] = useState(''); const [selected, setSelected] = useState<Category[]>([]);
  const results = useMemo(() => { const q = query.trim().toLowerCase(); return spots.filter(s => (!s.contains_cannabis || canAccessCannabis) && (!selected.length || selected.includes(s.category)) && (!q || [s.title, s.details, s.neighborhood, s.city, ...s.tags].some(v => v.toLowerCase().includes(q)))).sort((a,b) => b.rating-a.rating); }, [spots, query, selected, canAccessCannabis]);
  const toggle = (value: Category) => setSelected(v => v.includes(value) ? v.filter(x => x !== value) : [...v, value]);
  return <Screen><View style={styles.search}><Ionicons name="search" size={20} color={colors.muted}/><Field autoFocus value={query} onChangeText={setQuery} style={styles.field} placeholder="Search spots, neighborhoods, tags…"/></View><View style={styles.wrap}>{categories.map(v => <Chip key={v} label={v[0].toUpperCase()+v.slice(1)} selected={selected.includes(v)} onPress={() => toggle(v)}/>)}</View><Text style={styles.count}>{results.length} spot{results.length === 1 ? '' : 's'}</Text>{!results.length && <Muted>No spots match. Try adjusting your search or filters.</Muted>}{results.map(spot => <SpotCard key={spot.id} spot={spot}/>)}</Screen>;
}
const styles = StyleSheet.create({search: {height: 54, flexDirection: 'row', alignItems: 'center', paddingLeft: spacing.md, borderRadius: 16, backgroundColor: colors.surface}, field: {flex: 1, backgroundColor: 'transparent'}, wrap: {flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm}, count: {fontWeight: '700', color: colors.text}});
