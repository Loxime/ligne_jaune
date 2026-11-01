import { createCommentVNode, createElementBlock, defineComponent } from "vue";
import { clientNodePlaceholder } from "#build/nuxt.config.mjs";
// src/app/components/server-placeholder.ts
const ServerPlaceholder = defineComponent({
	name: "ServerPlaceholder",
	render() {
		return clientNodePlaceholder ? createCommentVNode("placeholder") : createElementBlock("div");
	}
});
export { ServerPlaceholder as default };
