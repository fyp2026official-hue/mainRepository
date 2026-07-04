class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'SPORTIFY_ADMIN_API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );

  static const tokenStorageKey = 'sportify_admin_token';
}
