import { requireAdminSession } from '../../utils/auth'
import { readFile } from 'node:fs/promises'
import { createError, defineEventHandler, useRuntimeConfig } from 'nuxt/server'

export default defineEventHandler(async (event) => {
  await requireAdminSession(event)

  event.res.headers.set('Cache-Control', 'no-store')

  const config = useRuntimeConfig()

  const apiBaseUrl = String(config.apiBaseUrl || '')
  const apiTokenFile = String(config.apiTokenFile || '')

  if (!apiBaseUrl || !apiTokenFile) {
    throw createError({
      status: 503,
      statusText: 'Backend not configured',
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

  let endpoint: string

  try {
    const base = new URL(apiBaseUrl)

    if (!['http:', 'https:'].includes(base.protocol)) {
      throw new Error('Unsupported protocol')
    }

    endpoint = new URL('/api/health/db', base).toString()
  } catch {
    throw createError({
      status: 503,
      statusText: 'Backend configuration invalid',
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
      status: 502,
      statusText: 'Backend unavailable',
    })
  }

  return {
    status: 'ok',
    service: 'ligne-jaune-api',
  }
})
