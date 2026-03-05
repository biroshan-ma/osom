class AppConfig {
  final String environment; // dev, staging, production
  final String apiBaseUrl;
  final String defaultSubDomain; // default sub-domain/prefix to use for requests that require Origin
  final String turnstileSiteKey; // client-side site key for turnstile (non-secret)
  final String turnstileHostedUrl; // HTTPS URL where the Turnstile page is hosted

  const AppConfig._({required this.environment, required this.apiBaseUrl, required this.defaultSubDomain, required this.turnstileSiteKey, required this.turnstileHostedUrl});

  const AppConfig.dev()
      : this._(
          environment: 'development',
          apiBaseUrl: 'https://climbing-fowl-popular.ngrok-free.app',
          defaultSubDomain: '.localhost:5173/',
          turnstileSiteKey: '0x4AAAAAAAfGaE18tbkrUnve',
          // for local dev you might host a local turnstile.html or use Cloudflare-hosted page
          turnstileHostedUrl: 'http://localhost:5173/turnstile.html',
        );
  const AppConfig.staging()
      : this._(
          environment: 'staging',
          apiBaseUrl: 'https://osom-staging-server.onrender.com',
          defaultSubDomain: '.osom.technimus.com',
          turnstileSiteKey: '0x4AAAAAAAfGaE18tbkrUnve',
          // The previous value pointed at the siteverify POST endpoint by mistake. Use a hosted page that renders the widget.
          turnstileHostedUrl: 'https://osom-staging-server.onrender.com/turnstile.html',
        );
  const AppConfig.production()
      : this._(
          environment: 'production',
          apiBaseUrl: 'https://api.osom.global',
          defaultSubDomain: '.osom.global',
          turnstileSiteKey: '0x4AAAAAAAfGaE18tbkrUnve',
          turnstileHostedUrl: 'https://app.osom.global/turnstile.html',
        );

  @override
  String toString() => 'AppConfig(environment: $environment, apiBaseUrl: $apiBaseUrl, defaultSubDomain: $defaultSubDomain, turnstileSiteKey: $turnstileSiteKey, turnstileHostedUrl: $turnstileHostedUrl)';
}
