import {Ionicons} from '@expo/vector-icons';
import {Tabs} from 'expo-router';
import {ColorValue, View} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import {colors, shadows, spacing} from '@/theme';

const icon = (name: keyof typeof Ionicons.glyphMap) => {
  const TabIcon = ({color, focused, size}: {color: ColorValue; focused: boolean; size: number}) => (
    <View style={{width: 48, height: 34, borderRadius: 17, alignItems: 'center', justifyContent: 'center', backgroundColor: focused ? 'rgba(107,153,97,.20)' : 'transparent'}}>
      <Ionicons name={name} color={color} size={size}/>
    </View>
  );
  TabIcon.displayName = `TabIcon(${name})`;
  return TabIcon;
};
export default function TabLayout() {
  const insets = useSafeAreaInsets();
  return <Tabs screenOptions={{headerShown: false, tabBarShowLabel: false, tabBarHideOnKeyboard: true, tabBarActiveTintColor: colors.green, tabBarInactiveTintColor: colors.muted, tabBarIconStyle: {position: 'absolute', top: 9, width: 48, height: 36, margin: 0, alignItems: 'center', justifyContent: 'center'}, tabBarItemStyle: {height: 54, padding: 0, margin: 0, alignItems: 'center', justifyContent: 'center'}, tabBarStyle: {position: 'absolute', left: spacing.md, right: spacing.md, bottom: Math.max(insets.bottom, spacing.sm), height: 54, borderTopWidth: 0, borderRadius: 25, backgroundColor: colors.surface, paddingHorizontal: spacing.sm, paddingTop: 0, paddingBottom: 0, ...shadows.floating}}}>
    <Tabs.Screen name="index" options={{title: 'Home', tabBarIcon: icon('home-outline')}}/>
    <Tabs.Screen name="map" options={{title: 'Maps', tabBarIcon: icon('map-outline')}}/>
    <Tabs.Screen name="add" options={{title: 'Add', tabBarIcon: icon('add-circle')}}/>
    <Tabs.Screen name="trips" options={{href: null}}/>
    <Tabs.Screen name="profile" options={{title: 'Profile', tabBarIcon: icon('person-circle-outline')}}/>
  </Tabs>;
}
