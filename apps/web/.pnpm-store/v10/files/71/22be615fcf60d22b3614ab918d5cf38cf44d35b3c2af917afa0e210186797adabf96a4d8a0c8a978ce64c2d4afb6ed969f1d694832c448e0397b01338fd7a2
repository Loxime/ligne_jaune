import { DefineSetupFnComponent, SlotsType, VNode } from "vue";
/**
 * component only used within islands for slot teleport
 */
interface NuxtTeleportIslandSlotProps {
  name: string;
  /**
   * must be an array to handle v-for
   */
  props?: Array<any>;
}
type NuxtTeleportIslandSlotSlots = SlotsType<{
  default?: () => VNode[];
  fallback?: () => VNode[];
}>;
declare const NuxtTeleportIslandSlot: DefineSetupFnComponent<NuxtTeleportIslandSlotProps, {}, NuxtTeleportIslandSlotSlots>;
export { NuxtTeleportIslandSlot as default };