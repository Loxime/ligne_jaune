<script setup lang="ts">
import type { Entity, EntityKind } from '~/types/entities'
import type {
  EntityRelationship,
  RelationStatus,
} from '~/types/relationships'

const props = defineProps<{
  root: Entity | null
  relations: EntityRelationship[]
  demo: boolean
}>()

const emit = defineEmits<{
  select: [id: string]
  selectRelation: [id: string]
}>()

const container = ref<HTMLElement | null>(null)

const kindColors: Record<EntityKind, string> = {
  person: '#E7BC69',
  company: '#7DAEE7',
  association: '#8DD0BC',
  institution: '#B89AE8',
  other: '#A9AFBF',
}

const statusColors: Record<RelationStatus, string> = {
  reviewed: '#85CBA5',
  draft: '#D6AC64',
  disputed: '#E58B83',
  retracted: '#85818C',
}

function escapeHtml(value: string): string {
  const entities: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }

  return value.replace(/[&<>"']/g, char => entities[char] || char)
}

function graphData() {
  if (props.demo) {
    const kinds = Object.keys(kindColors) as EntityKind[]

    const nodes = Array.from({ length: 42 }, (_, i) => {
      const kind = kinds[i % kinds.length]!

      return {
        id: `demo-${i}`,
        label: `Entité fictive ${i + 1}`,
        color: kindColors[kind],
        val: i === 0 ? 8 : 3,
      }
    })

    const links = nodes.slice(1).map((node, index) => ({
      id: `demo-link-${index}`,
      source: nodes[Math.floor(index / 2)]!.id,
      target: node.id,
      label: 'Connexion fictive',
      color: '#8E83B9',
    }))

    return { nodes, links }
  }

  const nodes = new Map<string, {
    id: string
    label: string
    color: string
    val: number
  }>()

  function addNode(
    id: string,
    name: string,
    kind: EntityKind,
  ) {
    if (nodes.has(id)) return

    nodes.set(id, {
      id,
      label: escapeHtml(name),
      color: kindColors[kind],
      val: id === props.root?.id ? 9 : 3,
    })
  }

  if (props.root) {
    addNode(
      props.root.id,
      props.root.name,
      props.root.kind,
    )
  }

  const links = props.relations.map(relation => {
    addNode(
      relation.subject_entity_id,
      relation.subject_name,
      relation.subject_kind,
    )

    addNode(
      relation.object_entity_id,
      relation.object_name,
      relation.object_kind,
    )

    return {
      id: relation.id,
      source: relation.subject_entity_id,
      target: relation.object_entity_id,
      label: escapeHtml(
        `${relation.relation_type} — ${relation.status}`,
      ),
      color: statusColors[relation.status],
    }
  })

  return {
    nodes: [...nodes.values()],
    links,
  }
}

let disposed = false
let dispose = () => {}

onMounted(async () => {
  if (!container.value) return

  const { default: ForceGraph3D } = await import('3d-force-graph')

  if (disposed || !container.value) return

  const element = container.value

  const graph = new ForceGraph3D(element)
    .backgroundColor('#11111D')
    .showNavInfo(false)
    .nodeColor('color')
    .nodeLabel('label')
    .nodeVal('val')
    .linkColor('color')
    .linkLabel('label')
    .linkOpacity(0.65)
    .linkDirectionalArrowLength(3)
    .linkDirectionalArrowRelPos(0.8)
    .width(Math.max(element.clientWidth, 320))
    .height(560)

  graph.onNodeClick(node => {
    if (!props.demo && typeof node.id === 'string') {
      emit('select', node.id)
    }
  })

  graph.onLinkClick(link => {
    if (
      !props.demo
      && 'id' in link
      && typeof link.id === 'string'
    ) {
      emit('selectRelation', link.id)
    }
  })

  graph.graphData(graphData())

  const observer = new ResizeObserver(() => {
    graph.width(Math.max(element.clientWidth, 320))
  })

  observer.observe(element)

  const stopWatching = watch(
    [
      () => props.demo,
      () => props.root,
      () => props.relations,
    ],
    () => graph.graphData(graphData()),
  )

  dispose = () => {
    stopWatching()
    observer.disconnect()
    graph.pauseAnimation()
    graph.renderer().dispose()
    element.replaceChildren()
  }
})

onBeforeUnmount(() => {
  disposed = true
  dispose()
})
</script>

<template>
  <div
    ref="container"
    class="graph-container"
    aria-label="Graphe interactif des relations documentaires"
  />
</template>

<style scoped>
.graph-container {
  min-height: 560px;
  width: 100%;
  overflow: hidden;
  background: #11111d;
}
</style>
