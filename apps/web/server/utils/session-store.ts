import { randomBytes } from 'node:crypto'
import { access, stat, unlink, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { createError } from 'nuxt/server'

const ID_PATTERN = /^[a-f0-9]{64}$/

function unavailable(): never {
  throw createError({
    status: 503,
    statusText: 'Session storage unavailable',
  })
}

async function sessionPath(id: string): Promise<string> {
  if (!ID_PATTERN.test(id)) {
    throw createError({
      status: 401,
      statusText: 'Invalid session',
    })
  }

  const directory = process.env.LJ_AUTH_SESSION_STORE_DIR

  if (!directory) unavailable()

  try {
    const info = await stat(directory)

    if (!info.isDirectory() || (info.mode & 0o077) !== 0) {
      unavailable()
    }
  } catch {
    unavailable()
  }

  return join(directory, id)
}

export async function createAdminSessionId(): Promise<string> {
  const id = randomBytes(32).toString('hex')
  const path = await sessionPath(id)

  try {
    await writeFile(path, '', {
      flag: 'wx',
      mode: 0o600,
    })
  } catch {
    unavailable()
  }

  return id
}

export async function isActiveAdminSessionId(
  id: unknown,
): Promise<boolean> {
  if (typeof id !== 'string' || !ID_PATTERN.test(id)) {
    return false
  }

  const path = await sessionPath(id)

  try {
    await access(path)
    return true
  } catch (error) {
    if (
      typeof error === 'object'
      && error !== null
      && 'code' in error
      && error.code === 'ENOENT'
    ) {
      return false
    }

    unavailable()
  }
}

export async function revokeAdminSessionId(
  id: unknown,
): Promise<void> {
  if (typeof id !== 'string' || !ID_PATTERN.test(id)) {
    return
  }

  const path = await sessionPath(id)

  try {
    await unlink(path)
  } catch (error) {
    if (
      typeof error === 'object'
      && error !== null
      && 'code' in error
      && error.code === 'ENOENT'
    ) {
      return
    }

    unavailable()
  }
}
