<script setup lang="ts">
import type { Entity, EntityIndexResponse } from '~/types/entities'
import type {
  EntityRelationship,
  EntityNetworkIndexResponse,
  RelationStatus,
} from '~/types/relationships'

useHead({ title: 'Réseau documentaire — Ligne Jaune' })

const demo = ref(false)
const selectedRootId = ref('')
const selectedNodeId = ref<string | null>(null)
const selectedRelationId = ref<string | null>(null)
const statusFilter = ref<RelationStatus | 'all'>('reviewed')

const network = shallowRef<EntityNetworkIndexResponse | null>(null)
const loadingNetwork = ref(false)
const networkError = ref(false)

const { data: directory, error: directoryError } =
  await useFetch<EntityIndexResponse>('/api/entities', {
    key: 'lj-network-directory',
  })

const entities = computed(() => directory.value?.data ?? [])

const selectedRoot = computed<Entity | null>(() =>
  entities.value.find(e => e.id === selectedRootId.value) ?? null,
)

const relations = computed(() => network.value?.data ?? [])

const selectedRelation = computed<EntityRelationship | null>(() =>
  relations.value.find(r => r.id === selectedRelationId.value) ?? null,
)

const selectedNodeName = computed(() => {
  if (!selectedNodeId.value) return ''

  if (selectedRoot.value?.id === selectedNodeId.value) {
    return selectedRoot.value.name
  }

  for (const relation of relations.value) {
    if (relation.subject_entity_id === selectedNodeId.value) {
      return relation.subject_name
    }

    if (relation.object_entity_id === selectedNodeId.value) {
      return relation.object_name
    }
  }

  return ''
})

const statusLabels: Record<RelationStatus, string> = {
  reviewed: 'Révisée',
  draft: 'Brouillon',
  disputed: 'Contestée',
  retracted: 'Rétractée',
}

watch(entities, list => {
  if (list.length && !list.some(e => e.id === selectedRootId.value)) {
    selectedRootId.value = list[0]!.id
  }
}, { immediate: true })

let requestVersion = 0

watch([selectedRootId, statusFilter, demo], async () => {
  if (import.meta.server) return

  const version = ++requestVersion

  network.value = null
  selectedRelationId.value = null
  selectedNodeId.value = null
  networkError.value = false
  loadingNetwork.value = false

  if (demo.value || !selectedRootId.value) return

  loadingNetwork.value = true

  const params = new URLSearchParams({
    direction: 'both',
    limit: '100',
    offset: '0',
  })

  if (statusFilter.value !== 'all') {
    params.set('status', statusFilter.value)
  }

  try {
    const result = await $fetch<EntityNetworkIndexResponse>(
      `/api/entities/${selectedRootId.value}/relationships?${params}`,
    )

    if (version === requestVersion) {
      network.value = result
    }
  } catch {
    if (version === requestVersion) {
      networkError.value = true
    }
  } finally {
    if (version === requestVersion) {
      loadingNetwork.value = false
    }
  }
}, { immediate: true })

onBeforeUnmount(() => {
  requestVersion++
})
</script>

<template>
  <main class="network-page">
    <div class="network-container">
      <div class="network-heading">
        <p class="eyebrow">EXPLORATION DOCUMENTAIRE</p>
        <h1>Cartographie des relations</h1>
        <p class="subtitle">
          Explorez les connexions entre personnes et organisations.
          Chaque arête provient d'une relation enregistrée, avec
          son statut et sa source documentaire.
        </p>
      </div>

      <div class="toolbar">
        <label>
          Entité de départ
          <select v-model="selectedRootId" :disabled="demo">
            <option value="">Sélectionner une entité</option>
            <option
              v-for="entity in entities"
              :key="entity.id"
              :value="entity.id"
            >
              {{ entity.name }}
            </option>
          </select>
        </label>

        <label>
          Statut documentaire
          <select v-model="statusFilter" :disabled="demo">
            <option value="reviewed">Révisées</option>
            <option value="draft">Brouillons</option>
            <option value="disputed">Contestées</option>
            <option value="retracted">Rétractées</option>
            <option value="all">Tous les statuts</option>
          </select>
        </label>

        <label class="demo-control">
          <input v-model="demo" type="checkbox">
          Simulation fictive
        </label>
      </div>

      <div v-if="demo" class="notice demo-notice">
        MODE DÉMONSTRATION — Toutes les entités et connexions
        de ce mode sont fictives.
      </div>

      <div v-if="directoryError && !demo" class="notice" role="alert">
        Le répertoire d'entités est indisponible.
      </div>

      <div v-if="networkError && !demo" class="notice" role="alert">
        Impossible de charger les relations documentaires.
      </div>

      <div class="graph-frame">
        <ClientOnly>
          <RelationGraph3D
            :root="demo ? null : selectedRoot"
            :relations="demo ? [] : relations"
            :demo="demo"
            @select="selectedNodeId = $event"
            @select-relation="selectedRelationId = $event"
          />
          <template #fallback>
            <div class="fallback">Initialisation du graphe 3D…</div>
          </template>
        </ClientOnly>
      </div>

      <div class="graph-footer">
        <span v-if="demo">42 nœuds fictifs</span>
        <span v-else-if="loadingNetwork">Chargement des relations…</span>
        <span v-else>
          {{ relations.length }} relation(s) sur cette page
        </span>

        <span v-if="!demo && network?.pagination.has_more">
          Réseau partiel : d'autres relations sont disponibles.
        </span>
      </div>

      <div class="legend">
        <span><i class="dot reviewed" /> Révisée</span>
        <span><i class="dot draft" /> Brouillon</span>
        <span><i class="dot disputed" /> Contestée</span>
        <span><i class="dot retracted" /> Rétractée</span>
      </div>

      <section v-if="selectedNodeId && !demo" class="detail-panel">
        <p class="eyebrow">NŒUD SÉLECTIONNÉ</p>
        <h2>{{ selectedNodeName }}</h2>
        <NuxtLink :to="`/entites/${selectedNodeId}`">
          Consulter la fiche documentaire
        </NuxtLink>
      </section>

      <section v-if="selectedRelation && !demo" class="detail-panel">
        <p class="eyebrow">RELATION DOCUMENTÉE</p>
        <h2>
          {{ selectedRelation.subject_name }}
          <span aria-label="vers">→</span>
          {{ selectedRelation.object_name }}
        </h2>

        <p>Nature : {{ selectedRelation.relation_type }}</p>
        <p>
          Statut :
          {{ statusLabels[selectedRelation.status] }}
        </p>
        <p>
          Source : {{ selectedRelation.source_title }}
        </p>
        <p v-if="selectedRelation.source_locator">
          Référence : {{ selectedRelation.source_locator }}
        </p>
        <p>
          Éléments favorables :
          {{ selectedRelation.supporting_evidence_count }}
        </p>
        <p>
          Éléments contradictoires :
          {{ selectedRelation.contradictory_evidence_count }}
        </p>
        <p class="muted">
          Un lien enregistré n'établit pas, à lui seul,
          la réalité de tous les faits associés.
        </p>
      </section>

      <section v-if="!demo" class="relation-list">
        <h2>Relations de l'entité sélectionnée</h2>

        <p v-if="!selectedRoot && !directoryError">
          Aucune entité de départ disponible.
        </p>

        <p v-else-if="!loadingNetwork && !networkError && !relations.length">
          Aucune relation retournée pour le filtre sélectionné.
        </p>

        <button
          v-for="relation in relations"
          :key="relation.id"
          type="button"
          class="relation-item"
          @click="selectedRelationId = relation.id"
        >
          <strong>
            {{ relation.subject_name }} →
            {{ relation.object_name }}
          </strong>
          <span>
            {{ relation.relation_type }} ·
            {{ statusLabels[relation.status] }}
          </span>
        </button>
      </section>
    </div>
  </main>
