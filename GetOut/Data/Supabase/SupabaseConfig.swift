import Foundation
import Supabase

enum SupabaseConfig {
    static let projectURL = URL(string: "https://wnhafdejexuzebwoglja.supabase.co")!
    static let authCallbackURL = URL(string: "getout://login-callback")!

    /// A publishable key is designed to ship in a client app. Database access is constrained by RLS.
    static let publishableKey = "sb_publishable_B0SmWopAwGAJo8nEiWB0KQ_nkb-h0ED"

    static let client = SupabaseClient(supabaseURL: projectURL, supabaseKey: publishableKey)
}
