import { defineEventHandler } from 'nuxt/server'
import { requireAdminSession } from '../../utils/auth'
import { getPrivateSymfonyJson } from '../../utils/symfony-api'

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')

  await requireAdminSession(event)
  await getPrivateSymfonyJson('/api/health/db')

  return {
    status: 'ok',
    service: 'ligne-jaune-api',
  }
})
