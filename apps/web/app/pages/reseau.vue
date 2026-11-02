<script setup lang="ts">
import type {
  Entity,
  EntityIndexResponse,
  EntityKind,
} from '~/types/entities'

useHead({ title: 'Réseau 3D — Ligne Jaune' })

const demo = ref(false)
const selectedId = ref<string | null>(null)
const selectedKind = ref<'all' | EntityKind>('all')

const { data, status, error, refresh } =
  await useFetch<EntityIndexResponse>('/api/entities', {
    key: 'lj-network-entities',
  })

const entities = computed(() => data.value?.data ?? [])

const visibleEntities = computed(() =>
  selectedKind.value === 'all'
    ? entities.value
    : entities.value.filter(e => e.kind === selectedKind.value),
)

const selectedEntity = computed<Entity | undefined>(() =>
  entities.value.find(e => e.id === selectedId.value),
)

const labels: Record<EntityKind, string> = {
  person: 'Personnes',
  company: 'Entreprises',
  association: 'Associations',
  institution: 'Institutions',
  other: 'Autres',
}
</script>

<template>
  <main class="network-page">
    <div class="network-heading">
      <div>
        <p class="network-eyebrow">CARTOGRAPHIE DOCUMENTAIRE</p>
        <h1>Explorer le réseau</h1>
        <p class="network-description">
          Naviguez librement dans l'espace, sélectionnez un nœud
          et consultez ses informations documentaires.
        </p>
      </div>

      <NuxtLink to="/entites" class="network-link">
        Répertoire des entités
      </NuxtLink>
    </div>

    <div class="network-toolbar">
      <label>
        Catégorie
        <select v-model="selectedKind" :disabled="demo">
          <option value="all">Toutes les entités</option>
          <option
            v-for="(label, kind) in labels"
            :key="kind"
            :value="kind"
          >
            {{ label }}
          </option>
        </select>
      </label>

      <label class="demo-toggle">
        <input v-model="demo" type="checkbox">
        Simulation 3D fictive
      </label>

      <button type="button" @click="refresh()">
        Actualiser
      </button>
    </div>

    <div v-if="error" class="network-notice" role="alert">
      Impossible de charger les entités.
    </div>

    <div v-if="demo" class="demo-notice">
      MODE DÉMONSTRATION — Les nœuds et liens affichés sont
      entièrement fictifs. Ils ne proviennent pas de la base.
    </div>

    <div class="graph-frame">
      <ClientOnly>
        <RelationGraph3D
          :entities="visibleEntities"
          :demo="demo"
          @select="selectedId = $event"
        />

        <template #fallback>
          <div class="graph-fallback">
            Initialisation de l'explorateur 3D…
          </div>
        </template>
      </ClientOnly>
    </div>

    <div class="network-footer">
      <span v-if="status === 'pending'">Chargement…</span>
      <span v-else-if="demo">42 entités fictives</span>
      <span v-else>
        {{ visibleEntities.length }} entité(s) sur la page chargée
      </span>

      <span v-if="!demo">
        Les relations réelles seront affichées après raccordement
        à l'API réseau Symfony.
      </span>
    </div>

    <section v-if="selectedEntity && !demo" class="selected-panel">
      <p class="network-eyebrow">ENTITÉ SÉLECTIONNÉE</p>

      <h2>{{ selectedEntity.name }}</h2>

      <p>{{ selectedEntity.description || 'Description non renseignée.' }}</p>

      <p class="entity-identifier">
        Identifiant : {{ selectedEntity.id }}
      </p>
    </section>

    <div v-if="!demo && entities.length === 0" class="network-notice">
      Aucune entité enregistrée. Activez la simulation pour
      visualiser le fonctionnement 3D sans créer de données.
    </div>
  </main>
</template>

<style scoped>
.network-page {
  min-height: 100vh;
  padding: 48px max(24px, calc((100vw - 1320px) / 2));
  background: #211c32;
  color: #f7f5f1;
}

.network-heading {
  display: flex;
  justify-content: space-between;
  align-items: end;
  gap: 32px;
  margin-bottom: 32px;
}

.network-eyebrow {
  color: #e5bb67;
  letter-spacing: .14em;
  font-size: 11px;
}

h1 {
  margin: 12px 0;
  font-size: clamp(36px, 5vw, 68px);
  letter-spacing: -.05em;
}

.network-description {
  max-width: 640px;
  color: #bfbace;
  line-height: 1.65;
}

.network-link {
  color: #e5bb67;
}

.network-toolbar {
  display: flex;
  align-items: center;
  gap: 24px;
  flex-wrap: wrap;
  padding: 18px;
  background: #171521;
  border: 1px solid #383244;
  border-radius: 12px 12px 0 0;
}

.network-toolbar label {
  display: flex;
  gap: 12px;
  align-items: center;
  color: #d1cbdf;
  font-size: 13px;
}

.network-toolbar select,
.network-toolbar button {
  padding: 10px;
  border: 1px solid #554c66;
  border-radius: 7px;
  background: #292437;
  color: #f7f5f1;
  font: inherit;
}

.network-toolbar button {
  cursor: pointer;
}

.demo-toggle {
  cursor: pointer;
}

.demo-notice {
  padding: 12px 18px;
  background: #4c391e;
  color: #ffe1a4;
  font-size: 12px;
}

.graph-frame {
  overflow: hidden;
  border: 1px solid #383244;
  background: #11111d;
}

.graph-fallback {
  display: grid;
  place-items: center;
  min-height: 560px;
  color: #bfbace;
}

.network-footer {
  display: flex;
  justify-content: space-between;
  gap: 20px;
  padding: 16px;
  color: #bfbace;
  background: #171521;
  border-radius: 0 0 12px 12px;
  font-size: 12px;
}

.selected-panel,
.network-notice {
  margin-top: 24px;
  padding: 24px;
  border: 1px solid #413a50;
  border-radius: 12px;
  background: #171521;
}

.selected-panel h2 {
  margin: 10px 0;
}

.selected-panel p {
  color: #c5c0cf;
}

.entity-identifier {
  overflow-wrap: anywhere;
  font-size: 12px;
}

@media (max-width: 700px) {
  .network-heading,
  .network-footer {
    align-items: flex-start;
    flex-direction: column;
  }

  .network-toolbar {
    align-items: stretch;
    flex-direction: column;
  }
}
</style>
