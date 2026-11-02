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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object'
    && value !== null
    && !Array.isArray(value)
}

function isNullableString(value: unknown): boolean {
  return value === null || typeof value === 'string'
}

function isRelationship(value: unknown): boolean {
  if (!isRecord(value)) return false

  const uuidFields = [
    'id',
    'subject_entity_id',
    'object_entity_id',
    'source_id',
  ]

  if (uuidFields.some(field =>
    typeof value[field] !== 'string'
    || !UUID.test(value[field] as string)
  )) return false

  const textFields = [
    'subject_name',
    'object_name',
    'relation_type',
    'source_title',
    'source_kind',
    'created_at',
  ]

  if (textFields.some(field =>
    typeof value[field] !== 'string'
  )) return false

  const kinds = [
    'person', 'company', 'association',
    'institution', 'other',
  ]

  if (!kinds.includes(String(value.subject_kind))
    || !kinds.includes(String(value.object_kind))) {
    return false
  }

  if (!STATUSES.includes(String(value.status))) return false

  if (!isNullableString(value.valid_from)
    || !isNullableString(value.valid_until)
    || !isNullableString(value.source_locator)) {
    return false
  }

  return Number.isInteger(value.supporting_evidence_count)
    && Number(value.supporting_evidence_count) >= 0
    && Number.isInteger(value.contradictory_evidence_count)
    && Number(value.contradictory_evidence_count) >= 0
}

function isNetworkResponse(
  value: unknown,
): value is EntityNetworkIndexResponse {
  if (!isRecord(value)) return false

  if (!Array.isArray(value.data)
    || !value.data.every(isRelationship)) {
    return false
  }

  const p = value.pagination

  if (!isRecord(p)) return false

  return Number.isInteger(p.limit)
    && Number(p.limit) >= 1
    && Number(p.limit) <= 100
    && Number.isInteger(p.offset)
    && Number(p.offset) >= 0
    && Number(p.offset) <= 10000
    && Number.isInteger(p.returned)
    && p.returned === value.data.length
    && value.data.length <= Number(p.limit)
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
