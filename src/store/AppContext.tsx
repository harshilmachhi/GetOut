import AsyncStorage from '@react-native-async-storage/async-storage';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Linking from 'expo-linking';
import * as WebBrowser from 'expo-web-browser';
import type {Session} from '@supabase/supabase-js';
import React, {createContext, PropsWithChildren, useCallback, useContext, useEffect, useState} from 'react';
import {Platform} from 'react-native';
import {supabase} from '@/lib/supabase';
import {newId} from '@/lib/id';
import {normalizeTag} from '@/lib/tags';
import type {BeenThere, Block, Circle, CircleMember, Like, Profile, Rating, Spot, Trip, TripStop} from '@/types';

const CACHE_KEY = 'getout.public-cache.v1';

type ProfileDraft = Pick<Profile, 'username' | 'display_name' | 'bio' | 'cities_visited'>;
type SpotDraft = Omit<Spot, 'id' | 'owner_id' | 'created_at' | 'profiles' | 'ratings' | 'photo_urls' | 'circle_ids' | 'is_public'> & {photoUris: string[]; circleIds: string[]; isPublic: boolean};

interface AppValue {
  ready: boolean; refreshing: boolean; session: Session | null; profile: Profile | null;
  spots: Spot[]; likes: Like[]; beenThere: BeenThere[]; ratings: Rating[]; trips: Trip[]; tripStops: TripStop[]; blocks: Block[];
  circles: Circle[]; circleMembers: CircleMember[];
  refresh(): Promise<void>; signInGoogle(): Promise<void>; signInApple(): Promise<void>; signOut(): Promise<void>;
  createProfile(draft: ProfileDraft): Promise<void>; updateTaste(categories: string[], tags: string[]): Promise<void>;
  toggleLike(spotId: string): Promise<void>; toggleBeenThere(spotId: string): Promise<void>;
  setRating(spotId: string, stars: number): Promise<void>; setReview(spotId: string, stars: number, body: string): Promise<void>;
  reportReview(target: Rating, reason: string): Promise<void>;
  publishSpot(draft: SpotDraft): Promise<Spot>;
  deleteSpot(spotId: string): Promise<void>; createTrip(input: Pick<Trip, 'title' | 'summary' | 'start_date' | 'end_date'>): Promise<Trip>;
  updateTrip(trip: Trip): Promise<void>; deleteTrip(id: string): Promise<void>; addStop(tripId: string, spotId: string): Promise<void>;
  updateStop(stop: TripStop): Promise<void>; removeStop(id: string): Promise<void>; blockUser(id: string): Promise<void>;
  unblockUser(id: string): Promise<void>; reportSpot(spot: Spot, reason: string): Promise<void>; deleteAccount(): Promise<void>;
  createCircle(name: string, description: string): Promise<Circle>; deleteCircle(id: string): Promise<void>;
  createCircleInvite(circleId: string): Promise<string>; acceptCircleInvite(token: string): Promise<string>;
  removeCircleMember(circleId: string, userId: string): Promise<void>; leaveCircle(circleId: string): Promise<void>;
  revokeCircleInvites(circleId: string): Promise<void>;
}

const AppContext = createContext<AppValue | null>(null);

function parseOAuthUrl(url: string) {
  const normalized = url.replace('#', '?');
  const query = normalized.split('?')[1] ?? '';
  const values = new URLSearchParams(query);
  return {code: values.get('code'), access_token: values.get('access_token'), refresh_token: values.get('refresh_token'), error: values.get('error_description') ?? values.get('error')};
}

function normalizeSpot(row: Record<string, unknown>): Spot {
  const links = (row.spot_circles as {circle_id: string}[] | undefined) ?? [];
  return {...row, is_public: row.is_public !== false, circle_ids: links.map(link => link.circle_id)} as unknown as Spot;
}

async function signPrivatePhotos(items: Spot[], authenticated: boolean) {
  if (!authenticated) return items;
  const paths = items.flatMap(spot => spot.photo_urls.filter(url => url.startsWith('private:')).map(url => url.slice(8)));
  if (!paths.length) return items;
  const {data} = await supabase.storage.from('circle-spot-photos').createSignedUrls(paths, 300);
  const signed = new Map((data ?? []).map(item => [item.path, item.signedUrl]));
  return items.map(spot => ({...spot, photo_urls: spot.photo_urls.map(url => url.startsWith('private:') ? signed.get(url.slice(8)) ?? '' : url).filter(Boolean)}));
}

