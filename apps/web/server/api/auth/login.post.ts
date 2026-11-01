import { readFile } from 'node:fs/promises'
import {
  createAdminSessionId,
  revokeAdminSessionId,
} from '../../utils/session-store'
import { scryptSync, timingSafeEqual } from 'node:crypto'
import { createError, defineEventHandler, getRequestIP, readBody } from 'nuxt/server'
import {
  getAuthSession,
  requireSameOrigin,
} from '../../utils/auth'

interface Attempt {
  count: number
  resetAt: number
}

const attempts = new Map<string, Attempt>()
const WINDOW_MS = 15 * 60 * 1000
const MAX_ATTEMPTS = 5

function verifyPassword(
  password: string,
  stored: string,
): boolean {
  const parts = stored.trim().split(':')

  if (
    parts.length !== 3
    || parts[0] !== 'scrypt'
    || !/^[a-f0-9]{32}$/.test(parts[1]!)
    || !/^[a-f0-9]{64}$/.test(parts[2]!)
  ) {
    throw createError({
      status: 503,
      statusText: 'Credential configuration invalid',
    })
  }

  const salt = Buffer.from(parts[1]!, 'hex')
  const expected = Buffer.from(parts[2]!, 'hex')

  const actual = scryptSync(password, salt, 32, {
    N: 16384,
    r: 8,
    p: 1,
  })

  return timingSafeEqual(actual, expected)
}

export default defineEventHandler(async (event) => {
  requireSameOrigin(event)
  event.res.headers.set('Cache-Control', 'no-store')

  const ip = getRequestIP(event) || 'unknown'
  const now = Date.now()

  let attempt = attempts.get(ip)

  if (!attempt || now >= attempt.resetAt) {
    attempt = {
      count: 0,
      resetAt: now + WINDOW_MS,
    }
    attempts.set(ip, attempt)
  }

  if (attempt.count >= MAX_ATTEMPTS) {
    throw createError({
      status: 429,
      statusText: 'Too many login attempts',
    })
  }

  const body = await readBody<{ password?: unknown }>(event)
  const password = body?.password

  if (
    typeof password !== 'string'
    || password.length < 1
    || password.length > 256
  ) {
    throw createError({
      status: 400,
      statusText: 'Invalid credentials',
    })
  }

  const hashPath = process.env.LJ_AUTH_PASSWORD_HASH_FILE

  if (!hashPath) {
    throw createError({
      status: 503,
      statusText: 'Authentication not configured',
    })
  }

  let stored: string

  try {
    stored = await readFile(hashPath, 'utf8')
  } catch {
    throw createError({
      status: 503,
      statusText: 'Credentials unavailable',
    })
  }

  if (!verifyPassword(password, stored)) {
    attempt.count += 1

    throw createError({
      status: 401,
      statusText: 'Invalid credentials',
    })
  }

  attempts.delete(ip)

  const session = await getAuthSession(event)

  await revokeAdminSessionId(session.data.sessionId)

  const sessionId = await createAdminSessionId()

  try {
    await session.update({
      user: 'admin',
      issuedAt: Date.now(),
      sessionId,
    })
  } catch (error) {
    await revokeAdminSessionId(sessionId)
    throw error
  }

  return { authenticated: true }
})
