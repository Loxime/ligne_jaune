import { AnnouncerPoliteness } from "../composables/announcer.js";
import { DefineSetupFnComponent, SlotsType, VNode } from "vue";
interface NuxtAnnouncerProps {
  atomic?: boolean;
  politeness?: AnnouncerPoliteness;
}
type NuxtAnnouncerSlots = SlotsType<{
  default?: (props: {
    message: string;
  }) => VNode[];
}>;
declare const NuxtAnnouncer: DefineSetupFnComponent<NuxtAnnouncerProps, {}, NuxtAnnouncerSlots>;
export { NuxtAnnouncer as default };