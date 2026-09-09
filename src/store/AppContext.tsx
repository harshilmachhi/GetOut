import AsyncStorage from '@react-native-async-storage/async-storage';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Linking from 'expo-linking';
import * as WebBrowser from 'expo-web-browser';
import type {Session} from '@supabase/supabase-js';
import React, {createContext, PropsWithChildren, useCallback, useContext, useEffect, useState} from 'react';
import {Platform} from 'react-native';
import {supabase} from '@/lib/supabase';
import {newId} from '@/lib/id';
import type {Block, Like, Profile, Rating, Save, Spot, Trip, TripStop} from '@/types';

const CACHE_KEY = 'getout.public-cache.v1';

type ProfileDraft = Pick<Profile, 'username' | 'display_name' | 'bio' | 'cities_visited'>;
type SpotDraft = Omit<Spot, 'id' | 'owner_id' | 'created_at' | 'profiles' | 'ratings' | 'photo_urls'> & {photoUris: string[]};

interface AppValue {
  ready: boolean; refreshing: boolean; session: Session | null; profile: Profile | null;
  spots: Spot[]; likes: Like[]; saves: Save[]; ratings: Rating[]; trips: Trip[]; tripStops: TripStop[]; blocks: Block[];
  refresh(): Promise<void>; signInGoogle(): Promise<void>; signInApple(): Promise<void>; signOut(): Promise<void>;
  createProfile(draft: ProfileDraft): Promise<void>; updateTaste(categories: string[], tags: string[]): Promise<void>;
  toggleLike(spotId: string): Promise<void>; toggleSave(spotId: string, list: Save['list']): Promise<void>;
  setRating(spotId: string, stars: number): Promise<void>; publishSpot(draft: SpotDraft): Promise<Spot>;
  deleteSpot(spotId: string): Promise<void>; createTrip(input: Pick<Trip, 'title' | 'summary' | 'start_date' | 'end_date'>): Promise<Trip>;
  updateTrip(trip: Trip): Promise<void>; deleteTrip(id: string): Promise<void>; addStop(tripId: string, spotId: string): Promise<void>;
  updateStop(stop: TripStop): Promise<void>; removeStop(id: string): Promise<void>; blockUser(id: string): Promise<void>;
  unblockUser(id: string): Promise<void>; reportSpot(spot: Spot, reason: string): Promise<void>; deleteAccount(): Promise<void>;
}

const AppContext = createContext<AppValue | null>(null);

function parseOAuthUrl(url: string) {
  const normalized = url.replace('#', '?');
  const query = normalized.split('?')[1] ?? '';
  const values = new URLSearchParams(query);
  return {access_token: values.get('access_token'), refresh_token: values.get('refresh_token')};
}

