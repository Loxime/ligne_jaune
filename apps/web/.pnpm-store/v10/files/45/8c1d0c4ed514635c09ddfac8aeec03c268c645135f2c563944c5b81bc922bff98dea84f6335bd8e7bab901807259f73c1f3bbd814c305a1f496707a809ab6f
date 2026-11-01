import { defineEventHandler, getRequestHeader } from "h3";
// src/runtime/middleware/no-ssr.ts
const handler = defineEventHandler((event) => {
	if (getRequestHeader(event, "x-nuxt-no-ssr")) {
		event.context.nuxt ||= {};
		event.context.nuxt.noSSR = true;
	}
});
export { handler as default };
