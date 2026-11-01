import { readFile } from 'node:fs/promises'
import { createError, useSession, type SessionEvent } from 'nuxt/server'

import { isActiveAdminSessionId } from './session-store'

type AuthEvent = SessionEvent

interface AuthData extends Record<string, unknown> {
  user?: string
  issuedAt?: number
  sessionId?: string
}

export async function getAuthSession(event: AuthEvent) {
  const path = process.env.LJ_AUTH_SESSION_KEY_FILE

  if (!path) {
    throw createError({
      status: 503,
      statusText: 'Authentication not configured',
    })
  }

  let secret: string

  try {
    secret = (await readFile(path, 'utf8')).trim()
  } catch {
    throw createError({
      status: 503,
      statusText: 'Session secret unavailable',
    })
  }

  if (!/^[a-f0-9]{64}$/.test(secret)) {
    throw createError({
      status: 503,
      statusText: 'Session secret invalid',
    })
  }

  return useSession<AuthData>(event, {
    name: 'lj-auth',
    password: secret,
    maxAge: 60 * 60 * 2,
    cookie: {
      httpOnly: true,
      sameSite: 'strict',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
    },
  })
}

export async function isValidAdminSession(
  data: AuthData,
): Promise<boolean> {
  if (
    data.user !== 'admin'
    || typeof data.issuedAt !== 'number'
    || !Number.isFinite(data.issuedAt)
    || data.issuedAt > Date.now()
    || Date.now() - data.issuedAt > 2 * 60 * 60 * 1000
  ) {
    return false
  }

  return isActiveAdminSessionId(data.sessionId)
}

export async function requireAdminSession(event: AuthEvent) {
  const session = await getAuthSession(event)

  if (!(await isValidAdminSession(session.data))) {
    throw createError({
      status: 401,
      statusText: 'Authentication required',
    })
  }

  return session
}

export function requireSameOrigin(event: AuthEvent) {
  const origin = event.req.headers.get('origin')
  const host = event.req.headers.get('host')
  const fetchSite = event.req.headers.get('sec-fetch-site')

  if (fetchSite === 'cross-site') {
    throw createError({
      status: 403,
      statusText: 'Cross-origin request rejected',
    })
  }

  if (origin) {
    let originHost: string

    try {
      originHost = new URL(origin).host
    } catch {
      throw createError({
        status: 403,
        statusText: 'Invalid request origin',
      })
    }

    if (!host || originHost !== host) {
      throw createError({
        status: 403,
        statusText: 'Cross-origin request rejected',
      })
    }
  }
}
