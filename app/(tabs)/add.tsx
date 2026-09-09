import {Ionicons} from '@expo/vector-icons';
import * as ImagePicker from 'expo-image-picker';
import * as Location from 'expo-location';
import {router} from 'expo-router';
import React, {useCallback, useEffect, useRef, useState} from 'react';
import {ActivityIndicator, Alert, Image, Keyboard, Pressable, StyleSheet, Switch, Text, View} from 'react-native';
import MapView, {Marker, MapPressEvent} from 'react-native-maps';
import {AccountGate} from '@/components/AuthFlow';
import {Chip, Field, Muted, PrimaryButton, Screen, SectionTitle, Title} from '@/components/ui';
import {isCannabisJurisdiction} from '@/lib/geo';
import {hasNativePlaceSearch, searchNativePlaces} from '@/lib/placeSearch';
import {useCannabisAccess} from '@/hooks/useCannabisAccess';
import {useApp} from '@/store/AppContext';
import type {Category} from '@/types';
import {colors, radius, spacing} from '@/theme';

const categories: Category[] = ['views', 'coffee', 'food', 'nature', 'nightlife'];
type LocationSuggestion = {
  id: string;
  coordinate: {latitude: number; longitude: number};
  address: Location.LocationGeocodedAddress;
  title: string;
  subtitle: string;
};

type GooglePlace = {
  id: string;
  displayName?: {text?: string};
  formattedAddress?: string;
  location?: {latitude?: number; longitude?: number};
};

function locationLabel(address: Location.LocationGeocodedAddress) {
  const title = address.name || address.street || address.city || 'Location';
  const subtitle = [address.street && address.street !== title ? address.street : '', address.city, address.region, address.country]
    .filter(Boolean)
    .join(', ');
  return {title, subtitle};
}

