<script setup lang="ts">
import type { Entity, EntityKind } from '~/types/entities'

const props = defineProps<{
  entities: Entity[]
  demo: boolean
}>()

const emit = defineEmits<{
  select: [id: string]
}>()

const container = ref<HTMLElement | null>(null)

const colors: Record<EntityKind, string> = {
  person: '#E7BC69',
  company: '#7DAEE7',
  association: '#8DD0BC',
  institution: '#B89AE8',
  other: '#A9AFBF',
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, char => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[char] || char)
}

function graphData() {
  if (props.demo) {
    const kinds = Object.keys(colors) as EntityKind[]

    const nodes = Array.from({ length: 42 }, (_, index) => {
      const kind = kinds[index % kinds.length]!

      return {
        id: `demo-${index}`,
        name: `Entité fictive ${index + 1}`,
        label: `Entité fictive ${index + 1}`,
        kind,
        color: colors[kind],
        val: index % 9 === 0 ? 6 : 2,
      }
    })

    const links = nodes.slice(1).map((node, index) => ({
      source: nodes[Math.floor(index / 2)]!.id,
      target: node.id,
    }))

    return { nodes, links }
  }

  return {
    nodes: props.entities.map(entity => ({
      id: entity.id,
      name: entity.name,
      label: escapeHtml(entity.name),
      kind: entity.kind,
      color: colors[entity.kind],
      val: 3,
    })),
    links: [],
  }
}

let dispose = () => {}
let unmounted = false

onMounted(async () => {
  if (!container.value) return

  const { default: ForceGraph3D } = await import('3d-force-graph')

  if (!container.value || unmounted) return

  const element = container.value

  const graph = new ForceGraph3D(element)
    .backgroundColor('#11111D')
    .showNavInfo(false)
    .nodeColor('color')
    .nodeLabel('label')
    .nodeVal('val')
    .nodeOpacity(0.94)
    .linkColor(() => '#8E83B9')
    .linkOpacity(0.36)
    .linkDirectionalParticles(1)
    .linkDirectionalParticleSpeed(0.004)
    .width(Math.max(element.clientWidth, 320))
    .height(560)

  graph.onNodeClick(node => {
    if (!props.demo && typeof node.id === 'string') {
      emit('select', node.id)
    }
  })

  graph.graphData(graphData())

  const resizeObserver = new ResizeObserver(() => {
    graph.width(Math.max(element.clientWidth, 320))
  })

  resizeObserver.observe(element)

  const stopWatching = watch(
    () => [props.demo, props.entities],
    () => graph.graphData(graphData()),
    { deep: true },
  )

  dispose = () => {
    stopWatching()
    resizeObserver.disconnect()
    graph.pauseAnimation()
    graph.renderer().dispose()
    element.replaceChildren()
  }
})

onBeforeUnmount(() => {
  unmounted = true
  dispose()
})
</script>

<template>
  <div
    ref="container"
    class="graph-container"
    aria-label="Explorateur interactif du réseau en trois dimensions"
  />
</template>

<style scoped>
.graph-container {
  width: 100%;
  min-height: 560px;
  overflow: hidden;
  background: #11111d;
}
</style>
