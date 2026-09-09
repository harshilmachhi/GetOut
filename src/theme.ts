export const colors = {
  background: '#0B0B0D',
  surface: '#1B1B1E',
  surface2: '#242428',
  surfaceElevated: '#29292D',
  cream: '#F7F5ED',
  text: '#FFFFFF',
  muted: 'rgba(255,255,255,0.62)',
  subtle: 'rgba(255,255,255,0.38)',
  faint: 'rgba(255,255,255,0.10)',
  border: 'rgba(255,255,255,0.075)',
  green: '#6B9961',
  red: '#D95A52',
  orange: '#EB8C47',
  coffee: '#8C6647',
  purple: '#736BBF',
};

export const spacing = {xs: 4, sm: 8, md: 16, lg: 24, xl: 32};
export const radius = {control: 14, card: 20, pill: 999};

export const shadows = {
  card: {shadowColor: '#000', shadowOffset: {width: 0, height: 3}, shadowOpacity: 0.2, shadowRadius: 10, elevation: 3},
  floating: {shadowColor: '#000', shadowOffset: {width: 0, height: 7}, shadowOpacity: 0.34, shadowRadius: 18, elevation: 10},
};

export const categoryMeta = {
  nearby: {label: 'Nearby', icon: 'navigate', color: colors.green},
  views: {label: 'Views', icon: 'mountain', color: colors.orange},
  coffee: {label: 'Coffee', icon: 'cafe', color: colors.coffee},
  food: {label: 'Food', icon: 'restaurant', color: colors.red},
  nature: {label: 'Nature', icon: 'leaf', color: '#619E6B'},
  nightlife: {label: 'Nightlife', icon: 'moon', color: colors.purple},
} as const;