</template>

<style scoped>
.network-page {
  min-height: 100vh;
  padding: 44px 24px 100px;
  background: #211c32;
  color: #f7f5f1;
}

.network-container {
  max-width: 1320px;
  margin: auto;
}

.network-heading {
  max-width: 850px;
  margin-bottom: 36px;
}

.eyebrow {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: .15em;
  color: #e6bd6c;
}

h1 {
  font-size: clamp(36px, 5vw, 68px);
  letter-spacing: -.05em;
  margin: 14px 0;
}

.subtitle {
  max-width: 730px;
  color: #c7c0d3;
  line-height: 1.7;
}

.toolbar {
  display: flex;
  gap: 22px;
  align-items: end;
  flex-wrap: wrap;
  padding: 20px;
  background: #171521;
  border: 1px solid #403a4d;
  border-radius: 12px 12px 0 0;
}

.toolbar label {
  display: grid;
  gap: 9px;
  font-size: 12px;
  color: #d1cadb;
}

.toolbar select {
  min-width: 210px;
  max-width: 350px;
  padding: 11px 13px;
  background: #2b2638;
  border: 1px solid #584e68;
  border-radius: 7px;
  color: white;
  font: inherit;
}

.toolbar .demo-control {
  display: flex;
  gap: 10px;
  align-items: center;
  padding-bottom: 12px;
}

.graph-frame {
  overflow: hidden;
  background: #11111d;
  border-inline: 1px solid #403a4d;
}

.fallback {
  display: grid;
  place-items: center;
  min-height: 560px;
}

.graph-footer {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  padding: 17px 20px;
  background: #171521;
  border: 1px solid #403a4d;
  border-radius: 0 0 12px 12px;
  font-size: 12px;
  color: #cbc5d8;
}

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
  margin: 22px 0 30px;
  font-size: 12px;
  color: #d8d2e3;
}

.legend span {
  display: flex;
  align-items: center;
  gap: 8px;
}

.dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  display: inline-block;
}

.reviewed { background: #85cba5; }
.draft { background: #d6ac64; }
.disputed { background: #e58b83; }
.retracted { background: #85818c; }

.detail-panel,
.relation-list {
  margin-top: 22px;
  padding: 24px;
  background: #171521;
  border: 1px solid #403a4d;
  border-radius: 12px;
}

.detail-panel h2 {
  overflow-wrap: anywhere;
}

.detail-panel p {
  color: #d4cfe0;
  line-height: 1.6;
  overflow-wrap: anywhere;
}

.detail-panel a {
  color: #e6bd6c;
}

.muted {
  font-size: 12px;
}

.relation-list h2 {
  margin-bottom: 20px;
}

.relation-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
  width: 100%;
  text-align: left;
  padding: 15px;
  margin-top: 8px;
  background: #282337;
  color: #f7f5f1;
  border: 1px solid #484053;
  border-radius: 8px;
  cursor: pointer;
  overflow-wrap: anywhere;
}

.relation-item span {
  font-size: 12px;
  color: #c8c1d3;
}

.notice {
  padding: 14px 20px;
  background: #583f2c;
  color: #fff0d6;
}

@media (max-width: 700px) {
  .toolbar {
    align-items: stretch;
    flex-direction: column;
  }

  .toolbar select {
    width: 100%;
    max-width: none;
  }

  .graph-footer {
    flex-direction: column;
  }
}
</style>