export function AppProvider({children}: PropsWithChildren) {
  const [ready, setReady] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [spots, setSpots] = useState<Spot[]>([]);
  const [likes, setLikes] = useState<Like[]>([]);
  const [beenThere, setBeenThere] = useState<BeenThere[]>([]);
  const [ratings, setRatings] = useState<Rating[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [tripStops, setTripStops] = useState<TripStop[]>([]);
  const [blocks, setBlocks] = useState<Block[]>([]);
  const [circles, setCircles] = useState<Circle[]>([]);
  const [circleMembers, setCircleMembers] = useState<CircleMember[]>([]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      const spotSelect = session?.user.id
        ? '*, profiles(username,display_name,avatar_system_image), ratings(id,spot_id,stars,user_id,review_body,created_at,updated_at,profiles(username,display_name,avatar_system_image)), spot_circles(circle_id)'
        : '*, profiles(username,display_name,avatar_system_image), ratings(id,spot_id,stars,user_id,review_body,created_at,updated_at,profiles(username,display_name,avatar_system_image))';
      const publicResult = await supabase.from('spots').select(spotSelect).order('created_at', {ascending: false}).limit(250);
      if (publicResult.error) throw publicResult.error;
      const visibleSpots = await signPrivatePhotos((publicResult.data ?? []).map(row => normalizeSpot(row as unknown as Record<string, unknown>)), !!session?.user.id);
      setSpots(visibleSpots);
      await AsyncStorage.setItem(CACHE_KEY, JSON.stringify(visibleSpots.filter(spot => spot.is_public)));
      if (!session?.user.id) { setProfile(null); setCircles([]); setCircleMembers([]); return; }
      const userId = session.user.id;
      const [profileResult, likesResult, beenThereResult, ratingsResult, tripsResult, stopsResult, blocksResult, circlesResult, membersResult] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', userId).maybeSingle(),
        supabase.from('likes').select('*'), supabase.from('been_there').select('*'),
        supabase.from('ratings').select('*').eq('user_id', userId), supabase.from('trips').select('*').order('start_date'),
        supabase.from('trip_stops').select('*').order('sort_order'), supabase.from('user_blocks').select('*'),
        supabase.from('circles').select('*').order('created_at'),
        supabase.from('circle_members').select('*, profiles(username,display_name,avatar_system_image)').order('joined_at'),
      ]);
      if (profileResult.error) throw profileResult.error;
      setProfile(profileResult.data as Profile | null);
      setLikes((likesResult.data ?? []) as Like[]); setBeenThere((beenThereResult.data ?? []) as BeenThere[]);
      setRatings((ratingsResult.data ?? []) as Rating[]); setTrips((tripsResult.data ?? []) as Trip[]);
      setTripStops((stopsResult.data ?? []) as TripStop[]); setBlocks((blocksResult.data ?? []) as Block[]);
      setCircles((circlesResult.data ?? []) as Circle[]); setCircleMembers((membersResult.data ?? []) as CircleMember[]);
    } finally { setRefreshing(false); }
  }, [session?.user.id]);

  useEffect(() => {
    AsyncStorage.getItem(CACHE_KEY).then(value => { if (value) setSpots((JSON.parse(value) as Spot[]).map(spot => ({...spot, is_public: spot.is_public !== false, circle_ids: spot.circle_ids ?? []}))); }).catch(() => {});
    supabase.auth.getSession().then(({data}) => { setSession(data.session); setReady(true); });
    const {data} = supabase.auth.onAuthStateChange((_event, next) => setSession(next));
    return () => data.subscription.unsubscribe();
  }, []);
  useEffect(() => { const timer = setTimeout(() => { if (ready) refresh().catch(() => {}); }, 0); return () => clearTimeout(timer); }, [ready, session?.user.id, refresh]);

  const signInGoogle = useCallback(async () => {
    // A development URL resolves to localhost on a physical phone. Always return
    // to the registered app scheme on native builds.
    const redirectTo = Platform.OS === 'web' ? Linking.createURL('login-callback') : 'getout://login-callback';
    const {data, error} = await supabase.auth.signInWithOAuth({provider: 'google', options: {redirectTo, skipBrowserRedirect: true}});
    if (error) throw error;
    const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
    if (result.type === 'success') {
      const tokens = parseOAuthUrl(result.url);
      if (tokens.error) throw new Error(tokens.error);
      if (tokens.code) {
        const {error: exchangeError} = await supabase.auth.exchangeCodeForSession(tokens.code);
        if (exchangeError) throw exchangeError;
      } else if (tokens.access_token && tokens.refresh_token) {
        const {error: sessionError} = await supabase.auth.setSession({access_token: tokens.access_token, refresh_token: tokens.refresh_token});
        if (sessionError) throw sessionError;
      } else {
        throw new Error('Google did not return a valid sign-in response. Please try again.');
      }
    }
  }, []);

  const signInApple = useCallback(async () => {
    if (Platform.OS !== 'ios') return;
    const credential = await AppleAuthentication.signInAsync({requestedScopes: [AppleAuthentication.AppleAuthenticationScope.FULL_NAME, AppleAuthentication.AppleAuthenticationScope.EMAIL]});
    if (!credential.identityToken) throw new Error('Apple did not return an identity token.');
    const {error} = await supabase.auth.signInWithIdToken({provider: 'apple', token: credential.identityToken});
    if (error) throw error;
  }, []);

  const requireUser = () => { if (!session?.user.id) throw new Error('Sign in is required.'); return session.user.id; };
  const createProfile = async (draft: ProfileDraft) => {
    const id = requireUser();
    const row = {...draft, id, username: draft.username.trim().toLowerCase(), avatar_system_image: 'person.fill', preferred_categories: [], preferred_tags: []};
    const {error} = await supabase.from('profiles').upsert(row);
    if (error) {
      if (error.code === '23505') throw new Error('That username is already taken. Please choose another one.');
      throw new Error(error.message);
    }
    await refresh();
  };
  const updateTaste = async (categories: string[], tags: string[]) => {
    const id = requireUser(); const {error} = await supabase.from('profiles').update({preferred_categories: categories, preferred_tags: [...new Set(tags.map(normalizeTag).filter(Boolean))]}).eq('id', id); if (error) throw error; await refresh();
  };
  const toggleLike = async (spotId: string) => {
    const userId = requireUser(); const current = likes.find(x => x.spot_id === spotId);
    if (current) { setLikes(x => x.filter(v => v.id !== current.id)); const {error} = await supabase.from('likes').delete().eq('user_id', userId).eq('spot_id', spotId); if (error) throw error; }
    else { const row = {id: newId(), user_id: userId, spot_id: spotId, created_at: new Date().toISOString()}; setLikes(x => [...x, row]); const {error} = await supabase.from('likes').upsert(row, {onConflict: 'user_id,spot_id'}); if (error) throw error; }
  };
  const toggleBeenThere = async (spotId: string) => {
    const userId = requireUser(); const current = beenThere.find(x => x.spot_id === spotId);
    if (current) { setBeenThere(x => x.filter(v => v.id !== current.id)); const {error} = await supabase.from('been_there').delete().eq('user_id', userId).eq('spot_id', spotId); if (error) throw error; }
    else { const row = {id: newId(), user_id: userId, spot_id: spotId, created_at: new Date().toISOString()}; setBeenThere(x => [...x, row]); const {error} = await supabase.from('been_there').upsert(row, {onConflict: 'user_id,spot_id'}); if (error) throw error; }
  };
  const setRating = async (spotId: string, stars: number) => {
    const userId = requireUser(); const current = ratings.find(x => x.spot_id === spotId);
    if (!stars) { setRatings(x => x.filter(v => v.spot_id !== spotId)); const {error} = await supabase.from('ratings').delete().eq('user_id', userId).eq('spot_id', spotId); if (error) throw error; await refresh(); }
    else {
      const {error} = await supabase.from('ratings').upsert({user_id: userId, spot_id: spotId, stars, review_body: current?.review_body ?? ''}, {onConflict: 'user_id,spot_id'}); if (error) throw error;
      await refresh();
    }
  };
  const setReview = async (spotId: string, stars: number, body: string) => {
    const userId = requireUser(); const reviewBody = body.trim();
    if (stars < 1 || stars > 5) throw new Error('Choose a star rating for your review.');
    if (reviewBody.length < 3 || reviewBody.length > 2000) throw new Error('Reviews must be between 3 and 2,000 characters.');
    const {error} = await supabase.from('ratings').upsert({user_id: userId, spot_id: spotId, stars, review_body: reviewBody}, {onConflict: 'user_id,spot_id'}); if (error) throw error;
    await refresh();
  };
  const publishSpot = async (draft: SpotDraft) => {
    const ownerId = requireUser(); const id = newId(); const photo_urls: string[] = [];
    if (!draft.isPublic && !draft.circleIds.length) throw new Error('Choose Public or at least one Circle.');
    const {circleIds, isPublic, photoUris, ...spotDraft} = draft;
    const initialRow = {...spotDraft, tags: [...new Set(spotDraft.tags.map(normalizeTag).filter(Boolean))], id, owner_id: ownerId, is_public: isPublic, photo_urls: [], created_at: new Date().toISOString()};
    const inserted = await supabase.from('spots').insert(initialRow).select('*').single();
    if (inserted.error) throw inserted.error;
    if (circleIds.length) {
      const shares = circleIds.map(circle_id => ({spot_id: id, circle_id, shared_by: ownerId}));
      const {error} = await supabase.from('spot_circles').insert(shares);
      if (error) { await supabase.from('spots').delete().eq('id', id); throw error; }
    }
    for (let index = 0; index < photoUris.length; index++) {
      const response = await fetch(photoUris[index]); const data = await response.arrayBuffer(); const path = `${ownerId}/${id}/${index}.jpg`;
      const bucket = isPublic ? 'spot-photos' : 'circle-spot-photos';
      const upload = await supabase.storage.from(bucket).upload(path, data, {contentType: 'image/jpeg', upsert: true}); if (upload.error) throw upload.error;
      photo_urls.push(isPublic ? supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl : `private:${path}`);
    }
    const result = await supabase.from('spots').update({photo_urls}).eq('id', id).select('*, profiles(username,display_name,avatar_system_image), spot_circles(circle_id)').single(); if (result.error) throw result.error;
    const [spot] = await signPrivatePhotos([normalizeSpot(result.data as Record<string, unknown>)], true); setSpots(x => [spot, ...x]); return spot;
  };
  const deleteSpot = async (spotId: string) => { const {error} = await supabase.from('spots').delete().eq('id', spotId); if (error) throw error; setSpots(x => x.filter(v => v.id !== spotId)); };
  const createTrip = async (input: Pick<Trip, 'title' | 'summary' | 'start_date' | 'end_date'>) => { const row = {...input, id: newId(), owner_id: requireUser(), plan_summary: '', cover_system_image: 'suitcase'}; const {error} = await supabase.from('trips').insert(row); if (error) throw error; setTrips(x => [...x, row]); return row; };
  const updateTrip = async (trip: Trip) => { const {error} = await supabase.from('trips').update(trip).eq('id', trip.id); if (error) throw error; setTrips(x => x.map(v => v.id === trip.id ? trip : v)); };
  const deleteTrip = async (id: string) => { const {error} = await supabase.from('trips').delete().eq('id', id); if (error) throw error; setTrips(x => x.filter(v => v.id !== id)); setTripStops(x => x.filter(v => v.trip_id !== id)); };
  const addStop = async (tripId: string, spotId: string) => { if (tripStops.some(x => x.trip_id === tripId && x.spot_id === spotId)) return; const row = {id: newId(), trip_id: tripId, spot_id: spotId, day_index: 0, sort_order: tripStops.filter(x => x.trip_id === tripId).length, notes: ''}; const {error} = await supabase.from('trip_stops').insert(row); if (error) throw error; setTripStops(x => [...x, row]); };
  const updateStop = async (stop: TripStop) => { const {error} = await supabase.from('trip_stops').update({day_index: stop.day_index, sort_order: stop.sort_order, notes: stop.notes}).eq('id', stop.id); if (error) throw error; setTripStops(x => x.map(v => v.id === stop.id ? stop : v)); };
  const removeStop = async (id: string) => { const {error} = await supabase.from('trip_stops').delete().eq('id', id); if (error) throw error; setTripStops(x => x.filter(v => v.id !== id)); };
  const blockUser = async (blocked_user_id: string) => { const row = {blocker_id: requireUser(), blocked_user_id}; const {error} = await supabase.from('user_blocks').upsert(row, {onConflict: 'blocker_id,blocked_user_id'}); if (error) throw error; await refresh(); };
  const unblockUser = async (id: string) => { const userId = requireUser(); const {error} = await supabase.from('user_blocks').delete().eq('blocker_id', userId).eq('blocked_user_id', id); if (error) throw error; setBlocks(x => x.filter(v => v.blocked_user_id !== id)); };
  const reportSpot = async (spot: Spot, reason: string) => { const {error} = await supabase.from('reports').insert({reporter_id: requireUser(), target_id: spot.id, target_owner_id: spot.owner_id, target_kind: 'spot', reason, details: ''}); if (error) throw error; };
  const reportReview = async (target: Rating, reason: string) => {
    const {error} = await supabase.from('reports').insert({reporter_id: requireUser(), target_id: target.id, target_owner_id: target.user_id, target_kind: 'review', reason, details: ''}); if (error) throw error;
  };
  const signOut = async () => { await supabase.auth.signOut(); setProfile(null); setSpots(items => items.filter(spot => spot.is_public)); setLikes([]); setBeenThere([]); setRatings([]); setTrips([]); setTripStops([]); setBlocks([]); setCircles([]); setCircleMembers([]); };
  const deleteAccount = async () => {
    const userId = requireUser();
    const {data: ownedSpots, error: spotsError} = await supabase.from('spots').select('id,is_public').eq('owner_id', userId);
    if (spotsError) throw spotsError;
    for (const spot of ownedSpots ?? []) {
      const bucket = spot.is_public ? 'spot-photos' : 'circle-spot-photos';
      const folder = `${userId}/${spot.id}`;
      const {data: files, error: listError} = await supabase.storage.from(bucket).list(folder, {limit: 100});
      if (listError) throw listError;
      const paths = (files ?? []).filter(file => file.id).map(file => `${folder}/${file.name}`);
      if (paths.length) {
        const {error: removeError} = await supabase.storage.from(bucket).remove(paths);
        if (removeError) throw removeError;
      }
    }
    const {error} = await supabase.rpc('delete_my_account'); if (error) throw error; await signOut();
  };

  const createCircle = async (name: string, description: string) => {
    const row = {id: newId(), owner_id: requireUser(), name: name.trim(), description: description.trim(), color: '#6B9961'};
    const {data, error} = await supabase.from('circles').insert(row).select('*').single();
    if (error) throw new Error(error.message);
    await refresh(); return data as Circle;
  };
  const deleteCircle = async (id: string) => { const {error} = await supabase.from('circles').delete().eq('id', id); if (error) throw error; await refresh(); };
  const createCircleInvite = async (circleId: string) => { const {data, error} = await supabase.rpc('create_circle_invite', {target_circle: circleId}); if (error) throw error; return data as string; };
  const acceptCircleInvite = async (token: string) => { const {data, error} = await supabase.rpc('accept_circle_invite', {raw_token: token}); if (error) throw error; await refresh(); return data as string; };
  const removeCircleMember = async (circleId: string, userId: string) => { const {error} = await supabase.from('circle_members').delete().eq('circle_id', circleId).eq('user_id', userId); if (error) throw error; await refresh(); };
  const leaveCircle = async (circleId: string) => removeCircleMember(circleId, requireUser());
  const revokeCircleInvites = async (circleId: string) => { const {error} = await supabase.rpc('revoke_circle_invites', {target_circle: circleId}); if (error) throw error; };

  const value: AppValue = {ready, refreshing, session, profile, spots: spots.filter(s => !blocks.some(b => b.blocked_user_id === s.owner_id)), likes, beenThere, ratings, trips, tripStops, blocks, circles, circleMembers, refresh, signInGoogle, signInApple, signOut, createProfile, updateTaste, toggleLike, toggleBeenThere, setRating, setReview, reportReview, publishSpot, deleteSpot, createTrip, updateTrip, deleteTrip, addStop, updateStop, removeStop, blockUser, unblockUser, reportSpot, deleteAccount, createCircle, deleteCircle, createCircleInvite, acceptCircleInvite, removeCircleMember, leaveCircle, revokeCircleInvites};
  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp() { const value = useContext(AppContext); if (!value) throw new Error('useApp must be used within AppProvider'); return value; }
