import {
  createError,
  defineEventHandler,
  getQuery,
  getRouterParam,
} from 'nuxt/server'
import type { EntityNetworkIndexResponse } from '../../../../app/types/relationships'
import { requireAdminSession } from '../../../utils/auth'
import { getPrivateSymfonyJson } from '../../../utils/symfony-api'

const UUID =
  /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i

const DIRECTIONS = ['both', 'incoming', 'outgoing']
const STATUSES = ['draft', 'reviewed', 'disputed', 'retracted']

function invalidQuery(): never {
  throw createError({
    status: 400,
    statusText: 'Invalid relationship query',
  })
}

function parseInteger(
  value: unknown,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  if (value === undefined) return fallback

  if (
    typeof value !== 'string'
    || !/^(0|[1-9][0-9]*)$/.test(value)
  ) {
    return invalidQuery()
  }

  const parsed = Number(value)

  if (!Number.isInteger(parsed)
    || parsed < minimum
    || parsed > maximum) {
    return invalidQuery()
  }

  return parsed
}

function isNetworkResponse(
  value: unknown,
): value is EntityNetworkIndexResponse {
  if (!value || typeof value !== 'object') return false

  const record = value as Record<string, unknown>

  if (!Array.isArray(record.data)) return false

  const pagination = record.pagination

  if (!pagination || typeof pagination !== 'object') {
    return false
  }

  const p = pagination as Record<string, unknown>

  return Number.isInteger(p.limit)
    && Number.isInteger(p.offset)
    && Number.isInteger(p.returned)
    && p.returned === record.data.length
    && typeof p.has_more === 'boolean'
}

export default defineEventHandler(async (event) => {
  event.res.headers.set('Cache-Control', 'no-store')
  event.res.headers.set('X-Content-Type-Options', 'nosniff')

  await requireAdminSession(event)

  const id = getRouterParam(event, 'id') || ''

  if (!UUID.test(id)) {
    throw createError({
      status: 400,
      statusText: 'Invalid entity ID',
    })
  }

  const query = getQuery(event)

  if (
    Object.keys(query).some(key =>
      !['direction', 'status', 'limit', 'offset'].includes(key)
    )
  ) {
    return invalidQuery()
  }

  const direction = query.direction ?? 'both'
  const status = query.status

  if (
    typeof direction !== 'string'
    || !DIRECTIONS.includes(direction)
    || (
      status !== undefined
      && (
        typeof status !== 'string'
        || !STATUSES.includes(status)
      )
    )
  ) {
    return invalidQuery()
  }

  const limit = parseInteger(query.limit, 20, 1, 100)
  const offset = parseInteger(query.offset, 0, 0, 10000)

  const params = new URLSearchParams({
    direction,
    limit: String(limit),
    offset: String(offset),
  })

  if (typeof status === 'string') {
    params.set('status', status)
  }

  const response = await getPrivateSymfonyJson(
    `/api/entities/${id.toLowerCase()}/relationships?${params}`,
  )

  if (!isNetworkResponse(response)) {
    throw createError({
      status: 502,
      statusText: 'Unexpected network response',
    })
  }

  return response
})
