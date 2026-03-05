/// Helper to resolve an Origin header value from a tenant sub-domain and a default
/// suffix/template. This centralizes logic so all parts of the app construct Origins
/// consistently (used for login/logout/profile requests).

String? resolveOrigin(String? subDomain, String defaultSubDomain) {
  // Use explicit subDomain if provided
  final sd = (subDomain != null && subDomain.isNotEmpty) ? subDomain.trim() : null;
  if (sd == null) return null;

  // If caller provided a full URL, use as-is but normalize (remove trailing path)
  if (sd.startsWith('http://') || sd.startsWith('https://')) {
    final uri = Uri.tryParse(sd);
    if (uri == null) return sd;
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  // If the provided value is a host or host:port (contains '.' or ':'), treat it as hostname
  if (sd.contains('.') || sd.contains(':')) {
    final isLocalHost = sd.contains('localhost') || sd.contains('127.0.0.1');
    final scheme = isLocalHost ? 'http' : 'https';
    // If sd already contains port, keep it
    if (sd.contains(':')) {
      return '$scheme://$sd';
    }
    // Host only
    final host = sd;
    final portPart = isLocalHost && host.contains('localhost') ? ':5173' : '';
    return '$scheme://$host$portPart';
  }

  // If defaultSubDomain itself looks like a full template (contains scheme), try to use it
  if (defaultSubDomain.startsWith('http://') || defaultSubDomain.startsWith('https://')) {
    // replace placeholder if present
    if (defaultSubDomain.contains('{sub-domain}')) {
      final replaced = defaultSubDomain.replaceAll('{sub-domain}', sd);
      final uri = Uri.tryParse(replaced);
      if (uri == null) return replaced;
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    final uriStr = defaultSubDomain;
    if (uriStr.contains('{sub-domain}')) {
      final r = uriStr.replaceAll('{sub-domain}', sd);
      final uri = Uri.tryParse(r);
      if (uri == null) return r;
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    final u = Uri.tryParse(defaultSubDomain);
    if (u == null) return defaultSubDomain;
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  // Determine scheme: prefer http for localhost-like default suffixes, https otherwise
  final isDefaultLocal = defaultSubDomain.contains('localhost') || defaultSubDomain.contains('127.0.0.1');
  final scheme = isDefaultLocal ? 'http' : 'https';

  // Normalize suffix: ensure defaultSubDomain begins with '.' or '/'
  String suffix = defaultSubDomain;
  if (!suffix.startsWith('.') && !suffix.startsWith('/')) suffix = '.$suffix';

  // strip any trailing slash from suffix
  if (suffix.endsWith('/')) suffix = suffix.substring(0, suffix.length - 1);

  // Build origin (scheme://host[:port])
  return '$scheme://$sd$suffix';
}
