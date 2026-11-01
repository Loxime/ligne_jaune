import { getInternalStore, events, isEnabled } from 'vite-plugin-vue-tracer/client/listeners';
import { state } from 'vite-plugin-vue-tracer/client/overlay';

function createClientScriptSetup(options) {
  return function clientScriptSetup(ctx) {
    const store = getInternalStore();
    const devtools = store.devtools ||= { bindings: /* @__PURE__ */ new WeakMap() };
    const dockEvents = ctx.current.events;
    devtools.bindings.get(dockEvents)?.();
    let offClick;
    const stop = () => {
      offClick?.();
      offClick = void 0;
      if (devtools.stopActive !== stop)
        return;
      devtools.stopActive = void 0;
      isEnabled.value = false;
      state.isVisible = false;
      state.isEnabled = false;
    };
    const activate = () => {
      window.focus();
      devtools.stopActive?.();
      devtools.stopActive = stop;
      offClick = events.on("click", (e) => {
        stop();
        if (options.openInEditor)
          ctx.rpc.call("vite:core:open-in-editor", `${e.pos[0]}:${e.pos[1]}:${e.pos[2]}`);
        ctx.docks.setActionActive?.(ctx.current.entryMeta.id, false) ?? ctx.docks.switchEntry(null);
      });
      isEnabled.value = true;
      state.isVisible = true;
    };
    const offActivate = dockEvents.on("entry:activated", activate);
    const offDeactivate = dockEvents.on("entry:deactivated", stop);
    devtools.bindings.set(dockEvents, () => {
      offActivate();
      offDeactivate();
      stop();
    });
    if (ctx.current.isActive)
      activate();
  };
}
const viteDevtools = createClientScriptSetup({ openInEditor: true });
const pickOnly = createClientScriptSetup({ openInEditor: false });

export { viteDevtools as default, pickOnly };
