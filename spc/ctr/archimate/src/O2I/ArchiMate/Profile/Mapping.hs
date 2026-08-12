-- | Closed ArchiMate carrier and relationship mapping observations.
module O2I.ArchiMate.Profile.Mapping
  ( -- | Closed defects produced while canonicalizing a relationship label.
    RelationshipLabelDefect(..)
  , normalizeRelationshipLabel
  , -- | One immutable mapping from an ArchiMate carrier to admitted O2I types.
    CarrierMapping
  , carrierMappings
  , carrierMappingId
  , carrierMappingElement
  , carrierMappingCategory
  , carrierMappingTypes
  , -- | One immutable ArchiMate relationship-to-O2I relation mapping.
    RelationMapping
  , relationMappings
  , relationMappingId
  , relationMappingRelationship
  , relationMappingAssociationDirected
  , relationMappingLabel
  , relationMappingToken
  ) where

import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Mapping

-- | Canonicalize a notation label or return its exact closed defect.
--
-- This is notation normalization only; the label does not define fachliche
-- relation semantics independently of the O2I contract.
normalizeRelationshipLabel :: Text -> Either RelationshipLabelDefect Text
normalizeRelationshipLabel = normalizeLabel

-- | Complete carrier mapping inventory compiled from the Profile contract.
carrierMappings :: [CarrierMapping]
carrierMappings = carrierInventory

-- | Stable identifier of a carrier mapping.
carrierMappingId :: CarrierMapping -> Text
carrierMappingId = carrierMappingIdValue

-- | ArchiMate element type used as the notation carrier.
carrierMappingElement :: CarrierMapping -> Text
carrierMappingElement = carrierMappingElementValue

-- | O2I carrier category represented by the mapping.
carrierMappingCategory :: CarrierMapping -> Text
carrierMappingCategory = carrierMappingCategoryValue

-- | Closed O2I type tokens admitted for the carrier.
carrierMappingTypes :: CarrierMapping -> [Text]
carrierMappingTypes = carrierMappingTypesValue

-- | Complete relation mapping inventory compiled from the Profile contract.
relationMappings :: [RelationMapping]
relationMappings = relationInventory

-- | Stable identifier of a relation mapping.
relationMappingId :: RelationMapping -> Text
relationMappingId = relationMappingIdValue

-- | ArchiMate relationship type used as the notation carrier.
relationMappingRelationship :: RelationMapping -> Text
relationMappingRelationship = relationMappingRelationshipValue

-- | Whether an Association carrier must be directed for this mapping.
relationMappingAssociationDirected :: RelationMapping -> Bool
relationMappingAssociationDirected = relationMappingAssociationDirectedValue

-- | Canonical notation label required by the mapping.
relationMappingLabel :: RelationMapping -> Text
relationMappingLabel = relationMappingLabelValue

-- | O2I relation token represented by the mapping.
relationMappingToken :: RelationMapping -> Text
relationMappingToken = relationMappingTokenValue
