import { defineEventHandler } from 'nuxt/server'
import { getAuthSession } from '../../utils/auth'

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')

  const session = await getAuthSession(event)

  const authenticated = (
    session.data.user === 'admin'
    && typeof session.data.issuedAt === 'number'
    && Date.now() - session.data.issuedAt <= 2 * 60 * 60 * 1000
  )

  return {
    authenticated,
    user: authenticated ? 'admin' : null,
  }
})
