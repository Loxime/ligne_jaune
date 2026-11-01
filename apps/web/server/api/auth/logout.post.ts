import { defineEventHandler } from 'nuxt/server'
import {
  getAuthSession,
  requireSameOrigin,
} from '../../utils/auth'

export default defineEventHandler(async (event) => {
  requireSameOrigin(event)
  event.res.headers.set('Cache-Control', 'no-store')

  const session = await getAuthSession(event)

  await session.clear()

  return { authenticated: false }
})
