module StructureLegacyDefectConsumers where

import O2I.Core.Contract (CoreRuleId)
import O2I.Semantics.Input
import O2I.Structure

structureRule :: StructureDefect -> CoreRuleId
structureRule = structureDefectRule

supplementalRule :: SupplementalInputDefect -> CoreRuleId
supplementalRule = supplementalInputDefectRule

legacySubject defect = structureDefectSubject defect

legacyRelated defect = structureDefectRelatedOccurrences defect

legacySupplementalKind defect = supplementalInputDefectKind defect

legacySupplementalKindValue = SupplementalInvalidUtf8
