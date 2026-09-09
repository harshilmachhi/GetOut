export type Category = 'nearby' | 'views' | 'coffee' | 'food' | 'nature' | 'nightlife';

export interface Profile {
  id: string; username: string; display_name: string; bio: string;
  avatar_system_image: string; cities_visited: string[];
  preferred_categories: Category[]; preferred_tags: string[]; created_at: string;
}

export interface Spot {
  id: string; owner_id: string; title: string; details: string;
  latitude: number; longitude: number; address: string; city: string;
  neighborhood: string; category: Category; rating: number;
  visit_hour: number; visit_weekday: number; photo_urls: string[]; tags: string[];
  contains_cannabis: boolean; country_code: string; administrative_area: string;
  created_at: string; profiles?: Pick<Profile, 'username' | 'display_name' | 'avatar_system_image'>;
  ratings?: {stars: number; user_id: string}[];
}

export interface Like {id: string; user_id: string; spot_id: string; created_at: string}
export interface Save {id: string; user_id: string; spot_id: string; list: 'saved' | 'beenThere'; created_at: string}
export interface Rating {id: string; user_id: string; spot_id: string; stars: number; created_at: string}
export interface Trip {id: string; owner_id: string; title: string; summary: string; plan_summary: string; start_date: string | null; end_date: string | null; cover_system_image: string}
export interface TripStop {id: string; trip_id: string; spot_id: string; day_index: number; sort_order: number; notes: string}
export interface Block {id: string; blocker_id: string; blocked_user_id: string; created_at: string}
