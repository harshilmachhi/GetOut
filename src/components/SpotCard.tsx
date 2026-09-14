import {Ionicons} from '@expo/vector-icons';
import {router} from 'expo-router';
import React from 'react';
import {Image, ImageSourcePropType, Pressable, StyleSheet, Text, View} from 'react-native';
import {colors, radius, spacing} from '@/theme';
import type {Spot} from '@/types';
import {IconButton} from './ui';

const localPhotos: Record<string, ImageSourcePropType> = {
  'Sunset hill seating': require('../../GetOut/Resources/Assets.xcassets/spot_sunset_hill.imageset/spot_sunset_hill.png'),
  'Hidden cafe in the garden': require('../../GetOut/Resources/Assets.xcassets/spot_hidden_cafe.imageset/spot_hidden_cafe.png'),
  'East River quiet spot': require('../../GetOut/Resources/Assets.xcassets/spot_east_river.imageset/spot_east_river.png'),
  'Rooftop reading nook': require('../../GetOut/Resources/Assets.xcassets/spot_rooftop_nook.imageset/spot_rooftop_nook.png'),
  'Late-night dumpling counter': require('../../GetOut/Resources/Assets.xcassets/spot_dumpling.imageset/spot_dumpling.png'),
  'Prospect Park knoll': require('../../GetOut/Resources/Assets.xcassets/spot_prospect_park.imageset/spot_prospect_park.png'),
};
export function spotImage(spot: Spot): ImageSourcePropType { return spot.photo_urls?.[0] ? {uri: spot.photo_urls[0]} : localPhotos[spot.title] ?? require('../../GetOut/Resources/Assets.xcassets/home_morning_scenic.imageset/home_morning_scenic.png'); }

export function SpotCard({spot, liked, onLike, subtitle, compact}: {spot: Spot; liked?: boolean; onLike?(): void; subtitle?: string; compact?: boolean}) {
  return <Pressable onPress={() => router.push(`/spot/${spot.id}`)} style={[styles.card, compact && styles.compact]}>
    <Image source={spotImage(spot)} style={styles.image}/>
    <View style={styles.scrim}/>
    <View style={styles.info}>
      {!spot.is_public && <View style={styles.privateBadge}><Ionicons name="lock-closed" size={11} color={colors.text}/><Text style={styles.privateText}>Circle</Text></View>}
      <Text numberOfLines={1} style={styles.title}>{spot.title}</Text>
      <Text numberOfLines={1} style={styles.subtitle}>{subtitle ?? [spot.neighborhood, spot.city].filter(Boolean).join(', ')}</Text>
      <View style={styles.rating}><Ionicons name="star" size={14} color={colors.cream}/><Text style={styles.ratingText}>{spot.rating ? spot.rating.toFixed(1) : 'New'}</Text></View>
    </View>
    {onLike && <View style={styles.like}><IconButton label={liked ? 'Unlike' : 'Like'} icon={liked ? 'heart' : 'heart-outline'} active={liked} onPress={onLike}/></View>}
  </Pressable>;
}

const styles = StyleSheet.create({
  card: {height: 260, borderRadius: radius.card, overflow: 'hidden', backgroundColor: colors.surface}, compact: {width: 240, height: 300}, image: {width: '100%', height: '100%'},
  scrim: {...StyleSheet.absoluteFill, backgroundColor: 'rgba(0,0,0,.12)', borderRadius: radius.card}, info: {position: 'absolute', left: spacing.md, right: 60, bottom: spacing.md},
  title: {fontSize: 20, lineHeight: 24, letterSpacing: -0.3, fontWeight: '800', color: colors.text, textShadowColor: '#000', textShadowRadius: 8}, subtitle: {fontSize: 13, color: 'rgba(255,255,255,.82)', marginTop: 3},
  rating: {flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 6}, ratingText: {fontSize: 13, fontWeight: '700', color: colors.cream}, like: {position: 'absolute', right: 12, top: 12}, privateBadge:{alignSelf:'flex-start',flexDirection:'row',alignItems:'center',gap:4,backgroundColor:'rgba(20,20,22,.78)',borderRadius:10,paddingHorizontal:7,paddingVertical:4,marginBottom:6},privateText:{color:colors.text,fontSize:11,fontWeight:'800'},
});
