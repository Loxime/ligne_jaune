import { Plugin } from 'vite';

interface VueTracerOptions {
    /**
     * Enable this plugin or not, or only enable in certain environment.
     *
     * @default 'dev'
     */
    enabled?: boolean | 'dev' | 'prod';
    /**
     * Resolve the record entry path to relative path.
     * Normally, it should be true.
     *
     * @default true
     */
    resolveRecordEntryPath?: boolean;
    /**
     * Enable Vite DevTools integration: an "Inspect Vue component" dock button
     * that picks an element on the page.
     *
     * @default false
     */
    viteDevtools?: boolean | VueTracerViteDevtoolsOptions;
}
interface VueTracerViteDevtoolsOptions {
    /**
     * What to do with the picked element.
     *
     * - `'open-in-editor'`: open its source in the editor.
     * - `'none'`: only end the pick. Use it when you handle the `click` event
     *   from `vite-plugin-vue-tracer/client/listeners` yourself.
     *
     * @default 'open-in-editor'
     */
    onPick?: 'open-in-editor' | 'none';
}
declare function VueTracer(options?: VueTracerOptions): Plugin | undefined;

export { VueTracer, VueTracer as default };
export type { VueTracerOptions, VueTracerViteDevtoolsOptions };
