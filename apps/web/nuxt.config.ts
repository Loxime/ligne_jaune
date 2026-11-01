export default defineNuxtConfig({
  compatibilityDate: '2026-11-01',

  devtools: {
    enabled: false,
  },

  css: [
    '~/assets/css/main.css',
  ],

  app: {
    head: {
      title: 'Ligne Jaune — Recherche documentaire',
      htmlAttrs: {
        lang: 'fr',
      },
      meta: [
        {
          name: 'description',
          content: 'Plateforme privée de recherche et de cartographie documentaire.',
        },
        {
          name: 'robots',
          content: 'noindex, nofollow, noarchive',
        },
      ],
    },
  },

  runtimeConfig: {
    apiBaseUrl: '',
    apiTokenFile: '',
  },
})
