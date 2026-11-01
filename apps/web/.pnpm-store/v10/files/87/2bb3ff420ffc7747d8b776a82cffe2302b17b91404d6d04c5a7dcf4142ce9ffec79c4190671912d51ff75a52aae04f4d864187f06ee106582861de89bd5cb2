import { NuxtAppLiterals } from "../types.js";
import { DefineSetupFnComponent, SlotsType, VNode } from "vue";
interface NuxtIslandProps {
  name: NuxtAppLiterals['islandName'];
  lazy?: boolean;
  props?: Record<string, any>;
  context?: Record<string, any>;
  scopeId?: string | undefined | null;
  source?: string;
  dangerouslyLoadClientComponents?: boolean;
}
type NuxtIslandEmits = {
  error: (error: unknown) => void;
};
type NuxtIslandSlots = SlotsType<{
  fallback?: (props: {
    error: unknown;
  }) => VNode[];
  [name: string]: ((props: any) => VNode[]) | undefined;
}>;
declare const NuxtIsland: DefineSetupFnComponent<NuxtIslandProps, NuxtIslandEmits, NuxtIslandSlots>;
export { NuxtIsland as default };