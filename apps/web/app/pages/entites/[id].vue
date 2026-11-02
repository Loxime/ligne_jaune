<script setup lang="ts">
import type { Entity } from '~/types/entities'
import type { EntityNetworkIndexResponse } from '~/types/relationships'

const route = useRoute()
const id = String(route.params.id || '')

const { data, status, error } = await useFetch<{ data: Entity }>(
  `/api/entities/${encodeURIComponent(id)}`,
  { key: `lj-entity-detail-${id}` },
)

const entity = computed(() => data.value?.data)

const {
  data: network,
  status: networkStatus,
  error: networkError,
} = await useFetch<EntityNetworkIndexResponse>(
  `/api/entities/${encodeURIComponent(id)}/relationships`,
  { key: `lj-entity-network-${id}` },
)


useHead({
  title: computed(() =>
    entity.value
      ? `${entity.value.name} — Ligne Jaune`
      : 'Fiche documentaire — Ligne Jaune',
  ),
})

const kindNames: Record<string, string> = {
  person: 'Personne',
  company: 'Entreprise',
  association: 'Association',
  institution: 'Institution',
  other: 'Autre',
}
</script>

<template>
  <main class="profile-page">
    <div class="profile-wrap">
      <nav class="breadcrumbs" aria-label="Fil d'Ariane">
        <NuxtLink to="/entites">Entités</NuxtLink>
        <span aria-hidden="true">/</span>
        <span>Fiche documentaire</span>
      </nav>

      <div v-if="status === 'pending'" class="message">
        Chargement de la fiche…
      </div>

      <div v-else-if="error" class="message" role="alert">
        <h1>Fiche indisponible</h1>
        <p>
          Cette entité est introuvable ou son dossier ne peut pas
          être consulté actuellement.
        </p>
        <NuxtLink to="/entites">Retour au répertoire</NuxtLink>
      </div>

      <template v-else-if="entity">
        <header class="profile-hero">
          <p class="eyebrow">FICHE DOCUMENTAIRE</p>

          <div class="identity-row">
            <div class="avatar" aria-hidden="true">
              {{ entity.name.slice(0, 1).toUpperCase() }}
            </div>
            <div class="identity">
              <span class="kind">
                {{ kindNames[entity.kind] || entity.kind }}
              </span>
              <h1>{{ entity.name }}</h1>
              <p>{{ entity.description || 'Description non renseignée.' }}</p>
            </div>
          </div>

          <div class="identity-footer">
            <span>Identifiant : {{ entity.id }}</span>
            <NuxtLink to="/reseau">Explorer le réseau 3D</NuxtLink>
          </div>
        </header>

        <nav class="profile-tabs" aria-label="Sections du profil">
          <a href="#carriere">Carrière</a>
          <a href="#judiciaire">Judiciaire</a>
          <a href="#contacts">Contacts</a>
        </nav>

        <div class="profile-content">
          <section id="carriere" class="profile-card">
            <div class="section-heading">
              <span class="section-index">01</span>
              <div>
                <h2>Carrière et parcours</h2>
                <p>Fonctions, organisations et mandats documentés</p>
              </div>
            </div>

            <div class="empty-detail">
              <h3>Parcours non encore documenté</h3>
              <p>
                Cette section accueillera les fonctions actuelles
                et passées, les dates, les entreprises et les sources
                associées. Aucune expérience n'est supposée.
              </p>
            </div>
          </section>

          <section id="judiciaire" class="profile-card">
            <div class="section-heading">
              <span class="section-index">02</span>
              <div>
                <h2>Situation judiciaire</h2>
                <p>Affaires, procédures, décisions et sources</p>
              </div>
            </div>

            <div class="empty-detail">
              <h3>Aucune information judiciaire structurée</h3>
              <p>
                Le dossier ne dispose pas encore d'un historique
                judiciaire associé à cette interface. Cela ne
                préjuge ni de l'existence ni de l'absence d'affaires.
              </p>
            </div>
          </section>

          <section id="contacts" class="profile-card">
            <div class="section-heading">
              <span class="section-index">03</span>
              <div>
                <h2>Contacts et relations</h2>
                <p>Connexions et organisations liées à cette entité</p>
              </div>
            </div>

            <div class="empty-detail">
              <h3>Relations documentaires</h3>

              <p v-if="networkStatus === 'pending'">
                Chargement des relations…
              </p>

              <p v-else-if="networkError">
                Impossible de consulter les relations actuellement.
              </p>

              <p v-else-if="network">
                {{ network.pagination.returned }} relation(s)
                renvoyée(s) sur cette page.
                <span v-if="network.pagination.has_more">
                  D'autres résultats sont disponibles.
                </span>
              </p>

              <p>
                Les noms, fonctions et justificatifs seront affichés
                après validation du format détaillé des relations.
              </p>
              <NuxtLink to="/reseau">Ouvrir le réseau 3D</NuxtLink>
            </div>
          </section>
        </div>
      </template>
    </div>
  </main>
