import { useNuxtApp } from "../nuxt.js";
import { isAbsoluteHref } from "../utils.js";
import { defineNuxtRouteMiddleware, navigateTo } from "../composables/router.js";
import { getRouteRules } from "../composables/manifest.js";
// src/app/middleware/route-rules.ts
const middleware = /* @__PURE__ */ defineNuxtRouteMiddleware((to) => {
	if (import.meta.server ? !useNuxtApp().ssrContext?.islandContext : import.meta.test) return;
	const rules = getRouteRules({ path: to.path });
	if (rules.redirect) {
		const path = rules.redirect.includes("#") ? rules.redirect : rules.redirect + to.hash;
		if (import.meta.server) return navigateTo(path, { external: isAbsoluteHref(path) });
		if (isAbsoluteHref(path)) {
			window.location.href = path;
			return false;
		}
		return path;
	}
});
export { middleware as default };
