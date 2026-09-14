import {Stack} from 'expo-router';
import {StatusBar} from 'expo-status-bar';
import {AppProvider} from '@/store/AppContext';
import {colors} from '@/theme';

export default function RootLayout() {
  return <AppProvider><StatusBar style="light"/><Stack screenOptions={{headerStyle: {backgroundColor: colors.background}, headerTintColor: colors.text, contentStyle: {backgroundColor: colors.background}, headerShadowVisible: false}}>
    <Stack.Screen name="index" options={{headerShown: false}}/><Stack.Screen name="(tabs)" options={{headerShown: false}}/>
    <Stack.Screen name="search" options={{presentation: 'modal', title: 'Search'}}/><Stack.Screen name="spot/[id]" options={{headerTransparent: true, title: ''}}/>
    <Stack.Screen name="trip/[id]" options={{title: 'Trip'}}/><Stack.Screen name="settings" options={{title: 'Settings'}}/>
    <Stack.Screen name="circles/index" options={{title: 'Circles'}}/><Stack.Screen name="circles/[id]" options={{title: 'Circle'}}/>
    <Stack.Screen name="invite/[token]" options={{title: 'Circle invite'}}/>
  </Stack></AppProvider>;
}