</template>

<style scoped>
.profile-page {
  min-height: 100vh;
  background: #f3f1ed;
  color: #24232b;
  padding: 28px 22px 96px;
}

.profile-wrap {
  max-width: 1080px;
  margin: 0 auto;
}

.breadcrumbs {
  display: flex;
  gap: 12px;
  align-items: center;
  margin-bottom: 24px;
  font-size: 13px;
  color: #77717d;
}

.breadcrumbs a {
  color: #5e4d75;
  text-decoration: none;
}

.profile-hero {
  padding: 38px;
  color: #f7f5f3;
  background: #211c32;
  border-radius: 16px 16px 0 0;
}

.eyebrow {
  color: #e6bd6c;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .14em;
}

.identity-row {
  display: flex;
  gap: 24px;
  margin-top: 26px;
  align-items: center;
}

.avatar {
  width: 90px;
  height: 90px;
  flex: 0 0 90px;
  border-radius: 18px;
  display: grid;
  place-items: center;
  background: #4b425d;
  color: #e6bd6c;
  font-size: 40px;
  font-weight: 800;
}

.identity {
  min-width: 0;
}

.kind {
  color: #e6bd6c;
  font-size: 12px;
}

h1 {
  font-size: clamp(30px, 5vw, 50px);
  letter-spacing: -.045em;
  margin: 8px 0 12px;
  overflow-wrap: anywhere;
}

.identity p {
  color: #d0cada;
  line-height: 1.65;
}

.identity-footer {
  display: flex;
  gap: 16px;
  justify-content: space-between;
  align-items: center;
  margin-top: 34px;
  font-size: 12px;
  color: #beb7ce;
  overflow-wrap: anywhere;
}

.identity-footer a {
  color: #e6bd6c;
}

.profile-tabs {
  display: flex;
  background: #fff;
  border: 1px solid #e0dce1;
  border-top: 0;
  overflow-x: auto;
}

.profile-tabs a {
  padding: 19px 28px;
  color: #34303e;
  text-decoration: none;
  font-weight: 650;
  border-right: 1px solid #eee9ed;
}

.profile-tabs a:hover {
  color: #805c27;
  background: #fbf6ea;
}

.profile-content {
  display: grid;
  gap: 22px;
  padding-top: 28px;
}

.profile-card {
  background: #fff;
  border: 1px solid #e1dce0;
  border-radius: 14px;
  padding: 30px;
  scroll-margin-top: 20px;
}

.section-heading {
  display: flex;
  gap: 18px;
  align-items: flex-start;
}

.section-index {
  color: #a58b57;
  font-size: 12px;
  font-weight: 800;
}

h2 {
  margin: 0 0 8px;
  font-size: 24px;
}

.section-heading p,
.empty-detail p {
  color: #706d75;
  line-height: 1.65;
}

.section-heading p {
  margin: 0;
}

.empty-detail {
  margin: 26px 0 0 30px;
  padding: 22px;
  background: #f8f7f5;
  border-left: 3px solid #d5bb83;
  border-radius: 0 8px 8px 0;
}

.empty-detail h3 {
  margin: 0 0 8px;
  font-size: 16px;
}

.empty-detail a {
  color: #655083;
}

.message {
  padding: 60px 28px;
  background: #fff;
  border-radius: 12px;
}

@media (max-width: 650px) {
  .profile-hero,
  .profile-card {
    padding: 22px;
  }

  .identity-row,
  .identity-footer {
    align-items: flex-start;
    flex-direction: column;
  }

  .empty-detail {
    margin-left: 0;
  }
}
</style>
