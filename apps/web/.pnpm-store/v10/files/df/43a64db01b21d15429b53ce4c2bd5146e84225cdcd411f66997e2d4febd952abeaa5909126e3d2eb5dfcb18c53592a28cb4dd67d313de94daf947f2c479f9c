import { createError } from "../error.js";
import "../composables/error.js";
// src/app/components/nuxt-stubs.ts
function renderStubMessage(name) {
	throw createError({
		fatal: true,
		status: 500,
		statusText: `${name} is provided by @nuxt/image. Check your console to install it or run 'npx nuxt module add @nuxt/image'`
	});
}
const NuxtImg = { setup: () => renderStubMessage("<NuxtImg>") };
const NuxtPicture = { setup: () => renderStubMessage("<NuxtPicture>") };
export { NuxtImg, NuxtPicture };
