import { defineEventHandler } from 'nuxt/server'
import { revokeAdminSessionId } from '../../utils/session-store'
import {
  getAuthSession,
  requireSameOrigin,
} from '../../utils/auth'

export default defineEventHandler(async (event) => {
  requireSameOrigin(event)
  event.res.headers.set('Cache-Control', 'no-store')

  const session = await getAuthSession(event)

  await revokeAdminSessionId(session.data.sessionId)
  await session.clear()

  return { authenticated: false }
})
