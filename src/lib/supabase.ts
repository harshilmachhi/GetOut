import 'expo-sqlite/localStorage/install';
import {createClient} from '@supabase/supabase-js';

const fallbackUrl = 'https://wnhafdejexuzebwoglja.supabase.co';
const fallbackKey = 'sb_publishable_B0SmWopAwGAJo8nEiWB0KQ_nkb-h0ED';

export const supabase = createClient(
  process.env.EXPO_PUBLIC_SUPABASE_URL ?? fallbackUrl,
  process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? fallbackKey,
  {auth: {storage: globalThis.localStorage, autoRefreshToken: true, persistSession: true, detectSessionInUrl: false}},
);
