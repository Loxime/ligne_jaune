import { EnvironmentOptions } from "vite";
import { ViteConfig } from "nuxt/schema";
import { NuxtBuilder } from "@nuxt/schema";
export declare const bundle: NuxtBuilder["bundle"];
/**
 * Reuse Vite's `server.watcher` (chokidar) to drive `builder:watch` instead of
 * spinning up a second FS watcher in Nuxt core. Only active in `dev` mode.
 */
export declare const setupWatcher: NonNullable<NuxtBuilder["setupWatcher"]>;
declare module "nuxt/schema" {
  interface ViteOptions extends ViteConfig {
    $client?: EnvironmentOptions;
    $server?: EnvironmentOptions;
    viteNode?: {
      maxRetryAttempts?: number;
      /** in milliseconds */
      baseRetryDelay?: number;
      /** in milliseconds */
      maxRetryDelay?: number;
      /** in milliseconds */
      requestTimeout?: number;
    };
  }
}