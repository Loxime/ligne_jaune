import { readFile } from 'node:fs/promises'
import { createError, useRuntimeConfig } from 'nuxt/server'

type AllowedPath = '/api/health/db' | '/api/entities'

export async function getPrivateSymfonyJson(
  path: AllowedPath,
): Promise<unknown> {
  const config = useRuntimeConfig()

  const baseUrl = String(config.apiBaseUrl || '')
  const tokenFile = String(config.apiTokenFile || '')

  if (!baseUrl || !tokenFile) {
    throw createError({
      status: 503,
      statusText: 'Backend not configured',
    })
  }

  let endpoint: string

  try {
    const base = new URL(baseUrl)

    if (!['http:', 'https:'].includes(base.protocol)) {
      throw new Error('Unsupported protocol')
    }

    endpoint = new URL(path, base).toString()
  } catch {
    throw createError({
      status: 503,
      statusText: 'Backend configuration invalid',
    })
  }

  let token: string

  try {
    token = (await readFile(tokenFile, 'utf8')).trim()
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

  try {
    return await $fetch(endpoint, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'application/json',
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
}
