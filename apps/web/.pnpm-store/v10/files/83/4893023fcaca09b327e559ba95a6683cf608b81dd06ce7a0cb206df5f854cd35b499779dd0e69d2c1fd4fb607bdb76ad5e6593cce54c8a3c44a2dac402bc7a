import "./vite-node-runner-BLL3YBPY.mjs";
import { PluginContainer } from "vite";
import net, { Socket } from "node:net";
import { Manifest } from "vue-bundle-renderer";
import "@nuxt/schema";
import { FetchResult } from "vite-node";
type ResolveIdResponse = Awaited<ReturnType<PluginContainer["resolveId"]>>;
interface ViteNodeFetch {
  /**  Gets the client manifest. */
  getManifest(): Promise<Manifest>;
  /** Gets the list of invalidated files. */
  getInvalidates(): Promise<string[]>;
  /** Resolves a module ID. */
  resolveId(id: string, importer?: string): Promise<ResolveIdResponse | null>;
  /** Fetches a module. */
  fetchModule(moduleId: string): Promise<FetchResult>;
  /** Ensures the IPC socket is connected. */
  ensureConnected(): Promise<Socket>;
}
type ViteNodeServerOptions = {
  baseURL: string;
  socketPath: string;
  root: string;
  entryPath: string;
  warmupPath?: string;
  base: string;
  maxRetryAttempts?: number;
  baseRetryDelay?: number;
  maxRetryDelay?: number;
  requestTimeout?: number;
};
export declare const viteNodeOptions: ViteNodeServerOptions;
export declare const viteNodeFetch: ViteNodeFetch;
export {};