import {Ionicons} from '@expo/vector-icons';
import {Tabs} from 'expo-router';
import {colors, shadows, spacing} from '@/theme';

const icon = (name: keyof typeof Ionicons.glyphMap) => {
  const TabIcon = ({color, size}: {color: any; size: number}) => <Ionicons name={name} color={color} size={size}/>;
  TabIcon.displayName = `TabIcon(${name})`;
  return TabIcon;
};
export default function TabLayout() {
  return <Tabs screenOptions={{headerShown: false, tabBarShowLabel: false, tabBarActiveTintColor: colors.green, tabBarInactiveTintColor: colors.muted, tabBarItemStyle: {marginVertical: spacing.sm, borderRadius: 18}, tabBarActiveBackgroundColor: 'rgba(107,153,97,.18)', tabBarStyle: {position: 'absolute', left: spacing.lg, right: spacing.lg, bottom: spacing.sm, height: 60, borderTopWidth: 0, borderRadius: 28, backgroundColor: colors.surface, paddingHorizontal: spacing.sm, ...shadows.floating}}}>
    <Tabs.Screen name="index" options={{title: 'Home', tabBarIcon: icon('home-outline')}}/>
    <Tabs.Screen name="map" options={{title: 'Maps', tabBarIcon: icon('map-outline')}}/>
    <Tabs.Screen name="add" options={{title: 'Add', tabBarIcon: icon('add-circle')}}/>
    <Tabs.Screen name="trips" options={{title: 'Trip', tabBarIcon: icon('briefcase-outline')}}/>
    <Tabs.Screen name="profile" options={{title: 'Profile', tabBarIcon: icon('person-circle-outline')}}/>
  </Tabs>;
}
