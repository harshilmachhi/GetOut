import React, {useState} from 'react';
import {Alert, Platform, StyleSheet, View} from 'react-native';
import {Ionicons} from '@expo/vector-icons';
import {useApp} from '@/store/AppContext';
import {colors, spacing} from '@/theme';
import {Chip, Field, Loading, Muted, PrimaryButton, Screen, SectionTitle, Title} from './ui';

const categories = ['views', 'coffee', 'food', 'nature', 'nightlife'];
const tags = ['sunset', 'view', 'quiet', 'cozy', 'hidden', 'waterfront', 'local', 'late-night', 'picnic'];

export function AccountGate({children}: React.PropsWithChildren) {
  const app = useApp();
  if (!app.ready || app.refreshing) return <Loading/>;
  if (!app.session) return <SignIn/>;
  if (!app.profile) return <CreateProfile/>;
  if (!app.profile.preferred_categories.length && !app.profile.preferred_tags.length) return <TasteSetup/>;
  return <>{children}</>;
}

function SignIn() {
  const {signInGoogle, signInApple} = useApp(); const [busy, setBusy] = useState(false);
  const run = async (action: () => Promise<void>) => { try { setBusy(true); await action(); } catch (e) { Alert.alert('Could not sign in', e instanceof Error ? e.message : String(e)); } finally { setBusy(false); } };
  return <Screen style={styles.center}>
    <Ionicons name="person-circle" size={66} color={colors.green}/><Title>Your GetOut account</Title>
    <Muted style={styles.centerText}>{"Sign in to keep your profile and saved spots available when you reinstall or change devices."}</Muted>
    {Platform.OS === 'ios' && <PrimaryButton title="Continue with Apple" icon="logo-apple" disabled={busy} onPress={() => run(signInApple)}/>}
    <PrimaryButton title="Continue with Google" icon="logo-google" disabled={busy} onPress={() => run(signInGoogle)}/>
    <Muted style={styles.centerText}>By continuing, you agree to the Terms and Privacy Policy.</Muted>
  </Screen>;
}

function CreateProfile() {
  const {createProfile, updateTaste} = useApp(); const [step, setStep] = useState(0); const [busy, setBusy] = useState(false);
  const [displayName, setDisplayName] = useState(''); const [username, setUsername] = useState(''); const [city, setCity] = useState(''); const [bio, setBio] = useState('');
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]); const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const toggle = (value: string, values: string[], setter: (v: string[]) => void) => setter(values.includes(value) ? values.filter(v => v !== value) : [...values, value]);
  const saveBasic = async () => { if (!displayName.trim() || !/^[a-z0-9_]{3,24}$/.test(username.trim().toLowerCase())) return Alert.alert('Check your details', 'Enter a display name and a 3–24 character username using letters, numbers, or underscores.'); try { setBusy(true); await createProfile({display_name: displayName.trim(), username, bio: bio.trim(), cities_visited: city.trim() ? [city.trim()] : []}); setStep(1); } catch (e) { Alert.alert('Could not create profile', e instanceof Error ? e.message : String(e)); } finally { setBusy(false); } };
  if (step === 1) return <Screen><Title>Your taste</Title><Muted>{"Pick what you're into — we'll personalize Discover from day one."}</Muted><SectionTitle>Spot types</SectionTitle><View style={styles.wrap}>{categories.map(v => <Chip key={v} label={v[0].toUpperCase() + v.slice(1)} selected={selectedCategories.includes(v)} onPress={() => toggle(v, selectedCategories, setSelectedCategories)}/>)}</View><SectionTitle>Vibes</SectionTitle><View style={styles.wrap}>{tags.map(v => <Chip key={v} label={v} selected={selectedTags.includes(v)} onPress={() => toggle(v, selectedTags, setSelectedTags)}/>)}</View><PrimaryButton title="Finish" disabled={busy} onPress={() => updateTaste(selectedCategories, selectedTags).catch(e => Alert.alert('Could not save', String(e)))}/></Screen>;
  return <Screen><Muted>Your account is ready. Now create your public profile.</Muted><Title>About you</Title><Muted>A few basics so friends can find you.</Muted><Field value={displayName} onChangeText={setDisplayName} placeholder="Display name"/><Field value={username} onChangeText={setUsername} autoCapitalize="none" placeholder="Username"/><Field value={city} onChangeText={setCity} placeholder="City"/><Field value={bio} onChangeText={setBio} placeholder="Bio" multiline/><PrimaryButton title={busy ? 'Creating profile…' : 'Continue'} disabled={busy} onPress={saveBasic}/></Screen>;
}

function TasteSetup() {
  const {updateTaste} = useApp(); const [selectedCategories, setSelectedCategories] = useState<string[]>([]); const [selectedTags, setSelectedTags] = useState<string[]>([]); const [busy, setBusy] = useState(false);
  const toggle = (value: string, values: string[], setter: (v: string[]) => void) => setter(values.includes(value) ? values.filter(v => v !== value) : [...values, value]);
  const finish = async () => { if (!selectedCategories.length && !selectedTags.length) return Alert.alert('Pick at least one', 'Choose a spot type or vibe so Discover can start personalized.'); try { setBusy(true); await updateTaste(selectedCategories, selectedTags); } catch (e) { Alert.alert('Could not save', String(e)); } finally { setBusy(false); } };
  return <Screen><Title>Your taste</Title><Muted>{"Pick what you're into — we'll personalize Discover from day one."}</Muted><SectionTitle>Spot types</SectionTitle><View style={styles.wrap}>{categories.map(v => <Chip key={v} label={v[0].toUpperCase() + v.slice(1)} selected={selectedCategories.includes(v)} onPress={() => toggle(v, selectedCategories, setSelectedCategories)}/>)}</View><SectionTitle>Vibes</SectionTitle><View style={styles.wrap}>{tags.map(v => <Chip key={v} label={v} selected={selectedTags.includes(v)} onPress={() => toggle(v, selectedTags, setSelectedTags)}/>)}</View><PrimaryButton title={busy ? 'Saving…' : 'Finish'} disabled={busy} onPress={finish}/></Screen>;
}

const styles = StyleSheet.create({center: {flexGrow: 1, justifyContent: 'center'}, centerText: {textAlign: 'center'}, wrap: {flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm}});
