import { readFile } from 'node:fs/promises'

export default defineEventHandler(async (event) => {
  setResponseHeader(event, 'Cache-Control', 'no-store')

  const config = useRuntimeConfig(event)

  const apiBaseUrl = String(config.apiBaseUrl || '')
  const apiTokenFile = String(config.apiTokenFile || '')

  if (!apiBaseUrl || !apiTokenFile) {
    throw createError({
      statusCode: 503,
      statusMessage: 'Backend not configured',
    })
  }

  let token: string

  try {
    token = (await readFile(apiTokenFile, 'utf8')).trim()
  } catch {
    throw createError({
      statusCode: 503,
      statusMessage: 'Backend credentials unavailable',
    })
  }

  if (!/^[a-f0-9]{64}$/.test(token)) {
    throw createError({
      statusCode: 503,
      statusMessage: 'Backend credentials invalid',
    })
  }

  let endpoint: string

  try {
    const base = new URL(apiBaseUrl)

    if (!['http:', 'https:'].includes(base.protocol)) {
      throw new Error('Unsupported protocol')
    }

    endpoint = new URL('/api/health/db', base).toString()
  } catch {
    throw createError({
      statusCode: 503,
      statusMessage: 'Backend configuration invalid',
    })
  }

  try {
    await $fetch(endpoint, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
      timeout: 5000,
      retry: 0,
      redirect: 'manual',
    })
  } catch {
    throw createError({
      statusCode: 502,
      statusMessage: 'Backend unavailable',
    })
  }

  return {
    status: 'ok',
    service: 'ligne-jaune-api',
  }
})
