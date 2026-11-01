<script setup lang="ts">
async function logout() {
  await $fetch('/api/auth/logout', { method: 'POST' })
  await navigateTo('/login', { replace: true })
}

const { data: health } = await useFetch('/api/health')

const modules = [
  {
    title: 'Entités',
    description: 'Personnes, entreprises et institutions.',
    icon: '01',
  },
  {
    title: 'Relations',
    description: 'Liens documentés et périodes de validité.',
    icon: '02',
  },
  {
    title: 'Sources',
    description: 'Références et provenance des informations.',
    icon: '03',
  },
]
</script>

<template>
  <div class="app-shell">
    <header class="topbar">
      <div class="brand">
        <div class="brand-symbol">LJ</div>

        <div class="brand-copy">
          <strong>LIGNE JAUNE</strong>
          <span>RECHERCHE & CARTOGRAPHIE</span>
        </div>
      </div>

      <button class="environment-tag" type="button" @click="logout">Déconnexion</button>
    </header>

    <main class="main-content">
      <section class="hero">
        <span class="eyebrow">
          ESPACE DE RECHERCHE
        </span>

        <h1>
          Rendre les relations
          <em>lisibles.</em>
        </h1>

        <p class="hero-description">
          Une plateforme privée pour explorer les entités,
          documenter les relations et distinguer les faits
          établis des hypothèses de recherche.
        </p>

        <div class="system-status">
          <span
            class="status-indicator"
            :class="{ active: health?.status === 'ok' }"
          />

          <span>
            Frontend :
            {{ health?.status === 'ok' ? 'opérationnel' : 'indisponible' }}
          </span>

          <span class="status-separator">/</span>

          <span>API Symfony : non connectée</span>
        </div>
      </section>

      <section class="modules-section">
        <div class="section-heading">
          <span class="eyebrow">ARCHITECTURE FONCTIONNELLE</span>
          <h2>Modules de recherche</h2>
        </div>

        <div class="module-grid">
          <article
            v-for="module in modules"
            :key="module.icon"
            class="module-card"
          >
            <div class="module-number">
              {{ module.icon }}
            </div>

            <div>
              <h3>{{ module.title }}</h3>
              <p>{{ module.description }}</p>
            </div>

            <span class="module-state">
              EN PRÉPARATION
            </span>
          </article>
        </div>
      </section>

      <footer class="page-footer">
        <span>Ligne Jaune — environnement de développement</span>
        <span>Version 0.1.0</span>
      </footer>
    </main>
  </div>
</template>
