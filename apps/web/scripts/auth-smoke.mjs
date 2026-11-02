import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import {
  mkdtemp,
  mkdir,
  writeFile,
  rm,
} from 'node:fs/promises'
import { createServer } from 'node:net'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import {
  randomBytes,
  scryptSync,
} from 'node:crypto'
import { fileURLToPath } from 'node:url'

const appDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const tmp = await mkdtemp(join(tmpdir(), 'ligne-jaune-auth-'))

let server
let logs = ''

async function getFreePort() {
  const listener = createServer()

  await new Promise((resolve, reject) => {
    listener.once('error', reject)
    listener.listen(0, '127.0.0.1', resolve)
  })

  const port = listener.address().port

  await new Promise(resolve => listener.close(resolve))

  return port
}

async function run() {
  const password = randomBytes(24).toString('hex')
  const salt = randomBytes(16)
  const digest = scryptSync(password, salt, 32, {
    N: 16384,
    r: 8,
    p: 1,
  })

  const sessionFile = join(tmp, 'session.key')
  const hashFile = join(tmp, 'admin.hash')
  const sessionDirectory = join(tmp, 'sessions')
  await mkdir(sessionDirectory, { mode: 0o700 })

  await writeFile(
    sessionFile,
    randomBytes(32).toString('hex') + '\n',
    { mode: 0o600 },
  )

  await writeFile(
    hashFile,
    `scrypt:${salt.toString('hex')}:${digest.toString('hex')}\n`,
    { mode: 0o600 },
  )

  const port = await getFreePort()
  const base = `http://127.0.0.1:${port}`

  server = spawn(
    process.execPath,
    ['.output/server/index.mjs'],
    {
      cwd: appDir,
      env: {
        ...process.env,
        NODE_ENV: 'production',
        NITRO_HOST: '127.0.0.1',
        NITRO_PORT: String(port),
        HOST: '127.0.0.1',
        PORT: String(port),
        NUXT_API_BASE_URL: '',
        NUXT_API_TOKEN_FILE: '',
        LJ_AUTH_SESSION_KEY_FILE: sessionFile,
        LJ_AUTH_PASSWORD_HASH_FILE: hashFile,
        LJ_AUTH_SESSION_STORE_DIR: sessionDirectory,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    },
  )

  for (const stream of [server.stdout, server.stderr]) {
    stream.on('data', chunk => {
      logs = (logs + chunk.toString()).slice(-8000)
    })
  }

  async function request(path, options = {}) {
    return fetch(base + path, {
      redirect: 'manual',
      signal: AbortSignal.timeout(5000),
      ...options,
    })
  }

  let ready = false

  for (let i = 0; i < 120; i++) {
    if (server.exitCode !== null) break

    try {
      const response = await request('/api/health')

      if (response.status === 200) {
        ready = true
        break
      }
    } catch {
      // Le serveur n'écoute pas encore.
    }

    await new Promise(resolve => setTimeout(resolve, 250))
  }

  assert.ok(ready, `Nitro indisponible :\n${logs}`)

  console.log('✓ Serveur Nitro de production opérationnel')

  const anonymous = await request('/api/auth/me')
  assert.equal(anonymous.status, 200)
  assert.equal((await anonymous.json()).authenticated, false)

  console.log('✓ Session anonyme refusée')

  const protectedRoute = await request('/api/backend/health')
  assert.equal(protectedRoute.status, 401)

  console.log('✓ Passerelle interdite sans session')

  const anonymousEntities = await request('/api/entities')
  assert.equal(anonymousEntities.status, 401)

  console.log('✓ Entités interdites sans session')

  const testEntityId = '00000000-0000-4000-8000-000000000001'

  const anonymousDetail = await request(
    `/api/entities/${testEntityId}`,
  )
  assert.equal(anonymousDetail.status, 401)

  console.log('✓ Fiches individuelles protégées')

  const anonymousNetwork = await request(
    `/api/entities/${testEntityId}/relationships`,
  )
  assert.equal(anonymousNetwork.status, 401)

  console.log('✓ Réseau individuel protégé')




  const invalid = await request('/api/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: base,
    },
    body: JSON.stringify({ password: 'invalid-password' }),
  })

  assert.equal(invalid.status, 401)

  console.log('✓ Mot de passe incorrect rejeté')

  const crossOrigin = await request('/api/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: 'https://example.com',
    },
    body: JSON.stringify({ password }),
  })

  assert.equal(crossOrigin.status, 403)

  console.log('✓ Origine étrangère rejetée')

  const login = await request('/api/auth/login', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Origin: base,
    },
    body: JSON.stringify({ password }),
  })

  assert.equal(login.status, 200)
  assert.equal((await login.json()).authenticated, true)

  const cookie = login.headers.getSetCookie()
    .map(value => value.split(';', 1)[0])
    .join('; ')

  assert.match(cookie, /lj-auth=/)

  console.log('✓ Connexion et cookie de session')

  const authenticated = await request('/api/auth/me', {
    headers: { Cookie: cookie },
  })

  assert.equal(authenticated.status, 200)
  assert.equal((await authenticated.json()).authenticated, true)

  console.log('✓ Session authentifiée reconnue')

  const backend = await request('/api/backend/health', {
    headers: { Cookie: cookie },
  })

  // Aucun backend Symfony n'est configuré dans ce test isolé.
  // HTTP 503 prouve que la requête passe le contrôle de session.
  assert.equal(backend.status, 503)

  console.log('✓ Passerelle autorisée après authentification')

  const invalidNetworkFilter = await request(
    `/api/entities/${testEntityId}/relationships?direction=invalid`,
    { headers: { Cookie: cookie } },
  )
  assert.equal(invalidNetworkFilter.status, 400)

  console.log('✓ Filtres réseau invalides rejetés')


  const authorizedEntities = await request('/api/entities', {
    headers: { Cookie: cookie },
  })

  // Le backend Symfony est volontairement absent de ce test CI.
  assert.equal(authorizedEntities.status, 503)

  console.log('✓ Entités accessibles uniquement après contrôle de session')


  const logout = await request('/api/auth/logout', {
    method: 'POST',
    headers: {
      Cookie: cookie,
      Origin: base,
    },
  })

  assert.equal(logout.status, 200)
  assert.equal((await logout.json()).authenticated, false)
  assert.ok(logout.headers.getSetCookie().length > 0)

  console.log('✓ Déconnexion et instruction de suppression du cookie')

  const afterLogout = await request('/api/backend/health', {
    headers: { Cookie: cookie },
  })

  assert.equal(afterLogout.status, 401)

  const replayedSession = await request('/api/auth/me', {
    headers: { Cookie: cookie },
  })

  assert.equal(replayedSession.status, 200)
  assert.equal(
    (await replayedSession.json()).authenticated,
    false,
  )

  console.log('✓ Ancien cookie révoqué côté serveur')
  console.log('=== TESTS AUTHENTIFICATION VALIDÉS ===')
}

try {
  await run()
} catch (error) {
  console.error('ÉCHEC :', error)
  process.exitCode = 1
} finally {
  if (server && server.exitCode === null && server.signalCode === null) {
    const stopped = once(server, 'exit')
    server.kill('SIGTERM')
    await stopped
  }

  await rm(tmp, { recursive: true, force: true })
}