export function AppProvider({children}: PropsWithChildren) {
  const [ready, setReady] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [spots, setSpots] = useState<Spot[]>([]);
  const [likes, setLikes] = useState<Like[]>([]);
  const [saves, setSaves] = useState<Save[]>([]);
  const [ratings, setRatings] = useState<Rating[]>([]);
  const [trips, setTrips] = useState<Trip[]>([]);
  const [tripStops, setTripStops] = useState<TripStop[]>([]);
  const [blocks, setBlocks] = useState<Block[]>([]);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    try {
      const publicResult = await supabase.from('spots').select('*, profiles(username,display_name,avatar_system_image), ratings(stars,user_id)').order('created_at', {ascending: false}).limit(250);
      if (publicResult.error) throw publicResult.error;
      const publicSpots = (publicResult.data ?? []) as Spot[];
      setSpots(publicSpots);
      await AsyncStorage.setItem(CACHE_KEY, JSON.stringify(publicSpots));
      if (!session?.user.id) { setProfile(null); return; }
      const userId = session.user.id;
      const [profileResult, likesResult, savesResult, ratingsResult, tripsResult, stopsResult, blocksResult] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', userId).maybeSingle(),
        supabase.from('likes').select('*'), supabase.from('saves').select('*'),
        supabase.from('ratings').select('*').eq('user_id', userId), supabase.from('trips').select('*').order('start_date'),
        supabase.from('trip_stops').select('*').order('sort_order'), supabase.from('user_blocks').select('*'),
      ]);
      if (profileResult.error) throw profileResult.error;
      setProfile(profileResult.data as Profile | null);
      setLikes((likesResult.data ?? []) as Like[]); setSaves((savesResult.data ?? []) as Save[]);
      setRatings((ratingsResult.data ?? []) as Rating[]); setTrips((tripsResult.data ?? []) as Trip[]);
      setTripStops((stopsResult.data ?? []) as TripStop[]); setBlocks((blocksResult.data ?? []) as Block[]);
    } finally { setRefreshing(false); }
  }, [session?.user.id]);

  useEffect(() => {
    AsyncStorage.getItem(CACHE_KEY).then(value => { if (value) setSpots(JSON.parse(value)); }).catch(() => {});
    supabase.auth.getSession().then(({data}) => { setSession(data.session); setReady(true); });
    const {data} = supabase.auth.onAuthStateChange((_event, next) => setSession(next));
    return () => data.subscription.unsubscribe();
  }, []);
  useEffect(() => { const timer = setTimeout(() => { if (ready) refresh().catch(() => {}); }, 0); return () => clearTimeout(timer); }, [ready, session?.user.id, refresh]);

  const signInGoogle = useCallback(async () => {
    const redirectTo = Linking.createURL('login-callback');
    const {data, error} = await supabase.auth.signInWithOAuth({provider: 'google', options: {redirectTo, skipBrowserRedirect: true}});
    if (error) throw error;
    const result = await WebBrowser.openAuthSessionAsync(data.url, redirectTo);
    if (result.type === 'success') {
      const tokens = parseOAuthUrl(result.url);
      if (tokens.access_token && tokens.refresh_token) await supabase.auth.setSession({access_token: tokens.access_token, refresh_token: tokens.refresh_token});
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
    const {error} = await supabase.from('profiles').upsert(row); if (error) throw error; await refresh();
  };
  const updateTaste = async (categories: string[], tags: string[]) => {
    const id = requireUser(); const {error} = await supabase.from('profiles').update({preferred_categories: categories, preferred_tags: tags}).eq('id', id); if (error) throw error; await refresh();
  };
  const toggleLike = async (spotId: string) => {
    const userId = requireUser(); const current = likes.find(x => x.spot_id === spotId);
    if (current) { setLikes(x => x.filter(v => v.id !== current.id)); const {error} = await supabase.from('likes').delete().eq('user_id', userId).eq('spot_id', spotId); if (error) throw error; }
    else { const row = {id: newId(), user_id: userId, spot_id: spotId, created_at: new Date().toISOString()}; setLikes(x => [...x, row]); const {error} = await supabase.from('likes').upsert(row, {onConflict: 'user_id,spot_id'}); if (error) throw error; }
  };
  const toggleSave = async (spotId: string, list: Save['list']) => {
    const userId = requireUser(); const current = saves.find(x => x.spot_id === spotId && x.list === list);
    if (current) { setSaves(x => x.filter(v => v.id !== current.id)); const {error} = await supabase.from('saves').delete().eq('user_id', userId).eq('spot_id', spotId).eq('list', list); if (error) throw error; }
    else { const row = {id: newId(), user_id: userId, spot_id: spotId, list, created_at: new Date().toISOString()}; setSaves(x => [...x, row]); const {error} = await supabase.from('saves').upsert(row, {onConflict: 'user_id,spot_id,list'}); if (error) throw error; }
  };
  const setRating = async (spotId: string, stars: number) => {
    const userId = requireUser(); const current = ratings.find(x => x.spot_id === spotId);
    if (!stars) { setRatings(x => x.filter(v => v.spot_id !== spotId)); const {error} = await supabase.from('ratings').delete().eq('user_id', userId).eq('spot_id', spotId); if (error) throw error; }
    else { const row = {id: current?.id ?? newId(), user_id: userId, spot_id: spotId, stars, created_at: current?.created_at ?? new Date().toISOString()}; setRatings(x => [...x.filter(v => v.spot_id !== spotId), row]); const {error} = await supabase.from('ratings').upsert(row, {onConflict: 'user_id,spot_id'}); if (error) throw error; }
  };
  const publishSpot = async (draft: SpotDraft) => {
    const ownerId = requireUser(); const id = newId(); const photo_urls: string[] = [];
    for (let index = 0; index < draft.photoUris.length; index++) {
      const response = await fetch(draft.photoUris[index]); const data = await response.arrayBuffer(); const path = `${ownerId}/${id}/${index}.jpg`;
      const upload = await supabase.storage.from('spot-photos').upload(path, data, {contentType: 'image/jpeg', upsert: true}); if (upload.error) throw upload.error;
      photo_urls.push(supabase.storage.from('spot-photos').getPublicUrl(path).data.publicUrl);
    }
    const row = {...draft, id, owner_id: ownerId, photo_urls, created_at: new Date().toISOString()}; delete (row as Partial<typeof row>).photoUris;
    const result = await supabase.from('spots').insert(row).select('*, profiles(username,display_name,avatar_system_image)').single(); if (result.error) throw result.error;
    const spot = result.data as Spot; setSpots(x => [spot, ...x]); return spot;
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
  const signOut = async () => { await supabase.auth.signOut(); setProfile(null); setLikes([]); setSaves([]); setRatings([]); setTrips([]); setTripStops([]); setBlocks([]); };
  const deleteAccount = async () => { const {error} = await supabase.rpc('delete_my_account'); if (error) throw error; await signOut(); };

  const value: AppValue = {ready, refreshing, session, profile, spots: spots.filter(s => !blocks.some(b => b.blocked_user_id === s.owner_id)), likes, saves, ratings, trips, tripStops, blocks, refresh, signInGoogle, signInApple, signOut, createProfile, updateTaste, toggleLike, toggleSave, setRating, publishSpot, deleteSpot, createTrip, updateTrip, deleteTrip, addStop, updateStop, removeStop, blockUser, unblockUser, reportSpot, deleteAccount};
  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp() { const value = useContext(AppContext); if (!value) throw new Error('useApp must be used within AppProvider'); return value; }
