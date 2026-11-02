import {
  createError,
  defineEventHandler,
  getRouterParam,
} from 'nuxt/server'
import { ENTITY_KINDS, type Entity } from '../../../app/types/entities'
import { requireAdminSession } from '../../utils/auth'
import { getPrivateSymfonyJson } from '../../utils/symfony-api'

const UUID_PATTERN =
  /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i

function isEntity(value: unknown): value is Entity {
  if (typeof value !== 'object' || value === null) return false

  const item = value as Record<string, unknown>

  return typeof item.id === 'string'
    && UUID_PATTERN.test(item.id)
    && typeof item.name === 'string'
    && typeof item.created_at === 'string'
    && ENTITY_KINDS.some(kind => kind === item.kind)
    && (
      item.description === null
      || typeof item.description === 'string'
    )
}

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')
  event.res.headers.set('X-Content-Type-Options', 'nosniff')

  await requireAdminSession(event)

  const id = getRouterParam(event, 'id') || ''

  if (!UUID_PATTERN.test(id)) {
    throw createError({
      status: 400,
      statusText: 'Invalid entity ID',
    })
  }

  const response = await getPrivateSymfonyJson(
    `/api/entities/${id.toLowerCase()}`,
  )

  if (
    typeof response !== 'object'
    || response === null
    || !('data' in response)
    || !isEntity(response.data)
    || response.data.id.toLowerCase() !== id.toLowerCase()
  ) {
    throw createError({
      status: 502,
      statusText: 'Unexpected entity response',
    })
  }

  return { data: response.data }
})
