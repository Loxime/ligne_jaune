<script setup lang="ts">
const route = useRoute()
</script>

<template>
  <LigneJauneHeader v-if="route.path !== '/login'" />
  <NuxtPage />
</template>
