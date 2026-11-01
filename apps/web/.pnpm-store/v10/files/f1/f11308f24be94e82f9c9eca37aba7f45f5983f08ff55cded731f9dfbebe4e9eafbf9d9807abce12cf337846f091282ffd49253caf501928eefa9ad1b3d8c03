import { viteNodeOptions } from "#vite-node";
import runner from "#vite-node-runner";
// src/vite-node-warmup.ts
var vite_node_warmup_default = () => {
	if (viteNodeOptions.warmupPath) setTimeout(() => runner.executeFile(viteNodeOptions.warmupPath).catch(() => {}), 0);
};
export { vite_node_warmup_default as default };
