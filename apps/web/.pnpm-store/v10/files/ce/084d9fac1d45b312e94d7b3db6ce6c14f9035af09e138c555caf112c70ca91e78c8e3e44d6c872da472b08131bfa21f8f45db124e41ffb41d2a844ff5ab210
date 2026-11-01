import { defineNuxtPlugin } from "../nuxt.js";
// src/app/plugins/warn.dev.server.ts
const plugin = /* @__PURE__ */ defineNuxtPlugin((nuxtApp) => {
	nuxtApp.vueApp.config.warnHandler ??= (msg, _instance, trace) => {
		console.warn(`[Vue warn]: ${msg}`, trace);
	};
});
export { plugin as default };
