import { defineEventHandler } from 'nuxt/server'
import { requireAdminSession } from '../../utils/auth'
import { getPrivateSymfonyJson } from '../../utils/symfony-api'

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')

  await requireAdminSession(event)

  return await getPrivateSymfonyJson('/api/entities')
})
