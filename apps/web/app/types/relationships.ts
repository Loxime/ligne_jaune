import type { EntityPagination } from './entities'

export type RelationDirection =
  | 'both'
  | 'incoming'
  | 'outgoing'

export type RelationStatus =
  | 'draft'
  | 'reviewed'
  | 'disputed'
  | 'retracted'

export interface EntityNetworkIndexResponse {
  data: unknown[]
  pagination: EntityPagination
}
