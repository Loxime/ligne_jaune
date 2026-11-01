import { DefineSetupFnComponent, InjectionKey, SlotsType, VNode } from "vue";
export declare const NuxtTeleportIslandSymbol: InjectionKey<false | string>;
/**
 * component only used with componentsIsland
 * this teleport the component in SSR only if it needs to be hydrated on client
 */
interface NuxtTeleportIslandComponentProps {
  nuxtClient?: boolean;
}
type NuxtTeleportIslandComponentSlots = SlotsType<{
  default?: () => VNode[];
}>;
declare const NuxtTeleportIslandComponent: DefineSetupFnComponent<NuxtTeleportIslandComponentProps, {}, NuxtTeleportIslandComponentSlots>;
export { NuxtTeleportIslandComponent as default };