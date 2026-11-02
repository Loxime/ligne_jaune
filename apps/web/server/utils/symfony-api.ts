import { readFile } from 'node:fs/promises'
import { createError, useRuntimeConfig } from 'nuxt/server'

const UUID = '[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}'

const ENTITY_PATH = new RegExp(
  `^/api/entities/${UUID}(?:/relationships(?:\\?[a-z0-9=&]*)?)?$`,
  'i',
)

function isAllowedPath(path: string): boolean {
  return path === '/api/health/db'
    || path === '/api/entities'
    || ENTITY_PATH.test(path)
}

export async function getPrivateSymfonyJson(
  path: string,
): Promise<unknown> {
  if (!isAllowedPath(path)) {
    throw createError({
      status: 400,
      statusText: 'Invalid backend path',
    })
  }

  const config = useRuntimeConfig()
  const apiBaseUrl = String(config.apiBaseUrl || '')
  const apiTokenFile = String(config.apiTokenFile || '')

  if (!apiBaseUrl || !apiTokenFile) {
    throw createError({
      status: 503,
      statusText: 'Backend not configured',
    })
  }

  let endpoint: URL

  try {
    const base = new URL(apiBaseUrl)

    if (!['http:', 'https:'].includes(base.protocol)) {
      throw new Error('Unsupported protocol')
    }

    endpoint = new URL(path, base)
  } catch {
    throw createError({
      status: 503,
      statusText: 'Backend configuration invalid',
    })
  }

  let token: string

  try {
    token = (await readFile(apiTokenFile, 'utf8')).trim()
  } catch {
    throw createError({
      status: 503,
      statusText: 'Backend credentials unavailable',
    })
  }

  if (!/^[a-f0-9]{64}$/.test(token)) {
    throw createError({
      status: 503,
      statusText: 'Backend credentials invalid',
    })
  }

  let response: Response

  try {
    response = await fetch(endpoint, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
      },
      redirect: 'manual',
      signal: AbortSignal.timeout(5000),
    })
  } catch {
    throw createError({
      status: 502,
      statusText: 'Backend unavailable',
    })
  }

  if (response.status === 404 || response.status === 400) {
    throw createError({
      status: response.status,
      statusText: response.status === 404
        ? 'Resource not found'
        : 'Invalid backend request',
    })
  }

  if (!response.ok) {
    throw createError({
      status: 502,
      statusText: 'Backend unavailable',
    })
  }

  if (
    !response.headers.get('content-type')
      ?.toLowerCase().includes('application/json')
  ) {
    throw createError({
      status: 502,
      statusText: 'Unexpected backend content type',
    })
  }

  try {
    return await response.json() as unknown
  } catch {
    throw createError({
      status: 502,
      statusText: 'Invalid backend JSON',
    })
  }
}
