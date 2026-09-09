import type {Spot} from '@/types';

export interface Coordinate {latitude: number; longitude: number}

export function distanceMeters(a: Coordinate, b: Coordinate) {
  const radius = 6_371_000;
  const toRad = (n: number) => n * Math.PI / 180;
  const dLat = toRad(b.latitude - a.latitude);
  const dLon = toRad(b.longitude - a.longitude);
  const lat1 = toRad(a.latitude);
  const lat2 = toRad(b.latitude);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return radius * 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

export function distanceLabel(meters?: number) {
  if (meters == null) return 'Nearby';
  const miles = meters / 1609.344;
  return miles < 0.1 ? 'Nearby' : miles < 10 ? `${miles.toFixed(1)} mi` : `${Math.round(miles)} mi`;
}

export function isCannabisJurisdiction(countryCode: string, administrativeArea: string) {
  const country = countryCode.toUpperCase();
  const area = administrativeArea.toLowerCase();
  return country === 'CA' || (country === 'US' && (area === 'california' || area === 'ca'));
}

export function rankSpots(spots: Spot[], location?: Coordinate, categories: string[] = [], tags: string[] = []) {
  return spots.map(spot => {
    const distance = location ? distanceMeters(location, spot) : undefined;
    const proximity = distance == null ? 0.5 : Math.exp(-(distance / 1000) / 2);
    const tag = tags.length ? spot.tags.filter(value => tags.includes(value)).length / tags.length : 0.5;
    const category = categories.includes(spot.category) ? 1 : categories.length ? 0 : 0.5;
    const popularity = Math.max(0, Math.min(1, spot.rating / 5));
    const age = (Date.now() - new Date(spot.created_at).getTime()) / 86_400_000;
    const novelty = Math.max(0, 1 - age / 14);
    return {spot, distance, score: proximity * .3 + tag * .25 + category * .2 + popularity * .2 + novelty * .05};
  }).sort((a, b) => b.score - a.score || b.spot.rating - a.spot.rating);
}
