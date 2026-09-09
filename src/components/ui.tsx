import {Ionicons} from '@expo/vector-icons';
import React, {PropsWithChildren} from 'react';
import {ActivityIndicator, Pressable, ScrollView, StyleProp, StyleSheet, Text, TextInput, TextInputProps, View, ViewStyle} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {colors, radius, shadows, spacing} from '@/theme';

export function Screen({children, scroll = true, style}: PropsWithChildren<{scroll?: boolean; style?: StyleProp<ViewStyle>}>) {
  const content = scroll ? <ScrollView keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false} contentContainerStyle={[styles.content, style]}>{children}</ScrollView> : <View style={[styles.content, styles.fill, style]}>{children}</View>;
  return <SafeAreaView edges={['top']} style={styles.screen}>{content}</SafeAreaView>;
}
export function Title({children}: PropsWithChildren) { return <Text style={styles.title}>{children}</Text>; }
export function SectionTitle({children}: PropsWithChildren) { return <Text style={styles.sectionTitle}>{children}</Text>; }
export function Muted({children, style}: PropsWithChildren<{style?: object}>) { return <Text style={[styles.muted, style]}>{children}</Text>; }
export function Card({children, style}: PropsWithChildren<{style?: StyleProp<ViewStyle>}>) { return <View style={[styles.card, style]}>{children}</View>; }
export function Field(props: TextInputProps) { return <TextInput placeholderTextColor={colors.muted} {...props} style={[styles.field, props.multiline && styles.multiline, props.style]} />; }
export function PrimaryButton({title, onPress, disabled, icon, danger}: {title: string; onPress(): void; disabled?: boolean; icon?: keyof typeof Ionicons.glyphMap; danger?: boolean}) {
  return <Pressable accessibilityRole="button" disabled={disabled} onPress={onPress} style={({pressed}) => [styles.button, danger && styles.dangerButton, disabled && styles.disabled, pressed && styles.pressed]}>
    {icon && <Ionicons name={icon} size={19} color={colors.text}/>}<Text style={styles.buttonText}>{title}</Text>
  </Pressable>;
}
export function IconButton({icon, onPress, active, label}: {icon: keyof typeof Ionicons.glyphMap; onPress(): void; active?: boolean; label: string}) {
  return <Pressable accessibilityLabel={label} accessibilityRole="button" onPress={onPress} style={[styles.iconButton, active && styles.activeIcon]}><Ionicons name={icon} size={22} color={active ? colors.green : colors.text}/></Pressable>;
}
export function Chip({label, selected, onPress}: {label: string; selected?: boolean; onPress?(): void}) {
  return <Pressable disabled={!onPress} onPress={onPress} style={[styles.chip, selected && styles.selectedChip]}><Text style={[styles.chipText, selected && styles.selectedChipText]}>{label}</Text></Pressable>;
}
export function Loading({label = 'Connecting to GetOut…'}: {label?: string}) { return <View style={styles.loading}><ActivityIndicator color={colors.green}/><Muted>{label}</Muted></View>; }

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: colors.background}, content: {paddingHorizontal: spacing.md, paddingTop: spacing.md, paddingBottom: 116, gap: spacing.lg}, fill: {flex: 1},
  title: {fontFamily: 'serif', fontSize: 34, lineHeight: 41, letterSpacing: -0.7, fontWeight: '700', color: colors.cream, marginBottom: spacing.xs},
  sectionTitle: {fontSize: 20, lineHeight: 25, letterSpacing: -0.25, fontWeight: '700', color: colors.text}, muted: {fontSize: 14, lineHeight: 20, color: colors.muted},
  card: {backgroundColor: colors.surface, borderRadius: radius.card, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border, overflow: 'hidden', ...shadows.card},
  field: {height: 50, borderRadius: radius.control, backgroundColor: colors.surface, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border, paddingHorizontal: spacing.md, color: colors.text, fontSize: 16}, multiline: {height: 110, paddingTop: 14, textAlignVertical: 'top'},
  button: {height: 50, borderRadius: radius.control, backgroundColor: colors.green, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, paddingHorizontal: spacing.md, ...shadows.card},
  dangerButton: {backgroundColor: colors.red}, buttonText: {color: colors.text, fontSize: 16, fontWeight: '700'}, disabled: {opacity: .45}, pressed: {opacity: .75},
  iconButton: {height: 42, minWidth: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(12,12,14,.72)', borderWidth: StyleSheet.hairlineWidth, borderColor: 'rgba(255,255,255,.14)'}, activeIcon: {backgroundColor: 'rgba(107,153,97,.25)'},
  chip: {paddingHorizontal: 14, paddingVertical: 8, borderRadius: radius.pill, backgroundColor: colors.surface2, borderWidth: StyleSheet.hairlineWidth, borderColor: colors.border},
  selectedChip: {backgroundColor: 'rgba(107,153,97,.25)', borderColor: colors.green}, chipText: {color: colors.muted, fontWeight: '600'}, selectedChipText: {color: colors.text},
  loading: {flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center', gap: spacing.md},
});
