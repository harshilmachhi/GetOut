import {requireOptionalNativeModule} from 'expo-modules-core';
import {Platform} from 'react-native';

export type NativePlaceResult = {
  id: string;
  name: string;
  formattedAddress: string;
  latitude: number;
  longitude: number;
  city: string;
  district: string;
  region: string;
  country: string;
  countryCode: string;
};

type PlaceSearchModule = {search(query: string, latitude: number, longitude: number): Promise<NativePlaceResult[]>};

const nativeModule = Platform.OS === 'ios' ? requireOptionalNativeModule<PlaceSearchModule>('ExpoPlaceSearch') : null;

export const hasNativePlaceSearch = !!nativeModule;
export function searchNativePlaces(query: string, latitude: number, longitude: number) {
  return nativeModule?.search(query, latitude, longitude) ?? Promise.resolve([]);
}
