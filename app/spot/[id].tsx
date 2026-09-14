import {Ionicons} from '@expo/vector-icons';
import {router, useLocalSearchParams} from 'expo-router';
import React, {useMemo, useState} from 'react';
import {Alert, Dimensions, Image, KeyboardAvoidingView, Linking, Modal, Platform, Pressable, ScrollView, Share, StyleSheet, Text, View} from 'react-native';
import MapView, {Marker} from 'react-native-maps';
import {SafeAreaView} from 'react-native-safe-area-context';
import {spotImage} from '@/components/SpotCard';
import {Card, Chip, Field, IconButton, Muted, PrimaryButton, Screen, SectionTitle} from '@/components/ui';
import {useApp} from '@/store/AppContext';
import {colors, radius, spacing} from '@/theme';
import type {Rating, SpotRating} from '@/types';

export default function SpotDetail() {
  const {id} = useLocalSearchParams<{id: string}>();
  const app = useApp();
  const spot = app.spots.find(item => item.id === id);
  const myRating = app.ratings.find(item => item.spot_id === id);
  const [safety, setSafety] = useState(false);
  const [review, setReview] = useState(myRating?.review_body ?? '');
  const [reviewStars, setReviewStars] = useState(myRating?.stars ?? 0);
  const [submitting, setSubmitting] = useState(false);

  const blockedIds = useMemo(() => new Set(app.blocks.map(block => block.blocked_user_id)), [app.blocks]);
  const reviews = useMemo(() => (spot?.ratings ?? []).filter(item => item.review_body && !blockedIds.has(item.user_id)).sort(newestFirst), [blockedIds, spot?.ratings]);

  if (!spot) return <Screen><Muted>This spot is no longer available.</Muted></Screen>;

  const liked = app.likes.some(item => item.spot_id === spot.id);
  const been = app.beenThere.some(item => item.spot_id === spot.id);
  const selectedRating = myRating?.stars ?? 0;
  const publicRatings = spot.ratings ?? [];
  const average = publicRatings.length ? publicRatings.reduce((sum, item) => sum + item.stars, 0) / publicRatings.length : spot.rating;
  const photos = spot.photo_urls?.length ? spot.photo_urls.map(uri => ({uri})) : [spotImage(spot)];

  const requireAccount = (action: () => void) => app.session ? action() : router.push('/(tabs)/profile');
  const directions = () => {
    const label = encodeURIComponent(spot.title);
    const point = `${spot.latitude},${spot.longitude}`;
    Linking.openURL(Platform.OS === 'ios' ? `http://maps.apple.com/?ll=${point}&q=${label}` : `https://www.google.com/maps/search/?api=1&query=${point}`);
  };
  const updateRating = (stars: number) => requireAccount(() => {
    const clear = stars === selectedRating;
    if (clear && myRating?.review_body) {
      Alert.alert('Delete your review?', 'Clearing its rating also removes the written review.', [
        {text: 'Cancel', style: 'cancel'},
        {text: 'Delete', style: 'destructive', onPress: () => app.setRating(spot.id, 0).catch(showError('Could not delete review'))},
      ]);
      return;
    }
    app.setRating(spot.id, clear ? 0 : stars).catch(showError('Could not update rating'));
  });
  const submitReview = async () => {
    if (!app.session) return router.push('/(tabs)/profile');
    try {
      setSubmitting(true);
      await app.setReview(spot.id, reviewStars, review);
      Alert.alert(myRating?.review_body ? 'Review updated' : 'Review posted', 'Thanks for sharing your experience.');
    } catch (error) { showError('Could not save review')(error); }
    finally { setSubmitting(false); }
  };
  const deleteReview = () => Alert.alert('Delete your review?', 'Your star rating and written review will both be removed.', [
    {text: 'Cancel', style: 'cancel'},
    {text: 'Delete', style: 'destructive', onPress: () => app.setRating(spot.id, 0).catch(showError('Could not delete review'))},
  ]);
  const moderate = (target: SpotRating) => {
    const ownerId = target.user_id;
    const username = target.profiles?.username ?? 'this person';
    Alert.alert('Review options', undefined, [
      {text: 'Report', onPress: () => app.reportReview(target as Rating, 'inappropriate').then(() => Alert.alert('Report sent', 'Thanks for helping keep GetOut safe.')).catch(showError('Could not send report'))},
      {text: `Block @${username}`, style: 'destructive', onPress: () => app.blockUser(ownerId).catch(showError('Could not block user'))},
      {text: 'Cancel', style: 'cancel'},
    ]);
  };

  return <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
    <ScrollView contentInsetAdjustmentBehavior="never" keyboardShouldPersistTaps="handled" contentContainerStyle={styles.scrollContent}>
      <ScrollView horizontal pagingEnabled showsHorizontalScrollIndicator={false}>
        {photos.map((source, index) => <Image key={index} source={source} style={styles.hero}/>) }
      </ScrollView>
      <View style={styles.body}>
        <View style={styles.audience}><Ionicons name={spot.is_public ? 'earth' : 'lock-closed'} size={13} color={spot.is_public ? colors.orange : colors.green}/><Text style={styles.audienceText}>{spot.is_public ? (spot.circle_ids.length ? 'Public + Circles' : 'Public') : 'Circle only'}</Text></View>
        <Text style={styles.title}>{spot.title}</Text>
        <Muted>{[spot.neighborhood, spot.city].filter(Boolean).join(', ')}</Muted>
        <View style={styles.meta}><Ionicons name="star" size={17} color={colors.orange}/><Text style={styles.metaText}>{average ? average.toFixed(1) : 'Not rated'}</Text><Muted>· {publicRatings.length} rating{publicRatings.length === 1 ? '' : 's'}</Muted></View>

        <Card style={styles.rating}><Text style={styles.label}>{selectedRating ? `Your rating: ${selectedRating} of 5` : 'Rate this spot'}</Text><StarPicker value={selectedRating} onChange={updateRating}/><Muted>{myRating?.review_body ? 'Your written review is attached to this rating.' : 'Tap your selected star again to clear your rating.'}</Muted></Card>
        <View style={styles.actionRow}><Action icon={liked ? 'heart' : 'heart-outline'} label={liked ? 'Loved' : 'Love'} active={liked} onPress={() => requireAccount(() => app.toggleLike(spot.id).catch(showError('Could not update Love')))}/><Action icon={been ? 'checkmark-circle' : 'checkmark-circle-outline'} label={been ? 'Visited' : 'Mark visited'} active={been} onPress={() => requireAccount(() => app.toggleBeenThere(spot.id).catch(showError('Could not update visit')))}/></View>

        <SectionTitle>About this spot</SectionTitle><Text style={styles.details}>{spot.details || 'No description was provided for this spot.'}</Text><View style={styles.tags}>{spot.tags.map(tag => <Chip key={tag} label={`#${tag}`}/>)}</View>

        <View style={styles.communityHeader}><View><SectionTitle>Reviews</SectionTitle><Muted>{reviews.length} written review{reviews.length === 1 ? '' : 's'}</Muted></View>{!spot.is_public && <View style={styles.privateBadge}><Ionicons name="lock-closed" size={12} color={colors.green}/><Text style={styles.privateText}>Circle members</Text></View>}</View>
        <Card style={styles.composer}>
          {app.session ? <>
            <Text style={styles.label}>{myRating?.review_body ? 'Edit your review' : 'Write a review'}</Text>
            <Text style={styles.label}>Your rating</Text><StarPicker value={reviewStars} onChange={setReviewStars}/>
            <Field multiline maxLength={2000} value={review} onChangeText={setReview} placeholder="What should others know about this spot?" accessibilityLabel="Written review"/>
            <View style={styles.submitRow}><Muted>{review.trim().length}/2000</Muted><View style={styles.submitButton}><PrimaryButton title={submitting ? 'Saving…' : myRating?.review_body ? 'Update review' : 'Post review'} disabled={submitting || reviewStars === 0 || review.trim().length < 3} onPress={submitReview}/></View></View>
          </> : <PrimaryButton title="Sign in to write a review" icon="person" onPress={() => router.push('/(tabs)/profile')}/>}
        </Card>

        {!!reviews.length && reviews.map(item => <CommunityCard key={item.id} profile={item.profiles} date={item.updated_at} stars={item.stars} body={item.review_body} own={item.user_id === app.profile?.id} onMore={() => item.user_id === app.profile?.id ? deleteReview() : moderate(item)}/>)}
        {!reviews.length && <Card style={styles.emptyCommunity}><Ionicons name="star-outline" size={28} color={colors.muted}/><Muted>Be the first to write a helpful review of this spot.</Muted></Card>}

        <SectionTitle>Location</SectionTitle><MapView scrollEnabled={false} pitchEnabled={false} style={styles.map} initialRegion={{latitude: spot.latitude, longitude: spot.longitude, latitudeDelta: .012, longitudeDelta: .012}}><Marker coordinate={spot}/></MapView><Muted>{spot.address || `${spot.latitude.toFixed(5)}, ${spot.longitude.toFixed(5)}`}</Muted><PrimaryButton title="Get Directions" icon="navigate" onPress={directions}/>
        {spot.profiles && <><SectionTitle>Shared by</SectionTitle><Card style={styles.owner}><View style={styles.ownerAvatar}><Ionicons name="person" size={24} color={colors.muted}/></View><View><Text style={styles.label}>{spot.profiles.display_name}</Text><Muted>@{spot.profiles.username}</Muted></View></Card></>}
      </View>
    </ScrollView>

    <SafeAreaView pointerEvents="box-none" edges={['top']} style={styles.navLayer}><View style={styles.nav}><IconButton label="Back" icon="chevron-back" onPress={() => router.back()}/><View style={styles.navRight}><IconButton label="Share" icon="share-outline" onPress={() => Share.share({message: spot.is_public ? `${spot.title}\n${spot.address}` : `${spot.title}\nPrivate Circle spot — only current members can view the location in GetOut.`})}/><IconButton label="More" icon="ellipsis-horizontal" onPress={() => setSafety(true)}/></View></View></SafeAreaView>

    <Modal visible={safety} transparent animationType="fade" onRequestClose={() => setSafety(false)}><Pressable style={styles.backdrop} onPress={() => setSafety(false)}><Card style={styles.menu}><Text style={styles.label}>Safety options</Text>{['spam', 'inappropriate', 'unsafeLocation', 'other'].map(reason => <Pressable key={reason} onPress={() => requireAccount(() => app.reportSpot(spot, reason).then(() => {setSafety(false); Alert.alert('Report sent', 'Thanks for helping keep GetOut safe.');}).catch(showError('Could not send report')))} style={styles.menuRow}><Text style={styles.menuText}>Report: {reason}</Text></Pressable>)}{app.profile?.id !== spot.owner_id && <Pressable onPress={() => requireAccount(() => app.blockUser(spot.owner_id).then(() => {setSafety(false); router.back();}).catch(showError('Could not block user')))} style={styles.menuRow}><Text style={styles.danger}>Block @{spot.profiles?.username}</Text></Pressable>}</Card></Pressable></Modal>
  </KeyboardAvoidingView>;
}

