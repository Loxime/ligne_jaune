<script setup lang="ts">
async function logout() {
  await $fetch('/api/auth/logout', { method: 'POST' })
  await navigateTo('/login', { replace: true })
}
</script>

<template>
  <header class="lj-header">
    <div class="lj-topbar">
      <NuxtLink to="/" class="lj-brand">
        <span class="lj-mark">LJ.</span>
        <span>LIGNE JAUNE</span>
      </NuxtLink>

      <div class="lj-private">
        <span>PLATEFORME PRIVÉE</span>

        <button type="button" @click="logout">
          Déconnexion
        </button>
      </div>
    </div>

    <nav class="lj-nav" aria-label="Navigation principale">
      <NuxtLink to="/">Accueil</NuxtLink>
      <NuxtLink to="/entites">Entités</NuxtLink>
      <NuxtLink to="/reseau">Réseau 3D</NuxtLink>
    </nav>
  </header>
</template>

<style scoped>
.lj-header {
  position: relative;
  z-index: 10;
  background: #111017;
  color: #f8f7f4;
  font-family: inherit;
}

.lj-topbar {
  min-height: 68px;
  max-width: 1440px;
  margin: auto;
  padding: 12px 26px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.lj-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  color: inherit;
  text-decoration: none;
  font-size: 17px;
  font-weight: 800;
  letter-spacing: -.035em;
}

.lj-mark {
  padding: 7px 8px;
  border-radius: 5px;
  background: #e4bc69;
  color: #171419;
}

.lj-private {
  display: flex;
  align-items: center;
  gap: 24px;
  font-size: 11px;
  color: #a7a3ad;
}

.lj-private button {
  border: 1px solid #4d4754;
  border-radius: 24px;
  padding: 9px 15px;
  color: #f8f7f4;
  background: transparent;
  cursor: pointer;
}

.lj-nav {
  display: flex;
  flex-wrap: wrap;
  gap: 0;
  padding: 0 max(26px, calc((100% - 1388px) / 2));
  border-top: 1px solid #2d2935;
  border-bottom: 1px solid #393440;
}

.lj-nav a {
  padding: 16px 20px;
  text-decoration: none;
  color: #c8c4cc;
  font-size: 13px;
  border-right: 1px solid #34303a;
}

.lj-nav a:hover,
.lj-nav a.router-link-active {
  color: #e4bc69;
  background: #24202c;
}

@media (max-width: 600px) {
  .lj-private > span {
    display: none;
  }

  .lj-topbar {
    padding: 12px 16px;
  }

  .lj-nav a {
    padding: 12px 14px;
  }
}
</style>
