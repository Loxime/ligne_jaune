import { defineEventHandler } from 'nuxt/server'
import { getAuthSession, isValidAdminSession } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')

  const session = await getAuthSession(event)

  const authenticated = await isValidAdminSession(session.data)

  return {
    authenticated,
    user: authenticated ? 'admin' : null,
  }
})
