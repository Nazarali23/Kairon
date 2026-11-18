/// KaironMobile Supabase Yapılandırması
class AppConfig {
  static const String supabaseUrl = 'https://qwvkgxyjjbuslzbaervr.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
      'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3dmtneHlqamJ1c2x6YmFlcnZyIiwicm9sZSI6Im'
      'Fub24iLCJpYXQiOjE3OTM2MjY1MTUsImV4cCI6MjEwOTIwMjUxNX0.'
      'JblAqF00gYoJGDqxHaErj7DRGMOOJTEqyHiJwTbHqgw';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('your-project');
}
