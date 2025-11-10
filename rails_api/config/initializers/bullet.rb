# frozen_string_literal: true

if defined?(Bullet)
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
  Bullet.add_footer = true

  # Skip certain paths if needed (e.g., health checks)
  # Bullet.skip_html_injection = false

  # Show stack traces for better debugging
  Bullet.stacktrace_includes = [
    'app/controllers',
    'app/models',
    'app/serializers'
  ]

  # Uncomment to raise errors in development (useful for CI)
  # Bullet.raise = true
end

