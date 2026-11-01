import { tryUseNuxtApp } from "../nuxt.js";
import { vforBound } from "./vfor.js";
import { renderList as renderList$1 } from "vue";
import { ssrRenderList as ssrRenderList$1 } from "vue/server-renderer";
// src/app/components/render-list.ts
function bound(source) {
	if (typeof source === "number" && source > 1e4 && tryUseNuxtApp()?.ssrContext?.islandContext) return vforBound(source);
	return source;
}
/**
* `renderList` from `vue`, with numeric sources clamped to `MAX_VFOR_LENGTH`
* while rendering a server component or island.
*
* @internal
*/
const renderList = ((source, ...rest) => renderList$1(bound(source), ...rest));
/**
* `ssrRenderList` from `vue/server-renderer`, with numeric sources clamped to
* `MAX_VFOR_LENGTH` while rendering a server component or island.
*
* @internal
*/
function ssrRenderList(source, renderItem) {
	ssrRenderList$1(bound(source), renderItem);
}
export { renderList, ssrRenderList };
