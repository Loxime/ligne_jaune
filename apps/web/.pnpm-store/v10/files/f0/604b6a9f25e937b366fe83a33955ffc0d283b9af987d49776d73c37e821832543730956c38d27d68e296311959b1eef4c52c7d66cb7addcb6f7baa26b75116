import { Politeness } from "../composables/route-announcer.js";
import { DefineSetupFnComponent, SlotsType, VNode } from "vue";
interface NuxtRouteAnnouncerProps {
  atomic?: boolean;
  politeness?: Politeness;
}
type NuxtRouteAnnouncerSlots = SlotsType<{
  default?: (props: {
    message: string;
  }) => VNode[];
}>;
declare const NuxtRouteAnnouncer: DefineSetupFnComponent<NuxtRouteAnnouncerProps, {}, NuxtRouteAnnouncerSlots>;
export { NuxtRouteAnnouncer as default };