module StructureLegacyDefectConsumers where

import O2I.Structure

legacyRule defect = structureDefectRule defect

legacySubject defect = structureDefectSubject defect

legacyRelated defect = structureDefectRelatedOccurrences defect
