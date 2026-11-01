import { defineNuxtPlugin, useNuxtApp } from "../nuxt.js";
// src/app/plugins/restore-state.client.ts
const plugin = /* @__PURE__ */ defineNuxtPlugin({
	name: "nuxt:restore-state",
	hooks: { "app:mounted"() {
		const nuxtApp = useNuxtApp();
		try {
			const state = sessionStorage.getItem("nuxt:reload:state");
			if (state) {
				sessionStorage.removeItem("nuxt:reload:state");
				Object.assign(nuxtApp.payload.state, JSON.parse(state)?.state);
			}
		} catch {}
	} }
});
export { plugin as default };
