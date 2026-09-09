import * as Location from 'expo-location';
import {useEffect, useState} from 'react';
import type {Coordinate} from '@/lib/geo';

export function useLocation() {
  const [location, setLocation] = useState<Coordinate>();
  const [jurisdiction, setJurisdiction] = useState<{countryCode: string; administrativeArea: string}>();
  const request = async () => {
    const permission = await Location.requestForegroundPermissionsAsync(); if (!permission.granted) return undefined;
    const value = await Location.getCurrentPositionAsync({accuracy: Location.Accuracy.Balanced});
    const coordinate = {latitude: value.coords.latitude, longitude: value.coords.longitude}; setLocation(coordinate);
    const [address] = await Location.reverseGeocodeAsync(coordinate); if (address) setJurisdiction({countryCode: address.isoCountryCode ?? '', administrativeArea: address.region ?? ''});
    return coordinate;
  };
  useEffect(() => { const timer = setTimeout(() => request().catch(() => {}), 0); return () => clearTimeout(timer); }, []);
  return {location, jurisdiction, request};
}
