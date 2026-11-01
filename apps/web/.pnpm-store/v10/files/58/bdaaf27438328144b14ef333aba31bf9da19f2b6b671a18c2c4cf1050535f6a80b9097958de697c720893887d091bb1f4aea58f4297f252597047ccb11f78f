import { SessionPassword } from "./session.js";
export interface SealOptions {
  /** Milliseconds; `0` for no expiry. */
  ttl?: number;
}
export declare function seal(value: unknown, password: SessionPassword, options?: SealOptions): Promise<string>;
export declare function unseal(sealed: string, password: SessionPassword, options?: SealOptions): Promise<unknown>;