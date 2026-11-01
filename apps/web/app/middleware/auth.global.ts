export default defineNuxtRouteMiddleware(async (to) => {
  let authenticated = false

  try {
    const response = import.meta.server
      ? await useRequestFetch()<{
          authenticated: boolean
        }>('/api/auth/me')
      : await $fetch<{
          authenticated: boolean
        }>('/api/auth/me')

    authenticated = response.authenticated === true
  } catch {
    authenticated = false
  }

  if (!authenticated && to.path !== '/login') {
    return navigateTo('/login')
  }

  if (authenticated && to.path === '/login') {
    return navigateTo('/')
  }
})
