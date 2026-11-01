import process from 'node:process';
import { walk } from 'estree-walker';
import { resolveModulePath } from 'exsolve';
import MagicString from 'magic-string';
import { relative, dirname, isAbsolute } from 'pathe';
import { SourceMapConsumer } from 'source-map-js';
import { searchForWorkspaceRoot } from 'vite';

function getRecordImportPath(id, pathRecordDist, resolveRecordEntryPath) {
  if (!resolveRecordEntryPath)
    return "vite-plugin-vue-tracer/client/record";
  if (id.startsWith("virtual:") || id.startsWith("\0"))
    return pathRecordDist;
  let related = relative(dirname(id), pathRecordDist);
  if (!related.startsWith("./") && !isAbsolute(related))
    related = `./${related}`;
  return related;
}

const functions = [
  "h",
  "_createElementVNode",
  "_createElementBlock",
  "_createBlock",
  "_createVNode",
  "_createStaticVNode"
];
const DOCK_ID = "vue-tracer";
const testRe = new RegExp(`\\b(?:${functions.join("|")})\\(`);
function VueTracer(options) {
  let {
    enabled = "dev",
    resolveRecordEntryPath = true,
    viteDevtools = false
  } = options || {};
  const devtoolsOptions = viteDevtools === true ? {} : viteDevtools;
  if (enabled === false)
    return;
  const pathRecordDist = resolveModulePath("vite-plugin-vue-tracer/client/record", { from: import.meta.url });
  const getRecordPath = (id) => getRecordImportPath(id, pathRecordDist, resolveRecordEntryPath);
  return {
    name: "vite-plugin-vue-tracer",
    enforce: "post",
    configResolved(config) {
      if (enabled === "dev")
        enabled = config.command === "serve";
      else if (enabled === "prod")
        enabled = config.command === "build";
    },
    transform(code, id) {
      if (!enabled)
        return;
      if (this.environment.name !== "client")
        return;
      if (!code.includes("_sfc_render("))
        return;
      if (!testRe.test(code))
        return;
      if (code.includes("_tracer("))
        return;
      function offsetToPos(index) {
        const lines = code.slice(0, index).split("\n");
        return {
          line: lines.length,
          column: lines.at(-1).length
        };
      }
      const map = this.getCombinedSourcemap();
      const consumer = new SourceMapConsumer(map);
      const s = new MagicString(code);
      const ast = this.parse(code);
      let hit = false;
      walk(ast, {
        enter(node) {
          if (node.type !== "CallExpression" || node.callee.type !== "Identifier")
            return;
          if (!functions.includes(node.callee.name))
            return;
          const { start, end } = node;
          const pos = offsetToPos(start);
          const original = consumer.originalPositionFor(pos);
          if (original.source === null)
            return;
          hit = true;
          s.appendLeft(start, `_tracer(${original.line},${original.column},`);
          s.appendRight(end, `)`);
        }
      });
      if (!hit)
        return;
      const workspaceRoot = searchForWorkspaceRoot(process.cwd());
      const related = relative(workspaceRoot, id);
      s.prepend(`import { recordPosition as _tracerRecordPosition } from ${JSON.stringify(getRecordPath(id))}
`);
      s.append(`
function _tracer(line, column, vnode) { return _tracerRecordPosition(${JSON.stringify(related)}, line, column, vnode) }
`);
      return {
        code: s.toString(),
        map: s.generateMap({ hires: true })
      };
    },
    // Vite DevTools integration
    ...devtoolsOptions ? {
      devtools: {
        setup(ctx) {
          const { onPick = "open-in-editor" } = devtoolsOptions;
          const entry = {
            id: DOCK_ID,
            title: "Inspect Vue component",
            description: onPick === "none" ? "Pick an element on the page to inspect its Vue component" : "Pick an element on the page to open its Vue component in the editor",
            icon: "ph:crosshair-simple-duotone",
            type: "action",
            toggle: true,
            action: {
              importFrom: "vite-plugin-vue-tracer/client/vite-devtools",
              importName: onPick === "none" ? "pickOnly" : "default"
            }
          };
          ctx.docks.register(entry);
          ctx.commands?.register({
            id: "vue-tracer:toggle-inspector",
            title: "Toggle Vue component inspector",
            icon: entry.icon,
            keybindings: [{ key: "Mod+Shift+X" }],
            handler: () => ctx.docks.activate(DOCK_ID)
          });
        }
      }
    } : {}
  };
}

export { VueTracer, VueTracer as default };
