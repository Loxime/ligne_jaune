import { DefineSetupFnComponent, SlotsType, VNode } from "vue";
interface NuxtClientFallbackProps {
  fallbackTag?: string;
  fallback?: string;
  placeholder?: string;
  placeholderTag?: string;
  keepFallback?: boolean;
}
type NuxtClientFallbackEmits = {
  'ssr-error': (error: unknown) => void;
};
type NuxtClientFallbackSlots = SlotsType<{
  default?: () => VNode[];
  fallback?: () => VNode[];
  placeholder?: () => VNode[];
}>;
declare const NuxtClientFallbackClient: DefineSetupFnComponent<NuxtClientFallbackProps, NuxtClientFallbackEmits, NuxtClientFallbackSlots>;
export { NuxtClientFallbackClient as default };