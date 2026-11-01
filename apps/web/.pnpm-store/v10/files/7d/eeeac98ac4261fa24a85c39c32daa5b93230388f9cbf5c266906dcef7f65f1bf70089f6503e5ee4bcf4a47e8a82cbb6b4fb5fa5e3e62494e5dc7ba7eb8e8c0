import { defineNuxtPlugin } from "../nuxt.js";
import { createDebugger } from "hookable";
// src/app/plugins/debug-hooks.ts
const plugin = /* @__PURE__ */ defineNuxtPlugin({
	name: "nuxt:debug:hooks",
	enforce: "pre",
	setup(nuxtApp) {
		createDebugger(nuxtApp.hooks, { tag: "nuxt-app" });
	}
});
export { plugin as default };
