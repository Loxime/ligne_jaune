<script setup lang="ts">
const password = ref('')
const pending = ref(false)
const error = ref('')

async function login() {
  if (pending.value || !password.value) return

  pending.value = true
  error.value = ''

  try {
    await $fetch('/api/auth/login', {
      method: 'POST',
      body: { password: password.value },
    })

    password.value = ''
    await navigateTo('/', { replace: true })
  } catch {
    error.value = 'Connexion refusée. Vérifiez vos identifiants.'
  } finally {
    pending.value = false
  }
}
</script>

<template>
  <main class="login-screen">
    <form class="login-card" @submit.prevent="login">
      <div class="login-mark">LJ</div>

      <p class="login-label">ACCÈS RESTREINT</p>

      <h1>Ligne Jaune</h1>

      <p class="login-description">
        Espace privé de recherche et de cartographie documentaire.
      </p>

      <label for="password">Mot de passe administrateur</label>

      <input
        id="password"
        v-model="password"
        type="password"
        name="password"
        autocomplete="current-password"
        minlength="16"
        required
      >

      <p v-if="error" class="login-error" role="alert">
        {{ error }}
      </p>

      <button type="submit" :disabled="pending">
        {{ pending ? 'Vérification...' : 'Se connecter' }}
      </button>

      <p class="login-footer">Environnement privé • Ligne Jaune</p>
    </form>
  </main>
</template>

<style scoped>
.login-screen {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: #101318;
  color: #f2f1ed;
}

.login-card {
  width: min(100%, 420px);
  padding: 36px;
  background: #1a1e24;
  border: 1px solid #30353d;
  border-radius: 14px;
}

.login-mark {
  width: 46px;
  height: 46px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  background: #e5bb52;
  color: #171717;
  font-weight: 800;
}

.login-label {
  margin-top: 36px;
  color: #e5bb52;
  font-size: 11px;
  letter-spacing: 0.15em;
}

h1 {
  font-size: 36px;
  margin: 12px 0;
  letter-spacing: -0.05em;
}

.login-description,
.login-footer {
  color: #a8adb5;
  line-height: 1.6;
  font-size: 14px;
}

label {
  display: block;
  margin: 32px 0 10px;
  font-size: 13px;
}

input {
  width: 100%;
  padding: 13px;
  border-radius: 8px;
  border: 1px solid #444b55;
  background: #101318;
  color: white;
  font: inherit;
}

input:focus-visible {
  outline: 2px solid #e5bb52;
  outline-offset: 2px;
}

button {
  width: 100%;
  margin-top: 18px;
  padding: 14px;
  border: none;
  border-radius: 8px;
  color: #151515;
  background: #e5bb52;
  font-weight: 700;
  cursor: pointer;
}

button:disabled {
  opacity: 0.6;
  cursor: wait;
}

.login-error {
  color: #f0a1a1;
  font-size: 13px;
}

.login-footer {
  margin-top: 30px;
  text-align: center;
  font-size: 12px;
}
</style>
