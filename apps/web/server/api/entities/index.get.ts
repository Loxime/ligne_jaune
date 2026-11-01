import { createError, defineEventHandler } from 'nuxt/server'
import {
  ENTITY_KINDS,
  type Entity,
  type EntityIndexResponse,
} from '../../../app/types/entities'
import { requireAdminSession } from '../../utils/auth'
import { getPrivateSymfonyJson } from '../../utils/symfony-api'

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object'
    && value !== null
    && !Array.isArray(value)
}

function isEntity(value: unknown): value is Entity {
  if (!isRecord(value)) return false

  return typeof value.id === 'string'
    && typeof value.name === 'string'
    && typeof value.created_at === 'string'
    && (value.description === null
      || typeof value.description === 'string')
    && ENTITY_KINDS.some(kind => kind === value.kind)
}

function isEntityIndexResponse(
  value: unknown,
): value is EntityIndexResponse {
  if (!isRecord(value)) return false

  if (!Array.isArray(value.data)
    || !value.data.every(isEntity)) {
    return false
  }

  const pagination = value.pagination

  if (!isRecord(pagination)) return false

  return Number.isInteger(pagination.limit)
    && Number(pagination.limit) >= 1
    && Number(pagination.limit) <= 100
    && Number.isInteger(pagination.offset)
    && Number(pagination.offset) >= 0
    && Number(pagination.offset) <= 10000
    && Number.isInteger(pagination.returned)
    && pagination.returned === value.data.length
    && typeof pagination.has_more === 'boolean'
}

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')
  event.res.headers.set('X-Content-Type-Options', 'nosniff')

  await requireAdminSession(event)

  const response = await getPrivateSymfonyJson('/api/entities')

  if (!isEntityIndexResponse(response)) {
    throw createError({
      status: 502,
      statusText: 'Unexpected backend response',
    })
  }

  return response
})
