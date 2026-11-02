<script setup lang="ts">
import type {
  EntityIndexResponse,
  EntityKind,
} from '~/types/entities'

useHead({
  title: 'Entités — Ligne Jaune',
})

const kindLabels: Record<EntityKind, string> = {
  person: 'Personne',
  company: 'Entreprise',
  association: 'Association',
  institution: 'Institution',
  other: 'Autre',
}

const {
  data,
  status,
  error,
  refresh,
} = await useFetch<EntityIndexResponse>('/api/entities', {
  key: 'lj-entities-first-page',
})

const entities = computed(() => data.value?.data ?? [])
const pagination = computed(() => data.value?.pagination)

function formatDate(value: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value)

  if (!match) return value

  return `${match[3]}/${match[2]}/${match[1]}`
}
</script>

<template>
  <main class="entities-page">
    <div class="entities-container">
      <header class="entities-header">
        <NuxtLink to="/" class="back-link">
          ← Tableau de bord
        </NuxtLink>

        <span class="access-label">
          ESPACE PRIVÉ
        </span>
      </header>

      <section class="entities-intro">
        <p class="eyebrow">REGISTRE DOCUMENTAIRE</p>
        <h1>Entités</h1>
        <p class="intro-text">
          Consultation des personnes, entreprises, associations
          et institutions enregistrées dans Ligne Jaune.
        </p>
      </section>

      <section class="entities-panel">
        <div class="panel-heading">
          <div>
            <h2>Répertoire</h2>

            <p class="panel-description">
              Première page du registre, limitée à 20 entités.
            </p>
          </div>

          <button
            type="button"
            class="refresh-button"
            :disabled="status === 'pending'"
            @click="refresh()"
          >
            Actualiser
          </button>
        </div>

        <div
          v-if="status === 'pending'"
          class="state-message"
          role="status"
        >
          Chargement des entités…
        </div>

        <div
          v-else-if="error"
          class="state-message error-state"
          role="alert"
        >
          <h3>Consultation indisponible</h3>
          <p>
            Impossible de récupérer les entités.
            Vérifiez que Symfony est disponible.
          </p>
        </div>

        <div
          v-else-if="entities.length === 0"
          class="state-message empty-state"
        >
          <div class="empty-symbol">◇</div>
          <h3>Aucune entité enregistrée</h3>
          <p>
            Le registre ne contient actuellement aucun résultat.
            Aucune donnée fictive n'est affichée.
          </p>
        </div>

        <div v-else class="entity-list">
          <article
            v-for="entity in entities"
            :key="entity.id"
            class="entity-card"
          >
            <div class="entity-main">
              <span class="entity-kind">
                {{ kindLabels[entity.kind] }}
              </span>

              <h3>
                <NuxtLink
                  :to="`/entites/${entity.id}`"
                  class="entity-detail-link"
                >
                  {{ entity.name }}
                </NuxtLink>
              </h3>

              <p v-if="entity.description" class="entity-description">
                {{ entity.description }}
              </p>

              <p v-else class="entity-description muted">
                Aucune description renseignée.
              </p>
            </div>

            <div class="entity-meta">
              <span>Créée le {{ formatDate(entity.created_at) }}</span>
              <code :title="entity.id">
                {{ entity.id }}
              </code>
            </div>
          </article>
        </div>

        <footer v-if="pagination" class="panel-footer">
          <span>
            {{ pagination.returned }} résultat(s) affiché(s)
          </span>

          <span v-if="pagination.has_more">
            D'autres résultats sont disponibles.
          </span>

          <span v-else>
            Fin des résultats disponibles.
          </span>
        </footer>
      </section>
    </div>
  </main>
</template>

<style scoped>
.entities-page {
  min-height: 100vh;
  padding: 30px 24px 100px;
  background: #101318;
  color: #f2f1ed;
}

.entities-container {
  max-width: 1100px;
  margin: 0 auto;
}

.entities-header,
.panel-heading,
.panel-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 20px;
}

.back-link {
  color: #d3d6d8;
  text-decoration: none;
  font-size: 14px;
}

.back-link:hover {
  color: #e5bb52;
}

.access-label,
.eyebrow {
  font-size: 11px;
  letter-spacing: 0.14em;
  color: #e5bb52;
}

.entities-intro {
  padding: 76px 0 42px;
}

h1 {
  margin: 12px 0;
  font-size: clamp(40px, 6vw, 72px);
  letter-spacing: -0.055em;
}

.intro-text {
  max-width: 650px;
  line-height: 1.7;
  color: #a8adb5;
}

.entities-panel {
  overflow: hidden;
  border: 1px solid #30353d;
  border-radius: 14px;
  background: #1a1e24;
}

.panel-heading {
  padding: 26px;
  border-bottom: 1px solid #30353d;
}

.panel-heading h2 {
  margin: 0;
  font-size: 22px;
}

.panel-description {
  margin-bottom: 0;
  color: #a8adb5;
  font-size: 13px;
}

.refresh-button {
  padding: 10px 16px;
  border: 1px solid #5c5138;
  border-radius: 8px;
  background: #29271f;
  color: #e5bb52;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
}

.refresh-button:disabled {
  opacity: 0.5;
  cursor: wait;
}

.state-message {
  padding: 90px 25px;
  text-align: center;
  color: #a8adb5;
}

.state-message h3 {
  color: #f2f1ed;
}

.state-message p {
  max-width: 470px;
  margin: 12px auto;
  line-height: 1.6;
}

.empty-symbol {
  font-size: 46px;
  color: #e5bb52;
}

.error-state h3 {
  color: #f0a1a1;
}

.entity-card {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  padding: 24px 26px;
  border-bottom: 1px solid #30353d;
}

.entity-kind {
  display: inline-block;
  margin-bottom: 12px;
  padding: 5px 9px;
  border-radius: 5px;
  background: #302d23;
  color: #e5bb52;
  font-size: 11px;
}

.entity-main {
  min-width: 0;
}

.entity-main h3 {
  margin: 0;
  font-size: 20px;
  overflow-wrap: anywhere;
}

.entity-description {
  margin: 12px 0 0;
  max-width: 590px;
  color: #b8bcc3;
  line-height: 1.6;
  overflow-wrap: anywhere;
}

.muted {
  color: #797f89;
}

.entity-meta {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 12px;
  flex-shrink: 0;
  color: #a8adb5;
  font-size: 12px;
}

.entity-meta code {
  max-width: 220px;
  overflow-wrap: anywhere;
  text-align: right;
  font-size: 11px;
}

.panel-footer {
  padding: 20px 26px;
  color: #a8adb5;
  font-size: 12px;
}

@media (max-width: 700px) {
  .entities-header,
  .panel-heading,
  .panel-footer,
  .entity-card {
    align-items: flex-start;
    flex-direction: column;
  }

  .entities-intro {
    padding-top: 50px;
  }

  .entity-meta {
    align-items: flex-start;
  }

  .entity-meta code {
    text-align: left;
  }
}
.entity-detail-link {
  color: inherit;
  text-decoration: none;
}

.entity-detail-link:hover {
  color: #e5bb52;
  text-decoration: underline;
}

</style>
