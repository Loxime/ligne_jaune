import type { EntityKind, EntityPagination } from './entities'

export type RelationDirection = 'both' | 'incoming' | 'outgoing'

export type RelationStatus =
  | 'draft'
  | 'reviewed'
  | 'disputed'
  | 'retracted'

export interface EntityRelationship {
  id: string
  subject_entity_id: string
  subject_name: string
  subject_kind: EntityKind
  object_entity_id: string
  object_name: string
  object_kind: EntityKind
  relation_type: string
  status: RelationStatus
  valid_from: string | null
  valid_until: string | null
  source_id: string
  source_locator: string | null
  source_title: string
  source_kind: string
  created_at: string
  supporting_evidence_count: number
  contradictory_evidence_count: number
}

export interface EntityNetworkIndexResponse {
  data: EntityRelationship[]
  pagination: EntityPagination
}
