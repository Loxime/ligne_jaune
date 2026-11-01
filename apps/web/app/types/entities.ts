export const ENTITY_KINDS = [
  'person',
  'company',
  'association',
  'institution',
  'other',
] as const

export type EntityKind = typeof ENTITY_KINDS[number]

export interface Entity {
  id: string
  kind: EntityKind
  name: string
  description: string | null
  created_at: string
}

export interface EntityPagination {
  limit: number
  offset: number
  returned: number
  has_more: boolean
}

export interface EntityIndexResponse {
  data: Entity[]
  pagination: EntityPagination
}