function newestFirst(a: {updated_at: string}, b: {updated_at: string}) { return new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime(); }
function showError(title: string) { return (error: unknown) => Alert.alert(title, error instanceof Error ? error.message : String(error)); }
function StarPicker({value, onChange}: {value: number; onChange(value: number): void}) { return <View style={styles.stars}>{[1, 2, 3, 4, 5].map(star => <Pressable key={star} accessibilityLabel={`${star} stars`} accessibilityRole="button" onPress={() => onChange(star)} hitSlop={6}><Ionicons name={star <= value ? 'star' : 'star-outline'} size={31} color={colors.orange}/></Pressable>)}</View>; }
function Action({icon, label, active, onPress}: {icon: keyof typeof Ionicons.glyphMap; label: string; active?: boolean; onPress(): void}) { return <Pressable accessibilityRole="button" onPress={onPress} style={styles.action}><Ionicons name={icon} size={23} color={active ? colors.green : colors.text}/><Text style={[styles.actionText, active && {color: colors.green}]}>{label}</Text></Pressable>; }
function CommunityCard({profile, date, stars, body, own, onMore}: {profile?: {display_name: string; username: string}; date: string; stars?: number; body: string; own: boolean; onMore(): void}) { return <Card style={styles.communityCard}><View style={styles.entryHeader}><View style={styles.entryIdentity}><View style={styles.smallAvatar}><Ionicons name="person" size={17} color={colors.muted}/></View><View style={styles.identityText}><Text numberOfLines={1} style={styles.entryName}>{profile?.display_name ?? 'GetOut member'}</Text><Muted>@{profile?.username ?? 'member'} · {new Date(date).toLocaleDateString(undefined, {month: 'short', day: 'numeric'})}</Muted></View></View><Pressable accessibilityLabel={own ? 'Delete' : 'More options'} accessibilityRole="button" hitSlop={10} onPress={onMore}><Ionicons name={own ? 'trash-outline' : 'ellipsis-horizontal'} size={19} color={own ? colors.red : colors.muted}/></Pressable></View>{stars !== undefined && <View style={styles.inlineStars}>{[1, 2, 3, 4, 5].map(star => <Ionicons key={star} name={star <= stars ? 'star' : 'star-outline'} size={15} color={colors.orange}/>)}</View>}<Text style={styles.entryBody}>{body}</Text></Card>; }

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: colors.background}, scrollContent: {paddingBottom: 80}, hero: {width: Dimensions.get('window').width, height: 430},
  navLayer: {position: 'absolute', zIndex: 20, top: 0, left: 0, right: 0}, nav: {paddingHorizontal: spacing.md, paddingTop: spacing.xs, flexDirection: 'row', justifyContent: 'space-between'}, navRight: {flexDirection: 'row', gap: spacing.sm},
  body: {padding: spacing.lg, gap: spacing.md}, audience: {alignSelf: 'flex-start', flexDirection: 'row', alignItems: 'center', gap: 5, backgroundColor: colors.surface2, borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 6}, audienceText: {color: colors.text, fontSize: 12, fontWeight: '800'},
  title: {fontFamily: 'serif', fontSize: 34, fontWeight: '800', color: colors.cream}, meta: {flexDirection: 'row', alignItems: 'center', gap: 5}, metaText: {color: colors.text, fontWeight: '800'}, rating: {padding: spacing.md, gap: spacing.sm}, label: {color: colors.text, fontSize: 16, fontWeight: '700'}, stars: {flexDirection: 'row', justifyContent: 'space-between'},
  actionRow: {flexDirection: 'row', gap: spacing.sm}, action: {flex: 1, alignItems: 'center', gap: 6, paddingVertical: 12, borderRadius: radius.control, backgroundColor: colors.surface}, actionText: {fontSize: 12, color: colors.text, fontWeight: '700'}, details: {color: colors.text, fontSize: 16, lineHeight: 24}, tags: {flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm},
  communityHeader: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: spacing.sm}, privateBadge: {flexDirection: 'row', alignItems: 'center', gap: 5, borderRadius: radius.pill, backgroundColor: 'rgba(107,153,97,.16)', paddingHorizontal: 10, paddingVertical: 7}, privateText: {fontSize: 11, color: colors.green, fontWeight: '700'}, composer: {padding: spacing.md, gap: spacing.md}, submitRow: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', gap: spacing.md}, submitButton: {minWidth: 142},
  subheading: {fontSize: 16, color: colors.text, fontWeight: '800', marginTop: spacing.xs}, communityCard: {padding: spacing.md, gap: spacing.sm}, entryHeader: {flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center'}, entryIdentity: {flex: 1, flexDirection: 'row', alignItems: 'center', gap: spacing.sm}, identityText: {flex: 1}, smallAvatar: {width: 36, height: 36, borderRadius: 18, backgroundColor: colors.surface2, alignItems: 'center', justifyContent: 'center'}, entryName: {color: colors.text, fontWeight: '700'}, inlineStars: {flexDirection: 'row', gap: 2}, entryBody: {color: colors.text, fontSize: 15, lineHeight: 22}, emptyCommunity: {padding: spacing.lg, alignItems: 'center', gap: spacing.sm},
  map: {height: 210, borderRadius: radius.card}, owner: {padding: spacing.md, flexDirection: 'row', alignItems: 'center', gap: 12}, ownerAvatar: {width: 48, height: 48, borderRadius: 24, backgroundColor: colors.surface2, alignItems: 'center', justifyContent: 'center'},
  backdrop: {flex: 1, backgroundColor: 'rgba(0,0,0,.7)', justifyContent: 'flex-end', padding: spacing.lg}, menu: {padding: spacing.md}, menuRow: {paddingVertical: 15, borderBottomColor: colors.faint, borderBottomWidth: StyleSheet.hairlineWidth}, menuText: {color: colors.text}, danger: {color: colors.red, fontWeight: '700'},
});
