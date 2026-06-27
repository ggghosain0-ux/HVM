# branding_config.py - Centralized branding configuration for DICOT PANEL

BRANDING = {
    # Panel Names
    "panel_name": "DICOT PANEL",
    "short_name": "DICOT",
    "browser_title": "DICOT PANEL",
    
    # Visual Assets
    "favicon": "/static/img/favicon.png",
    "logo_path": "/static/img/logo.png",
    "logo_svg": """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 100" class="w-full h-full">
  <defs>
    <!-- Premium Gradients -->
    <linearGradient id="electricGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3b82f6" /> <!-- Electric Blue -->
      <stop offset="100%" stop-color="#06b6d4" /> <!-- Cyan -->
    </linearGradient>
    <linearGradient id="violetGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#06b6d4" /> <!-- Cyan -->
      <stop offset="100%" stop-color="#a855f7" /> <!-- Violet -->
    </linearGradient>
    <linearGradient id="accentGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#3b82f6" />
      <stop offset="50%" stop-color="#06b6d4" />
      <stop offset="100%" stop-color="#a855f7" />
    </linearGradient>
    
    <!-- Sophisticated Glow Filters -->
    <filter id="premiumGlow" x="-30%" y="-30%" width="160%" height="160%">
      <feGaussianBlur stdDeviation="6" result="blur" />
      <feMerge>
        <feMergeNode in="blur" opacity="0.6"/>
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
    <filter id="subtleGlow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur stdDeviation="3" result="blur" />
      <feMerge>
        <feMergeNode in="blur" opacity="0.4" />
        <feMergeNode in="SourceGraphic" />
      </feMerge>
    </filter>
  </defs>

  <!-- Abstract Futuristic DICOT Core Symbol -->
  <g transform="translate(10, 8)">
    <!-- Inner futuristic micro-grid structure -->
    <circle cx="42" cy="42" r="30" fill="none" stroke="rgba(59, 130, 246, 0.15)" stroke-width="1" stroke-dasharray="3 3"/>
    <line x1="12" y1="42" x2="72" y2="42" stroke="rgba(59, 130, 246, 0.1)" stroke-width="1"/>
    <line x1="42" y1="12" x2="42" y2="72" stroke="rgba(59, 130, 246, 0.1)" stroke-width="1"/>
    
    <!-- Intersecting Futuristic Ribbon (The 'D' & Virtualization Loop) -->
    <path d="M 32 18 C 50 14, 76 26, 76 45 C 76 64, 50 76, 32 72" fill="none" stroke="url(#accentGrad)" stroke-width="7.5" stroke-linecap="round" filter="url(#premiumGlow)"/>
    
    <!-- Outer sharp neon geometric shell -->
    <path d="M 24 16 L 38 16 C 56 16, 70 30, 70 45 C 70 60, 56 74, 38 74 L 24 74 Z" fill="none" stroke="url(#electricGrad)" stroke-width="3" stroke-linejoin="round" opacity="0.8"/>
    
    <!-- Core dynamic tech seed/node (Glows intensely in center-left) -->
    <circle cx="34" cy="45" r="8" fill="url(#violetGrad)" filter="url(#premiumGlow)" />
    <circle cx="34" cy="45" r="4" fill="#ffffff" />
    
    <!-- Floating node satellite orbits -->
    <circle cx="68" cy="32" r="3" fill="#06b6d4" filter="url(#subtleGlow)"/>
    <circle cx="56" cy="62" r="2.5" fill="#a855f7" filter="url(#subtleGlow)"/>
  </g>

  <!-- Premium Typography Area -->
  <text x="110" y="50" font-family="'Space Grotesk', system-ui, -apple-system, sans-serif" font-size="36" font-weight="900" fill="#ffffff" letter-spacing="4" filter="url(#subtleGlow)">
    DICOT
  </text>
  
  <text x="112" y="76" font-family="'Inter', system-ui, -apple-system, sans-serif" font-size="12" font-weight="700" fill="url(#violetGrad)" letter-spacing="9" opacity="0.95">
    P A N E L
  </text>
</svg>""",
    
    # Colors and Style Config
    "primary_color": "#05060f",
    "secondary_color": "#0a0e1e",
    "accent_color": "#22d3ee",         # Cyan-400
    "secondary_accent": "#a855f7",     # Purple-500
    "theme": "dark",
    
    # Typography
    "font_display": "'Space Grotesk', sans-serif",
    "font_sans": "'Inter', sans-serif",
    
    # Text and Copyrights
    "footer_text": "Powered by DICOT Panel",
    "copyright_text": "© 2026 DICOT PANEL. All rights reserved.",
    
    # Sub-Branding modules
    "login_branding": {
        "title": "Welcome back to DICOT",
        "subtitle": "Access the high-performance virtualization portal",
        "background": "bg-[#05060f]",
        "show_logo": True
    },
    
    "loading_screen_branding": {
        "title": "Booting DICOT Engine",
        "subtitle": "Preparing your performance virtualization environment..."
    }
}
