abstract class AppConstants {
  // Supabase local config — values from `supabase status`
  static const supabaseUrl = 'http://100.127.71.51:54321';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  // Storage buckets
  static const avatarsBucket = 'avatars';
  static const postMediaBucket = 'post-media';

  // Limits
  static const maxPostLength = 280;
  static const maxBioLength = 160;
  static const maxDisplayNameLength = 50;
  static const feedPageSize = 20;
}