export default function AddSpot() { return <AccountGate><AddForm/></AccountGate>; }
function AddForm() {
  const {publishSpot} = useApp(); const access = useCannabisAccess(); const [title, setTitle] = useState(''); const [details, setDetails] = useState(''); const [category, setCategory] = useState<Category>('views'); const [tag, setTag] = useState(''); const [tags, setTags] = useState<string[]>([]); const [photos, setPhotos] = useState<string[]>([]); const [query, setQuery] = useState(''); const [coordinate, setCoordinate] = useState({latitude: 43.6532, longitude: -79.3832}); const [address, setAddress] = useState<any>({}); const [cannabis, setCannabis] = useState(false); const [busy, setBusy] = useState(false);
  const [suggestions, setSuggestions] = useState<LocationSuggestion[]>([]); const [searching, setSearching] = useState(false); const [searchFocused, setSearchFocused] = useState(false); const searchSequence = useRef(0); const skipNextSearch = useRef(false); const searchCenter = useRef(coordinate);
  const reverse = async (value: typeof coordinate) => { searchCenter.current = value; setCoordinate(value); const [result] = await Location.reverseGeocodeAsync(value); if (result) setAddress(result); };
  const findSuggestions = useCallback(async (value: string, alertWhenEmpty = false) => {
    const trimmed = value.trim(); const sequence = ++searchSequence.current;
    if (trimmed.length < 2) { setSuggestions([]); setSearching(false); return; }
    setSearching(true);
    try {
      const placesKey = process.env.EXPO_PUBLIC_GOOGLE_PLACES_API_KEY;
      let resolved: (LocationSuggestion | null)[];
      if (hasNativePlaceSearch) {
        const center = searchCenter.current;
        const places = await searchNativePlaces(trimmed, center.latitude, center.longitude);
        resolved = places.map(place => ({
          id: place.id,
          coordinate: {latitude: place.latitude, longitude: place.longitude},
          address: {
            name: place.name,
            street: place.formattedAddress,
            city: place.city,
            district: place.district,
            region: place.region,
            country: place.country,
            isoCountryCode: place.countryCode,
          } as Location.LocationGeocodedAddress,
          title: place.name,
          subtitle: place.formattedAddress,
        }));
      } else if (placesKey && placesKey !== 'your_google_places_api_key') {
        const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
          method: 'POST',
          headers: {'Content-Type': 'application/json', 'X-Goog-Api-Key': placesKey, 'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location'},
          body: JSON.stringify({textQuery: trimmed, pageSize: 12, locationBias: {circle: {center: searchCenter.current, radius: 100000}}}),
        });
        if (!response.ok) throw new Error(`Places search failed (${response.status})`);
        const data = await response.json() as {places?: GooglePlace[]};
        resolved = await Promise.all((data.places ?? []).map(async place => {
          const latitude = place.location?.latitude, longitude = place.location?.longitude;
          if (latitude == null || longitude == null) return null;
          const resultCoordinate = {latitude, longitude};
          const [geocoded] = await Location.reverseGeocodeAsync(resultCoordinate);
          const fallbackAddress = {name: place.displayName?.text ?? null, street: place.formattedAddress ?? null} as Location.LocationGeocodedAddress;
          return {id: place.id, coordinate: resultCoordinate, address: geocoded ?? fallbackAddress, title: place.displayName?.text || 'Location', subtitle: place.formattedAddress || ''};
        }));
      } else {
        const queries = [trimmed, `${trimmed}, Toronto, Ontario`, `${trimmed}, Markham, Ontario`];
        const batches = await Promise.all(queries.map(searchQuery => Location.geocodeAsync(searchQuery)));
        const results = batches.flat().slice(0, 12);
        resolved = await Promise.all(results.map(async result => {
          const resultCoordinate = {latitude: result.latitude, longitude: result.longitude};
          const [place] = await Location.reverseGeocodeAsync(resultCoordinate); if (!place) return null;
          const label = locationLabel(place);
          return {id: `${result.latitude}:${result.longitude}`, coordinate: resultCoordinate, address: place, ...label};
        }));
      }
      if (sequence !== searchSequence.current) return;
      const unique = resolved.filter((item): item is LocationSuggestion => !!item).filter((item, index, all) => all.findIndex(other => other.title === item.title && other.subtitle === item.subtitle) === index);
      setSuggestions(unique);
      if (!unique.length && alertWhenEmpty) Alert.alert('No locations found', 'Try a place name, street address, or a nearby landmark.');
    } catch (error) {
      if (sequence === searchSequence.current && alertWhenEmpty) Alert.alert('Location search unavailable', error instanceof Error ? error.message : String(error));
    } finally { if (sequence === searchSequence.current) setSearching(false); }
  }, []);
  useEffect(() => {
    if (skipNextSearch.current) { skipNextSearch.current = false; return; }
    const timer = setTimeout(() => findSuggestions(query), 350);
    return () => clearTimeout(timer);
  }, [findSuggestions, query]);
  const selectSuggestion = (suggestion: LocationSuggestion) => { searchSequence.current += 1; skipNextSearch.current = true; searchCenter.current = suggestion.coordinate; setCoordinate(suggestion.coordinate); setAddress(suggestion.address); setQuery(suggestion.title); setSuggestions([]); setSearchFocused(false); Keyboard.dismiss(); };
  const search = () => { setSearchFocused(true); findSuggestions(query, true); };
  const useMyLocation = async () => { const current = await access.request(); if (current) await reverse(current); };
  const pick = async () => { const result = await ImagePicker.launchImageLibraryAsync({mediaTypes: ['images'], allowsMultipleSelection: true, selectionLimit: 5 - photos.length, quality: .85}); if (!result.canceled) setPhotos(v => [...v, ...result.assets.map(a => a.uri)].slice(0, 5)); };
  const addTag = () => { const value = tag.trim().toLowerCase(); if (value && !tags.includes(value)) setTags(v => [...v, value]); setTag(''); };
  const publish = async () => { const isCannabis = cannabis || tags.some(value => ['weed-friendly','weed','cannabis','420'].includes(value)); if (!title.trim() || !coordinate.latitude || !coordinate.longitude) return Alert.alert('Complete the spot', 'Add a name and pinned location.'); if (isCannabis && !access.ageConfirmed) return Alert.alert('Legal age confirmation','Cannabis-related spots are limited to adults physically in Canada or California and to spots located there.',[{text:'Cancel'},{text:'I am of legal age',onPress:()=>access.setAgeConfirmed(true)}]); if (isCannabis && !access.jurisdiction) return Alert.alert('Current location required','Allow location access so GetOut can confirm your current jurisdiction.'); if (isCannabis && (!isCannabisJurisdiction(access.jurisdiction?.countryCode ?? '', access.jurisdiction?.administrativeArea ?? '') || !isCannabisJurisdiction(address.isoCountryCode ?? '', address.region ?? ''))) return Alert.alert('Location not eligible', 'Weed-friendly spots require both you and the pinned spot to be in Canada or California.'); try { setBusy(true); const spot = await publishSpot({title: title.trim(), details: details.trim(), latitude: coordinate.latitude, longitude: coordinate.longitude, address: [address.name, address.street, address.city].filter(Boolean).join(', '), city: address.city ?? '', neighborhood: address.district ?? address.subregion ?? '', category, rating: 0, visit_hour: new Date().getHours(), visit_weekday: new Date().getDay() + 1, tags, contains_cannabis: isCannabis, country_code: address.isoCountryCode ?? '', administrative_area: address.region ?? '', photoUris: photos}); Alert.alert('Spot published!', undefined, [{text: 'View spot', onPress: () => router.push(`/spot/${spot.id}`)}]); } catch (e) { Alert.alert('Could not publish', e instanceof Error ? e.message : String(e)); } finally { setBusy(false); } };
  return <Screen><Title>Add a Spot</Title><SectionTitle>1  Choose a location</SectionTitle><View style={styles.locationSearch}><View style={styles.searchRow}><Field style={{flex: 1}} value={query} onChangeText={value => {setQuery(value); setSearchFocused(true)}} onFocus={() => setSearchFocused(true)} placeholder="Search for a place or address" returnKeyType="search" onSubmitEditing={search}/><Pressable onPress={search} style={styles.smallButton}>{searching ? <ActivityIndicator color={colors.green}/> : <Ionicons name="search" size={20} color={colors.text}/>}</Pressable></View>{searchFocused && (searching || suggestions.length > 0) && <View style={styles.suggestions}>{searching && !suggestions.length && <View style={styles.searchingRow}><ActivityIndicator size="small" color={colors.green}/><Muted>Finding places…</Muted></View>}{suggestions.map((suggestion, index) => <Pressable key={suggestion.id} onPress={() => selectSuggestion(suggestion)} style={[styles.suggestion, index < suggestions.length - 1 && styles.suggestionDivider]}><View style={styles.pin}><Ionicons name="location" size={18} color={colors.green}/></View><View style={{flex: 1}}><Text numberOfLines={1} style={styles.suggestionTitle}>{suggestion.title}</Text>{!!suggestion.subtitle && <Text numberOfLines={2} style={styles.suggestionSubtitle}>{suggestion.subtitle}</Text>}</View><Ionicons name="chevron-forward" size={17} color={colors.subtle}/></Pressable>)}</View>}</View><PrimaryButton title="Use my current location" icon="locate" onPress={useMyLocation}/><MapView style={styles.map} region={{...coordinate, latitudeDelta: .025, longitudeDelta: .025}} onPress={(e: MapPressEvent) => reverse(e.nativeEvent.coordinate)}><Marker draggable coordinate={coordinate} onDragEnd={e => reverse(e.nativeEvent.coordinate)}/></MapView><Muted>{[address.name, address.street, address.city, address.region].filter(Boolean).join(', ') || 'Tap the map to pin an exact location'}</Muted>
    <SectionTitle>2  Tell people about it</SectionTitle><Field value={title} onChangeText={setTitle} placeholder="Name this spot"/><Field value={details} onChangeText={setDetails} placeholder="What makes it special?" multiline/><View style={styles.wrap}>{categories.map(v => <Chip key={v} label={v[0].toUpperCase()+v.slice(1)} selected={category === v} onPress={() => setCategory(v)}/>)}</View>
    <View style={styles.searchRow}><Field style={{flex: 1}} value={tag} onChangeText={setTag} placeholder="Add a tag" onSubmitEditing={addTag}/><Pressable onPress={addTag} style={styles.smallButton}><Text style={styles.add}>Add</Text></Pressable></View><View style={styles.wrap}>{tags.map(v => <Chip key={v} label={`#${v}`} onPress={() => setTags(x => x.filter(t => t !== v))}/>)}</View>
    <SectionTitle>3  Add photos</SectionTitle><View style={styles.photos}>{photos.map(uri => <Image key={uri} source={{uri}} style={styles.photo}/>)}{photos.length < 5 && <Pressable onPress={pick} style={styles.photoAdd}><Ionicons name="images" size={28} color={colors.green}/><Text style={styles.add}>Add</Text></Pressable>}</View>
    <View style={styles.toggle}><View style={{flex: 1}}><Text style={styles.label}>Weed-friendly</Text><Muted>Shown only where legally eligible.</Muted></View><Switch value={cannabis} onValueChange={setCannabis} trackColor={{true: colors.green}}/></View><PrimaryButton title={busy ? 'Publishing…' : 'Publish spot'} disabled={busy} onPress={publish}/>
  </Screen>;
}
const styles = StyleSheet.create({locationSearch: {gap: spacing.sm}, searchRow: {flexDirection: 'row', gap: spacing.sm}, smallButton: {minWidth: 50, height: 50, borderRadius: radius.control, backgroundColor: colors.surface, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border, alignItems: 'center', justifyContent: 'center'}, suggestions: {backgroundColor: colors.surface, borderRadius: radius.control, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border, overflow: 'hidden'}, searchingRow: {minHeight: 56, paddingHorizontal: spacing.md, flexDirection: 'row', alignItems: 'center', gap: spacing.sm}, suggestion: {minHeight: 66, paddingHorizontal: spacing.md, paddingVertical: 11, flexDirection: 'row', alignItems: 'center', gap: 12}, suggestionDivider: {borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: colors.faint}, pin: {width: 34, height: 34, borderRadius: 17, backgroundColor: 'rgba(107,153,97,.16)', alignItems: 'center', justifyContent: 'center'}, suggestionTitle: {color: colors.text, fontSize: 15, fontWeight: '700'}, suggestionSubtitle: {color: colors.muted, fontSize: 12, lineHeight: 17, marginTop: 2}, map: {height: 260, borderRadius: 20}, wrap: {flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm}, photos: {flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm}, photo: {width: 94, height: 94, borderRadius: 14}, photoAdd: {width: 94, height: 94, borderRadius: 14, borderStyle: 'dashed', borderColor: colors.green, borderWidth: 1, alignItems: 'center', justifyContent: 'center'}, add: {color: colors.green, fontWeight: '700'}, toggle: {flexDirection: 'row', alignItems: 'center', padding: spacing.md, backgroundColor: colors.surface, borderRadius: 14}, label: {fontSize: 16, color: colors.text, fontWeight: '700'}});
