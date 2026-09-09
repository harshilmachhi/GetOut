import AsyncStorage from '@react-native-async-storage/async-storage';
import {useFocusEffect} from 'expo-router';
import {useCallback, useState} from 'react';
import {isCannabisJurisdiction} from '@/lib/geo';
import {useLocation} from './useLocation';

export const legalAgeKey = 'privacy.hasConfirmedCannabisLegalAge';
export function useCannabisAccess() {
  const geo = useLocation(); const [ageConfirmed, setAgeConfirmedState] = useState(false);
  useFocusEffect(useCallback(() => { let live = true; AsyncStorage.getItem(legalAgeKey).then(value => { if (live) setAgeConfirmedState(value === 'true'); }); return () => { live = false; }; }, []));
  const setAgeConfirmed = async (value: boolean) => { setAgeConfirmedState(value); await AsyncStorage.setItem(legalAgeKey, String(value)); };
  const jurisdictionAllowed = !!geo.jurisdiction && isCannabisJurisdiction(geo.jurisdiction.countryCode, geo.jurisdiction.administrativeArea);
  return {...geo, ageConfirmed, setAgeConfirmed, canAccessCannabis: ageConfirmed && jurisdictionAllowed};
}
