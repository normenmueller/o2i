{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Closed terminal-neutral projection of complete prepared diagnostics.
--
-- Every evidence branch is projected into an Operation-owned closed family.
-- No owner representation, textual role convention, or universal value bag
-- participates in evidence interpretation.
module O2I.Operation.Human.Diagnostic
  ( type HumanDiagnosticSeverity
  , foldHumanDiagnosticSeverity
  , type HumanDiagnosticDisposition
  , foldHumanDiagnosticDisposition
  , type HumanAdapterRuleStage
  , foldHumanAdapterRuleStage
  , type HumanAdapterRule
  , foldHumanAdapterRule
  , type HumanViewInventoryIssueKind
  , humanViewInventoryIssueKinds
  , foldHumanViewInventoryIssueKind
  , type HumanProfileMarkerIssueKind
  , humanProfileMarkerIssueKinds
  , foldHumanProfileMarkerIssueKind
  , type HumanSelectedUniverseIssueKind
  , humanSelectedUniverseIssueKinds
  , foldHumanSelectedUniverseIssueKind
  , type HumanNotationIssueKind
  , foldHumanNotationIssueKind
  , type HumanDraftValueKind
  , foldHumanDraftValueKind
  , type HumanNotationObservation
  , foldHumanNotationObservation
  , type HumanNotationDiagnosticEvidence
  , foldHumanNotationDiagnosticEvidence
  , type HumanClosureBranch
  , foldHumanClosureBranch
  , type HumanActivationDiagnosticEvidence
  , foldHumanActivationDiagnosticEvidence
  , type HumanProfileEvidenceKind
  , foldHumanProfileEvidenceKind
  , type HumanProfileDiagnosticEvidence
  , HumanProfileDiagnosticEliminator(..)
  , foldHumanProfileDiagnosticEvidence
  , type HumanProfileClassificationDiagnosticEvidence
  , foldHumanProfileClassificationDiagnosticEvidence
  , type HumanProfileMappingDiagnosticEvidence
  , foldHumanProfileMappingDiagnosticEvidence
  , type HumanProfileInvariantDiagnosticEvidence
  , foldHumanProfileInvariantDiagnosticEvidence
  , type HumanStructureZeroOrMultipleOccurrences
  , foldHumanStructureZeroOrMultipleOccurrences
  , type HumanStructureDiagnosticEvidence
  , HumanStructureDiagnosticEliminator(..)
  , foldHumanStructureDiagnosticEvidence
  , type HumanSemanticDiagnosticEvidence
  , HumanSemanticDiagnosticEliminator(..)
  , foldHumanSemanticDiagnosticEvidence
  , type HumanDiagnosticEvidence
  , foldHumanDiagnosticEvidence
  , type HumanDiagnostic
  , humanDiagnosticCode
  , humanDiagnosticRuleId
  , foldHumanDiagnostic
  , type HumanNotationRuleBinding
  , foldHumanNotationRuleBinding
  , type HumanDiagnosticAuthority
  , foldHumanDiagnosticAuthority
  , type HumanSupplementalDiagnosticGroup
  , foldHumanSupplementalDiagnosticGroup
  , type HumanDiagnosticDocument
  , foldHumanDiagnosticDocument
  , humanDiagnosticDocumentModelSource
  , humanDiagnosticDocument
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile.Closure as Closure
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Projection as Profile
import O2I.Core.Identity (ModelIdentity, OccurrenceIdentity)
import O2I.Operation.Acquisition
  ( AcquiredSupplementalSource
  , acquiredSourceIdentity
  , foldAcquiredSupplementalSource
  )
import O2I.Operation.Adapter
  ( AdapterRule
  , adapterContractDescriptor
  , adapterRuleAction
  , adapterRuleExpectation
  , adapterRuleId
  , adapterRuleIdText
  , adapterRuleMeaning
  , adapterRuleStage
  , foldAdapterRuleStage
  , lookupArchiMateNotationRule
  )
import O2I.Operation.Diagnostic
  ( AdapterNotationDiagnostic
  , DiagnosticDisposition
  , DiagnosticSeverity
  , PreparedDiagnostic
  , PreparedDiagnosticDocument
  , SupplementalDiagnostic
  , diagnosticDispositionText
  , diagnosticSeverityText
  , foldAdapterNotationDiagnostic
  , foldPreparedDiagnostic
  , foldPreparedDiagnosticDocument
  , foldSupplementalDiagnostic
  , foldSupplementalDiagnosticGroups
  , preparedDiagnosticDisposition
  , preparedDiagnosticOwner
  , preparedDiagnosticProducer
  , preparedDiagnosticRuleIdentity
  , preparedDiagnosticSeverity
  , preparedDiagnosticStage
  , supplementalDiagnosticRuleIdentity
  )
import O2I.Operation.Diagnostic.Owner.Source.Internal (PreparedAuthority(..))
import O2I.Operation.Human.Value
  ( HumanAdapterDescriptor
  , HumanCanonicalOccurrence
  , HumanDraftScalar
  , HumanModelIdentity
  , HumanOccurrenceIdentity
  , HumanProfileDescriptor
  , HumanSourceIdentity
  , HumanSourceLocation
  )
import O2I.Operation.Human.Value.Internal
  ( projectAdapterDescriptor
  , projectCanonicalOccurrence
  , projectDraftScalar
  , projectModelIdentity
  , projectOccurrenceIdentity
  , projectProfileDescriptor
  , projectSourceIdentity
  , projectSourceLocation
  )
import qualified O2I.Semantics as Semantics
import qualified O2I.Structure as Structure

-- | Stable severity projected from the diagnostic owner.
newtype HumanDiagnosticSeverity =
  HumanDiagnosticSeverity Text

-- | Stable disposition projected from the diagnostic owner.
newtype HumanDiagnosticDisposition =
  HumanDiagnosticDisposition Text

-- | Closed stage of an Adapter-owned diagnostic rule.
data HumanAdapterRuleStage
  = HumanAdapterPreparationRuleStage
  | HumanAdapterNotationRuleStage

-- | Complete Adapter-owned rule explanation.
data HumanAdapterRule =
  HumanAdapterRule Text HumanAdapterRuleStage Text Text Text

-- | Opaque View-inventory Notation subtype with its owner token.
newtype HumanViewInventoryIssueKind =
  HumanViewInventoryIssueKind Text

-- | Opaque Profile-marker Notation subtype with its owner token.
newtype HumanProfileMarkerIssueKind =
  HumanProfileMarkerIssueKind Text

-- | Opaque selected-universe Notation subtype with its owner token.
newtype HumanSelectedUniverseIssueKind =
  HumanSelectedUniverseIssueKind Text

-- | Closed family and subtype of one Notation issue.
data HumanNotationIssueKind
  = HumanViewInventoryIssue HumanViewInventoryIssueKind
  | HumanProfileMarkerIssue HumanProfileMarkerIssueKind
  | HumanSelectedUniverseIssue HumanSelectedUniverseIssueKind

-- | Closed observed native value category.
data HumanDraftValueKind
  = HumanDraftTextValue
  | HumanDraftBooleanValue
  | HumanDraftNumberValue
  | HumanDraftNativeNameValue
  | HumanDraftOtherValue Text

-- | One exact Notation observation.
data HumanNotationObservation
  = HumanNotationOccurrence HumanSourceLocation
  | HumanNotationValue HumanSourceLocation HumanDraftValueKind Text
  | HumanNotationReference HumanSourceLocation Text [HumanSourceLocation]

-- | Complete resolved Adapter-owned Notation evidence.
data HumanNotationDiagnosticEvidence =
  HumanNotationDiagnosticEvidence
    HumanAdapterDescriptor
    HumanAdapterRule
    HumanNotationIssueKind
    HumanSourceLocation
    (NonEmpty HumanNotationObservation)

-- | Closed Profile closure branch.
data HumanClosureBranch
  = HumanGraphClosureBranch
  | HumanQualificationClosureBranch

-- | Complete generated Profile activation provenance.
data HumanActivationDiagnosticEvidence =
  HumanActivationDiagnosticEvidence
    Text
    Text
    HumanClosureBranch
    Text
    HumanCanonicalOccurrence
    HumanCanonicalOccurrence
    [Text]

-- | Closed generated Profile evidence category.
data HumanProfileEvidenceKind
  = HumanCarrierOccurrenceEvidence
  | HumanClassificationOccurrenceEvidence
  | HumanMetadataOwnerAndO2iPropertyOccurrencesEvidence
  | HumanPropertyOccurrenceEvidence
  | HumanPropertySlotEvidence
  | HumanPropertyValueEvidence
  | HumanProposalCarrierOccurrenceEvidence
  | HumanProposalReferenceIncidenceEvidence
  | HumanRelationshipOccurrenceEvidence
  | HumanReservedPropertyOccurrenceEvidence
  | HumanStructuredCarrierOccurrenceEvidence
  | HumanStructuredIncidenceEvidence

-- | Opaque Operation-owned projection of one generated Profile defect.
newtype HumanProfileDiagnosticEvidence =
  HumanProfileDiagnosticEvidence
    (forall result. HumanProfileDiagnosticEliminator result -> result)

-- | Total consumer algebra for all generated Profile defect shapes.
data HumanProfileDiagnosticEliminator result = HumanProfileDiagnosticEliminator
    -- | Consume carrier-occurrence evidence and its rule.
  { eliminateHumanProfileCarrierOccurrence :: Text -> HumanCanonicalOccurrence -> result
    -- | Consume classification-occurrence evidence and its rule.
  , eliminateHumanProfileClassificationOccurrence :: Text -> HumanCanonicalOccurrence -> result
    -- | Consume metadata owner/property evidence and its rule.
  , eliminateHumanProfileMetadataOwnerAndO2iPropertyOccurrences :: Text -> HumanCanonicalOccurrence -> [HumanCanonicalOccurrence] -> result
    -- | Consume property occurrence/owner evidence and its rule.
  , eliminateHumanProfilePropertyOccurrence :: Text -> HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> result
    -- | Consume property-slot evidence and its rule.
  , eliminateHumanProfilePropertySlot :: Text -> HumanCanonicalOccurrence -> Text -> [HumanCanonicalOccurrence] -> result
    -- | Consume property-value evidence and its rule.
  , eliminateHumanProfilePropertyValue :: Text -> HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> [HumanDraftScalar] -> result
    -- | Consume proposal-carrier evidence and its rule.
  , eliminateHumanProfileProposalCarrierOccurrence :: Text -> HumanCanonicalOccurrence -> result
    -- | Consume proposal-reference incidence evidence and its rule.
  , eliminateHumanProfileProposalReferenceIncidence :: Text -> HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> [HumanCanonicalOccurrence] -> result
    -- | Consume relationship-occurrence evidence and its rule.
  , eliminateHumanProfileRelationshipOccurrence :: Text -> HumanCanonicalOccurrence -> result
    -- | Consume reserved-property evidence and its rule.
  , eliminateHumanProfileReservedPropertyOccurrence :: Text -> HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> Text -> result
    -- | Consume structured-carrier evidence and its rule.
  , eliminateHumanProfileStructuredCarrierOccurrence :: Text -> HumanCanonicalOccurrence -> result
    -- | Consume structured-incidence evidence and its rule.
  , eliminateHumanProfileStructuredIncidence :: Text -> HumanCanonicalOccurrence -> [HumanCanonicalOccurrence] -> result
  }

-- | Exact positive Profile classification provenance.
data HumanProfileClassificationDiagnosticEvidence =
  HumanProfileClassificationDiagnosticEvidence
    Bool
    Bool
    Text
    HumanCanonicalOccurrence

-- | Closed concrete Profile mapping provenance.
data HumanProfileMappingDiagnosticEvidence
  = HumanProfileCarrierMapping Text HumanOccurrenceIdentity Text
  | HumanProfileRelationMapping
      Text
      HumanOccurrenceIdentity
      Text
      HumanOccurrenceIdentity
      HumanOccurrenceIdentity
  | HumanProfileConstructionMapping
      Text
      HumanOccurrenceIdentity
      Text
      HumanProfileEvidenceKind

-- | Exact positive qualification-invariant evidence.
data HumanProfileInvariantDiagnosticEvidence =
  HumanProfileInvariantDiagnosticEvidence Text HumanCanonicalOccurrence

-- | Constructive zero-or-at-least-two Structure occurrence evidence.
data HumanStructureZeroOrMultipleOccurrences
  = HumanNoStructureOccurrence
  | HumanMultipleStructureOccurrences
      HumanOccurrenceIdentity
      HumanOccurrenceIdentity
      [HumanOccurrenceIdentity]

-- | Opaque Operation-owned projection of one Structure defect.
newtype HumanStructureDiagnosticEvidence =
  HumanStructureDiagnosticEvidence
    (forall result. HumanStructureDiagnosticEliminator result -> result)

-- | Total consumer algebra for every Structure defect shape.
data HumanStructureDiagnosticEliminator result = HumanStructureDiagnosticEliminator
    -- | Consume endpoint-catalog membership evidence.
  { eliminateHumanQualifiedEndpointCatalogMembership :: HumanOccurrenceIdentity -> result
    -- | Consume contextualization source-category evidence.
  , eliminateHumanContextualizationSourceCategory :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume contextualization target-category evidence.
  , eliminateHumanContextualizationTargetCategory :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume contextualization owner-cardinality evidence.
  , eliminateHumanContextualizationTargetOwnerCardinality :: HumanOccurrenceIdentity -> HumanStructureZeroOrMultipleOccurrences -> result
    -- | Consume semantic relation-compatibility evidence.
  , eliminateHumanSemanticRelationCompatibility :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume structured-proposition identity evidence.
  , eliminateHumanStructuredPropositionIdentity :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> [HumanOccurrenceIdentity] -> result
    -- | Consume collective participant-type evidence.
  , eliminateHumanCollectiveParticipantType :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume collective participant-cardinality evidence.
  , eliminateHumanCollectiveParticipantCardinality :: HumanOccurrenceIdentity -> Maybe
                                                                                   HumanOccurrenceIdentity -> result
    -- | Consume collective participant-uniqueness evidence.
  , eliminateHumanCollectiveParticipantUniqueness :: HumanOccurrenceIdentity -> NonEmpty
                                                                                  HumanOccurrenceIdentity -> result
    -- | Consume collective target-type evidence.
  , eliminateHumanCollectiveTargetType :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume collective target-cardinality evidence.
  , eliminateHumanCollectiveTargetCardinality :: HumanOccurrenceIdentity -> HumanStructureZeroOrMultipleOccurrences -> result
    -- | Consume collective target-distinctness evidence.
  , eliminateHumanCollectiveTargetDistinctness :: HumanOccurrenceIdentity -> NonEmpty
                                                                               HumanOccurrenceIdentity -> result
  }

-- | Opaque Operation-owned projection of one exact Core semantic defect.
newtype HumanSemanticDiagnosticEvidence =
  HumanSemanticDiagnosticEvidence
    (forall result. HumanSemanticDiagnosticEliminator result -> result)

-- | Total consumer algebra for every projected semantic diagnostic shape.
data HumanSemanticDiagnosticEliminator result = HumanSemanticDiagnosticEliminator
    -- | Consume collective coverage evidence.
  { eliminateHumanCollectiveAssertedCollectiveCoverage :: HumanModelIdentity -> NonEmpty
                                                                                  HumanOccurrenceIdentity -> result
    -- | Consume collective completeness evidence.
  , eliminateHumanCollectiveAssertedCompleteness :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume asserted macro-support evidence.
  , eliminateHumanCollectiveAssertedMacroSupport :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume asserted participant primitive-support evidence.
  , eliminateHumanCollectiveAssertedParticipantPrimitiveSupport :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume pairwise-coherence evidence.
  , eliminateHumanCollectiveFitPairwiseCoherence :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume participant-binding evidence.
  , eliminateHumanCollectiveFitParticipantBinding :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume participant-compatibility evidence.
  , eliminateHumanCollectiveFitParticipantCompatibility :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume target-binding evidence.
  , eliminateHumanCollectiveFitTargetBinding :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume target-guiding-policy evidence.
  , eliminateHumanCollectiveFitTargetGuidingPolicy :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume target-trade-offs evidence.
  , eliminateHumanCollectiveFitTargetTradeOffs :: HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume asserted-dependency contextualization evidence.
  , eliminateHumanContextualizationAssertedDependency :: HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Need-driver anchoring evidence.
  , eliminateHumanSituatedNeedDriverAnchoring :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Need-driver cardinality evidence.
  , eliminateHumanSituatedNeedDriverCardinality :: HumanModelIdentity -> result
    -- | Consume Need-objective cardinality evidence.
  , eliminateHumanSituatedNeedObjectiveCardinality :: HumanModelIdentity -> result
    -- | Consume Need-objective grounding evidence.
  , eliminateHumanSituatedNeedObjectiveGrounding :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Need surfacing-situation anchoring evidence.
  , eliminateHumanSituatedNeedSurfacingSituationAnchoring :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Need surfacing-situation cardinality evidence.
  , eliminateHumanSituatedNeedSurfacingSituationCardinality :: HumanModelIdentity -> result
    -- | Consume Strategy action-contribution evidence.
  , eliminateHumanStrategyFormulationActionContributions :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Strategy action-list evidence.
  , eliminateHumanStrategyFormulationActions :: HumanModelIdentity -> NonEmpty
                                                                        HumanOccurrenceIdentity -> result
    -- | Consume Strategy diagnosis evidence.
  , eliminateHumanStrategyFormulationDiagnosis :: HumanModelIdentity -> [HumanOccurrenceIdentity] -> result
    -- | Consume Strategy diagnosis-grounding evidence.
  , eliminateHumanStrategyFormulationDiagnosisGrounding :: HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Strategy guiding-policy evidence.
  , eliminateHumanStrategyFormulationGuidingPolicy :: HumanModelIdentity -> [HumanOccurrenceIdentity] -> result
    -- | Consume Strategy guiding-policy action evidence.
  , eliminateHumanStrategyFormulationGuidingPolicyActions :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Strategy intent evidence.
  , eliminateHumanStrategyFormulationIntent :: HumanModelIdentity -> [HumanOccurrenceIdentity] -> result
    -- | Consume Strategy key-result substantiation evidence.
  , eliminateHumanStrategyFormulationKeyResultSubstantiation :: HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result
    -- | Consume Strategy key-result-list evidence.
  , eliminateHumanStrategyFormulationKeyResults :: HumanModelIdentity -> NonEmpty
                                                                           HumanOccurrenceIdentity -> result
    -- | Consume Strategy vision-orientation evidence.
  , eliminateHumanStrategyFormulationVisionOrientation :: HumanModelIdentity -> result
  }

-- | Closed authority-typed diagnostic evidence family.
data HumanDiagnosticEvidence where
  HumanNotationEvidenceFamily
    :: HumanNotationDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanActivationEvidenceFamily
    :: HumanActivationDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanProfileEvidenceFamily
    :: HumanProfileDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanProfileClassificationEvidenceFamily
    :: HumanProfileClassificationDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanProfileMappingEvidenceFamily
    :: HumanProfileMappingDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanProfileInvariantEvidenceFamily
    :: HumanProfileInvariantDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanStructureEvidenceFamily
    :: HumanStructureDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanSemanticsEvidenceFamily
    :: HumanSemanticDiagnosticEvidence -> HumanDiagnosticEvidence
  HumanSupplementalIdentityUnknownEvidence
    :: HumanSourceIdentity
    -> Text
    -> HumanModelIdentity
    -> HumanDiagnosticEvidence
  HumanSupplementalIdentityAmbiguousEvidence
    :: HumanSourceIdentity
    -> Text
    -> HumanModelIdentity
    -> HumanDiagnosticEvidence
  HumanSupplementalIdentityWrongTypeEvidence
    :: HumanSourceIdentity
    -> Text
    -> HumanModelIdentity
    -> HumanDiagnosticEvidence
  HumanSupplementalIdentityOutOfSelectedViewEvidence
    :: HumanSourceIdentity
    -> Text
    -> HumanModelIdentity
    -> HumanDiagnosticEvidence

-- | Complete diagnostic metadata and exact typed evidence.
data HumanDiagnostic =
  HumanDiagnostic
    Text
    Text
    Text
    Text
    HumanDiagnosticSeverity
    HumanDiagnosticDisposition
    Text
    HumanDiagnosticEvidence

-- | Notation evidence kind bound to its selected-adapter rule.
data HumanNotationRuleBinding =
  HumanNotationRuleBinding Text Text

-- | Adapter, notation rules, Profile, and model authority of a document.
data HumanDiagnosticAuthority =
  HumanDiagnosticAuthority
    HumanAdapterDescriptor
    [HumanNotationRuleBinding]
    HumanProfileDescriptor
    HumanSourceIdentity

-- | Diagnostics grouped under their exact supplemental source.
data HumanSupplementalDiagnosticGroup =
  HumanSupplementalDiagnosticGroup HumanSourceIdentity [HumanDiagnostic]

-- | Authority-once model and supplemental diagnostic projection.
data HumanDiagnosticDocument =
  HumanDiagnosticDocument
    HumanDiagnosticAuthority
    [HumanDiagnostic]
    [HumanSupplementalDiagnosticGroup]

-- | Consume the stable severity token.
foldHumanDiagnosticSeverity ::
     (Text -> result) -> HumanDiagnosticSeverity -> result
foldHumanDiagnosticSeverity consume (HumanDiagnosticSeverity value) =
  consume value

-- | Consume the stable disposition token.
foldHumanDiagnosticDisposition ::
     (Text -> result) -> HumanDiagnosticDisposition -> result
foldHumanDiagnosticDisposition consume (HumanDiagnosticDisposition value) =
  consume value

-- | Eliminate both closed Adapter rule stages.
foldHumanAdapterRuleStage :: result -> result -> HumanAdapterRuleStage -> result
foldHumanAdapterRuleStage preparation notation stage =
  case stage of
    HumanAdapterPreparationRuleStage -> preparation
    HumanAdapterNotationRuleStage -> notation

-- | Consume every Adapter rule field in owner order.
foldHumanAdapterRule ::
     (Text -> HumanAdapterRuleStage -> Text -> Text -> Text -> result)
  -> HumanAdapterRule
  -> result
foldHumanAdapterRule consume (HumanAdapterRule identity stage expectation meaning action) =
  consume identity stage expectation meaning action

-- | Canonical non-empty View-inventory subtype in owner order.
humanViewInventoryIssueKinds :: NonEmpty HumanViewInventoryIssueKind
humanViewInventoryIssueKinds =
  HumanViewInventoryIssueKind . Notation.viewInventoryIssueKindToken
    <$> Notation.allViewInventoryIssueKinds

-- | Consume the owner-generated View-inventory subtype token.
foldHumanViewInventoryIssueKind ::
     (Text -> result) -> HumanViewInventoryIssueKind -> result
foldHumanViewInventoryIssueKind consume (HumanViewInventoryIssueKind token) =
  consume token

-- | Canonical non-empty Profile-marker subtype in owner order.
humanProfileMarkerIssueKinds :: NonEmpty HumanProfileMarkerIssueKind
humanProfileMarkerIssueKinds =
  HumanProfileMarkerIssueKind . Notation.profileMarkerIssueKindToken
    <$> Notation.allProfileMarkerIssueKinds

-- | Consume the owner-generated Profile-marker subtype token.
foldHumanProfileMarkerIssueKind ::
     (Text -> result) -> HumanProfileMarkerIssueKind -> result
foldHumanProfileMarkerIssueKind consume (HumanProfileMarkerIssueKind token) =
  consume token

-- | Canonical non-empty selected-universe subtype in owner order.
humanSelectedUniverseIssueKinds :: NonEmpty HumanSelectedUniverseIssueKind
humanSelectedUniverseIssueKinds =
  HumanSelectedUniverseIssueKind . Notation.selectedUniverseIssueKindToken
    <$> Notation.allSelectedUniverseIssueKinds

-- | Consume the owner-generated selected-universe subtype token.
foldHumanSelectedUniverseIssueKind ::
     (Text -> result) -> HumanSelectedUniverseIssueKind -> result
foldHumanSelectedUniverseIssueKind consume (HumanSelectedUniverseIssueKind token) =
  consume token

-- | Eliminate the three independently closed Notation issue families.
foldHumanNotationIssueKind ::
     (HumanViewInventoryIssueKind -> result)
  -> (HumanProfileMarkerIssueKind -> result)
  -> (HumanSelectedUniverseIssueKind -> result)
  -> HumanNotationIssueKind
  -> result
foldHumanNotationIssueKind inventory marker universe kind =
  case kind of
    HumanViewInventoryIssue value -> inventory value
    HumanProfileMarkerIssue value -> marker value
    HumanSelectedUniverseIssue value -> universe value

-- | Eliminate every recognized or explicitly retained Draft value kind.
foldHumanDraftValueKind ::
     result
  -> result
  -> result
  -> result
  -> (Text -> result)
  -> HumanDraftValueKind
  -> result
foldHumanDraftValueKind text boolean number nativeName other kind =
  case kind of
    HumanDraftTextValue -> text
    HumanDraftBooleanValue -> boolean
    HumanDraftNumberValue -> number
    HumanDraftNativeNameValue -> nativeName
    HumanDraftOtherValue token -> other token

-- | Eliminate every exact Notation observation branch.
foldHumanNotationObservation ::
     (HumanSourceLocation -> result)
  -> (HumanSourceLocation -> HumanDraftValueKind -> Text -> result)
  -> (HumanSourceLocation -> Text -> [HumanSourceLocation] -> result)
  -> HumanNotationObservation
  -> result
foldHumanNotationObservation occurrence value reference observation =
  case observation of
    HumanNotationOccurrence location -> occurrence location
    HumanNotationValue location kind retained -> value location kind retained
    HumanNotationReference location retained targets ->
      reference location retained targets

-- | Consume the exact Adapter, rule, issue kind, subject, and observations.
foldHumanNotationDiagnosticEvidence ::
     (HumanAdapterDescriptor -> HumanAdapterRule -> HumanNotationIssueKind -> HumanSourceLocation -> NonEmpty
                                                                                                       HumanNotationObservation -> result)
  -> HumanNotationDiagnosticEvidence
  -> result
foldHumanNotationDiagnosticEvidence consume (HumanNotationDiagnosticEvidence adapter rule kind subject observations) =
  consume adapter rule kind subject observations

-- | Eliminate both Profile closure branches.
foldHumanClosureBranch :: result -> result -> HumanClosureBranch -> result
foldHumanClosureBranch graph qualification branch =
  case branch of
    HumanGraphClosureBranch -> graph
    HumanQualificationClosureBranch -> qualification

-- | Consume every generated Profile activation field in owner order.
foldHumanActivationDiagnosticEvidence ::
     (Text -> Text -> HumanClosureBranch -> Text -> HumanCanonicalOccurrence -> HumanCanonicalOccurrence -> [Text] -> result)
  -> HumanActivationDiagnosticEvidence
  -> result
foldHumanActivationDiagnosticEvidence consume (HumanActivationDiagnosticEvidence profile digest branch rule owner trigger sourceRules) =
  consume profile digest branch rule owner trigger sourceRules

-- | Eliminate every closed generated Profile evidence category.
foldHumanProfileEvidenceKind ::
     result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> result
  -> HumanProfileEvidenceKind
  -> result
foldHumanProfileEvidenceKind carrier classification metadata property slot value proposal reference relationship reserved structured incidence kind =
  case kind of
    HumanCarrierOccurrenceEvidence -> carrier
    HumanClassificationOccurrenceEvidence -> classification
    HumanMetadataOwnerAndO2iPropertyOccurrencesEvidence -> metadata
    HumanPropertyOccurrenceEvidence -> property
    HumanPropertySlotEvidence -> slot
    HumanPropertyValueEvidence -> value
    HumanProposalCarrierOccurrenceEvidence -> proposal
    HumanProposalReferenceIncidenceEvidence -> reference
    HumanRelationshipOccurrenceEvidence -> relationship
    HumanReservedPropertyOccurrenceEvidence -> reserved
    HumanStructuredCarrierOccurrenceEvidence -> structured
    HumanStructuredIncidenceEvidence -> incidence

-- | Eliminate the exact closed Profile defect and all of its fields.
foldHumanProfileDiagnosticEvidence ::
     HumanProfileDiagnosticEliminator result
  -> HumanProfileDiagnosticEvidence
  -> result
foldHumanProfileDiagnosticEvidence eliminator (HumanProfileDiagnosticEvidence consume) =
  consume eliminator

-- | Consume all positive Profile classification fields.
foldHumanProfileClassificationDiagnosticEvidence ::
     (Bool -> Bool -> Text -> HumanCanonicalOccurrence -> result)
  -> HumanProfileClassificationDiagnosticEvidence
  -> result
foldHumanProfileClassificationDiagnosticEvidence consume (HumanProfileClassificationDiagnosticEvidence graph qualification rule occurrence) =
  consume graph qualification rule occurrence

-- | Eliminate all concrete Profile mapping provenance branches.
foldHumanProfileMappingDiagnosticEvidence ::
     (Text -> HumanOccurrenceIdentity -> Text -> result)
  -> (Text -> HumanOccurrenceIdentity -> Text -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result)
  -> (Text -> HumanOccurrenceIdentity -> Text -> HumanProfileEvidenceKind -> result)
  -> HumanProfileMappingDiagnosticEvidence
  -> result
foldHumanProfileMappingDiagnosticEvidence carrier relation construction evidence =
  case evidence of
    HumanProfileCarrierMapping rule occurrence mapping ->
      carrier rule occurrence mapping
    HumanProfileRelationMapping rule occurrence mapping source target ->
      relation rule occurrence mapping source target
    HumanProfileConstructionMapping rule occurrence mapping kind ->
      construction rule occurrence mapping kind

-- | Consume the rule and proposal-carrier occurrence of an invariant.
foldHumanProfileInvariantDiagnosticEvidence ::
     (Text -> HumanCanonicalOccurrence -> result)
  -> HumanProfileInvariantDiagnosticEvidence
  -> result
foldHumanProfileInvariantDiagnosticEvidence consume (HumanProfileInvariantDiagnosticEvidence rule occurrence) =
  consume rule occurrence

-- | Eliminate constructive zero-or-at-least-two Structure occurrences.
foldHumanStructureZeroOrMultipleOccurrences ::
     result
  -> (HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> [HumanOccurrenceIdentity] -> result)
  -> HumanStructureZeroOrMultipleOccurrences
  -> result
foldHumanStructureZeroOrMultipleOccurrences zero multiple occurrences =
  case occurrences of
    HumanNoStructureOccurrence -> zero
    HumanMultipleStructureOccurrences first second remaining ->
      multiple first second remaining

-- | Eliminate the exact closed Structure defect and all of its fields.
foldHumanStructureDiagnosticEvidence ::
     HumanStructureDiagnosticEliminator result
  -> HumanStructureDiagnosticEvidence
  -> result
foldHumanStructureDiagnosticEvidence eliminator (HumanStructureDiagnosticEvidence consume) =
  consume eliminator

-- | Eliminate the exact closed semantic producer branch and all of its fields.
foldHumanSemanticDiagnosticEvidence ::
     HumanSemanticDiagnosticEliminator result
  -> HumanSemanticDiagnosticEvidence
  -> result
foldHumanSemanticDiagnosticEvidence eliminator (HumanSemanticDiagnosticEvidence consume) =
  consume eliminator

-- | Eliminate every closed diagnostic-evidence family.
foldHumanDiagnosticEvidence ::
     (HumanNotationDiagnosticEvidence -> result)
  -> (HumanActivationDiagnosticEvidence -> result)
  -> (HumanProfileDiagnosticEvidence -> result)
  -> (HumanProfileClassificationDiagnosticEvidence -> result)
  -> (HumanProfileMappingDiagnosticEvidence -> result)
  -> (HumanProfileInvariantDiagnosticEvidence -> result)
  -> (HumanStructureDiagnosticEvidence -> result)
  -> (HumanSemanticDiagnosticEvidence -> result)
  -> (HumanSourceIdentity -> Text -> HumanModelIdentity -> result)
  -> (HumanSourceIdentity -> Text -> HumanModelIdentity -> result)
  -> (HumanSourceIdentity -> Text -> HumanModelIdentity -> result)
  -> (HumanSourceIdentity -> Text -> HumanModelIdentity -> result)
  -> HumanDiagnosticEvidence
  -> result
foldHumanDiagnosticEvidence notation activation profile classification mapping invariant structure semantics unknown ambiguous wrongType outOfView evidence =
  case evidence of
    HumanNotationEvidenceFamily value -> notation value
    HumanActivationEvidenceFamily value -> activation value
    HumanProfileEvidenceFamily value -> profile value
    HumanProfileClassificationEvidenceFamily value -> classification value
    HumanProfileMappingEvidenceFamily value -> mapping value
    HumanProfileInvariantEvidenceFamily value -> invariant value
    HumanStructureEvidenceFamily value -> structure value
    HumanSemanticsEvidenceFamily value -> semantics value
    HumanSupplementalIdentityUnknownEvidence source pointer identity ->
      unknown source pointer identity
    HumanSupplementalIdentityAmbiguousEvidence source pointer identity ->
      ambiguous source pointer identity
    HumanSupplementalIdentityWrongTypeEvidence source pointer identity ->
      wrongType source pointer identity
    HumanSupplementalIdentityOutOfSelectedViewEvidence source pointer identity ->
      outOfView source pointer identity

-- | Return the stable evidence-kind code of a diagnostic.
humanDiagnosticCode :: HumanDiagnostic -> Text
humanDiagnosticCode (HumanDiagnostic _ _ _ _ _ _ code _) = code

-- | Return the exact authoritative rule identity of a diagnostic.
humanDiagnosticRuleId :: HumanDiagnostic -> Text
humanDiagnosticRuleId (HumanDiagnostic _ _ _ rule _ _ _ _) = rule

-- | Consume all diagnostic metadata and exact typed evidence.
foldHumanDiagnostic ::
     (Text -> Text -> Text -> Text -> HumanDiagnosticSeverity -> HumanDiagnosticDisposition -> Text -> HumanDiagnosticEvidence -> result)
  -> HumanDiagnostic
  -> result
foldHumanDiagnostic consume (HumanDiagnostic producer owner stage rule severity disposition kind evidence) =
  consume producer owner stage rule severity disposition kind evidence

-- | Consume a notation evidence kind and its rule identity.
foldHumanNotationRuleBinding ::
     (Text -> Text -> result) -> HumanNotationRuleBinding -> result
foldHumanNotationRuleBinding consume (HumanNotationRuleBinding kind rule) =
  consume kind rule

-- | Consume every authority field retained once per document.
foldHumanDiagnosticAuthority ::
     (HumanAdapterDescriptor -> [HumanNotationRuleBinding] -> HumanProfileDescriptor -> HumanSourceIdentity -> result)
  -> HumanDiagnosticAuthority
  -> result
foldHumanDiagnosticAuthority consume (HumanDiagnosticAuthority adapter rules profile model) =
  consume adapter rules profile model

-- | Consume the supplemental source and all of its diagnostics.
foldHumanSupplementalDiagnosticGroup ::
     (HumanSourceIdentity -> [HumanDiagnostic] -> result)
  -> HumanSupplementalDiagnosticGroup
  -> result
foldHumanSupplementalDiagnosticGroup consume (HumanSupplementalDiagnosticGroup source diagnostics) =
  consume source diagnostics

-- | Consume authority, model diagnostics, and supplemental groups.
foldHumanDiagnosticDocument ::
     (HumanDiagnosticAuthority -> [HumanDiagnostic] -> [HumanSupplementalDiagnosticGroup] -> result)
  -> HumanDiagnosticDocument
  -> result
foldHumanDiagnosticDocument consume (HumanDiagnosticDocument authority model supplemental) =
  consume authority model supplemental

-- | Return the exact acquired model source bound into document authority.
humanDiagnosticDocumentModelSource ::
     HumanDiagnosticDocument -> HumanSourceIdentity
humanDiagnosticDocumentModelSource document =
  foldHumanDiagnosticDocument
    (\authority _ _ ->
       foldHumanDiagnosticAuthority (\_ _ _ model -> model) authority)
    document

-- | Project a complete prepared diagnostic document without rendering it.
humanDiagnosticDocument :: PreparedDiagnosticDocument -> HumanDiagnosticDocument
humanDiagnosticDocument =
  foldPreparedDiagnosticDocument $ \authority diagnostics groups ->
    HumanDiagnosticDocument
      (projectAuthority authority)
      (map projectPreparedDiagnostic diagnostics)
      (foldSupplementalDiagnosticGroups
         (\source values ->
            HumanSupplementalDiagnosticGroup
              (supplementalSourceIdentity source)
              (map projectSupplementalDiagnostic values))
         id
         groups)

projectAuthority ::
     PreparedAuthority authority profile document -> HumanDiagnosticAuthority
projectAuthority (PreparedAuthority contract profile model) =
  HumanDiagnosticAuthority
    (projectAdapterDescriptor (adapterContractDescriptor contract))
    [ HumanNotationRuleBinding
      ("archimate-notation-" <> Notation.archiMateNotationIssueKindToken kind)
      (adapterRuleIdText (adapterRuleId rule))
    | kind <- toList Notation.allArchiMateNotationIssueKinds
    , Just rule <- [lookupArchiMateNotationRule kind contract]
    ]
    (projectProfileDescriptor profile)
    (projectSourceIdentity model)

projectPreparedDiagnostic ::
     PreparedDiagnostic authority profile document -> HumanDiagnostic
projectPreparedDiagnostic diagnostic =
  HumanDiagnostic
    (preparedDiagnosticProducer diagnostic)
    (preparedDiagnosticOwner diagnostic)
    (preparedDiagnosticStage diagnostic)
    (preparedDiagnosticRuleIdentity diagnostic)
    (projectSeverity (preparedDiagnosticSeverity diagnostic))
    (projectDisposition (preparedDiagnosticDisposition diagnostic))
    (diagnosticEvidenceCode evidence)
    evidence
  where
    evidence =
      foldPreparedDiagnostic
        (HumanNotationEvidenceFamily . projectNotationDiagnosticEvidence)
        (HumanActivationEvidenceFamily . projectActivationDiagnosticEvidence)
        (HumanProfileEvidenceFamily . projectProfileDiagnosticEvidence)
        (HumanProfileClassificationEvidenceFamily
           . projectProfileClassificationDiagnosticEvidence)
        (HumanProfileMappingEvidenceFamily
           . projectProfileMappingDiagnosticEvidence)
        (HumanProfileInvariantEvidenceFamily
           . projectProfileInvariantDiagnosticEvidence)
        (HumanStructureEvidenceFamily . projectStructureDiagnosticEvidence)
        (HumanSemanticsEvidenceFamily . projectSemanticDiagnosticEvidence)
        diagnostic

projectAdapterRule :: AdapterRule -> HumanAdapterRule
projectAdapterRule rule =
  HumanAdapterRule
    (adapterRuleIdText (adapterRuleId rule))
    (foldAdapterRuleStage
       HumanAdapterPreparationRuleStage
       HumanAdapterNotationRuleStage
       (adapterRuleStage rule))
    (adapterRuleExpectation rule)
    (adapterRuleMeaning rule)
    (adapterRuleAction rule)

projectNotationIssueKind ::
     Notation.ArchiMateNotationIssueKind -> HumanNotationIssueKind
projectNotationIssueKind =
  Notation.foldArchiMateNotationIssueKind
    (HumanViewInventoryIssue
       . HumanViewInventoryIssueKind
       . Notation.viewInventoryIssueKindToken)
    (HumanProfileMarkerIssue
       . HumanProfileMarkerIssueKind
       . Notation.profileMarkerIssueKindToken)
    (HumanSelectedUniverseIssue
       . HumanSelectedUniverseIssueKind
       . Notation.selectedUniverseIssueKindToken)

projectDraftValueKind :: Draft.DraftValueKind -> HumanDraftValueKind
projectDraftValueKind =
  Draft.foldDraftValueKind
    HumanDraftTextValue
    HumanDraftBooleanValue
    HumanDraftNumberValue
    HumanDraftNativeNameValue
    HumanDraftOtherValue

projectNotationObservation ::
     Notation.ArchiMateNotationEvidence -> HumanNotationObservation
projectNotationObservation =
  Notation.foldArchiMateNotationEvidence
    (HumanNotationOccurrence . projectSourceLocation)
    (\location kind retained ->
       HumanNotationValue
         (projectSourceLocation location)
         (projectDraftValueKind kind)
         retained)
    (\location retained targets ->
       HumanNotationReference
         (projectSourceLocation location)
         retained
         (map projectSourceLocation targets))

projectNotationDiagnosticEvidence ::
     AdapterNotationDiagnostic -> HumanNotationDiagnosticEvidence
projectNotationDiagnosticEvidence =
  foldAdapterNotationDiagnostic $ \descriptor rule issue ->
    HumanNotationDiagnosticEvidence
      (projectAdapterDescriptor descriptor)
      (projectAdapterRule rule)
      (projectNotationIssueKind (Notation.archiMateNotationIssueKind issue))
      (projectSourceLocation (Notation.archiMateNotationIssueSubject issue))
      (projectNotationObservation
         <$> Notation.archiMateNotationIssueEvidence issue)

projectClosureBranch :: Closure.ClosureBranch -> HumanClosureBranch
projectClosureBranch =
  Closure.foldClosureBranch
    HumanGraphClosureBranch
    HumanQualificationClosureBranch

projectActivationDiagnosticEvidence ::
     Closure.ActivationProvenance profile document
  -> HumanActivationDiagnosticEvidence
projectActivationDiagnosticEvidence =
  Closure.foldActivationProvenance $ \profile digest branch rule owner trigger sourceRules ->
    HumanActivationDiagnosticEvidence
      profile
      digest
      (projectClosureBranch branch)
      rule
      (projectCanonicalOccurrence owner)
      (projectCanonicalOccurrence trigger)
      sourceRules

projectProfileEvidenceKind ::
     Profile.ProfileEvidenceKind -> HumanProfileEvidenceKind
projectProfileEvidenceKind =
  Profile.foldProfileEvidenceKind
    HumanCarrierOccurrenceEvidence
    HumanClassificationOccurrenceEvidence
    HumanMetadataOwnerAndO2iPropertyOccurrencesEvidence
    HumanPropertyOccurrenceEvidence
    HumanPropertySlotEvidence
    HumanPropertyValueEvidence
    HumanProposalCarrierOccurrenceEvidence
    HumanProposalReferenceIncidenceEvidence
    HumanRelationshipOccurrenceEvidence
    HumanReservedPropertyOccurrenceEvidence
    HumanStructuredCarrierOccurrenceEvidence
    HumanStructuredIncidenceEvidence

projectProfileDiagnosticEvidence ::
     Profile.ProfileDiagnosticEvidence profile document
  -> HumanProfileDiagnosticEvidence
projectProfileDiagnosticEvidence =
  Profile.foldProfileDiagnosticEvidence $ \rule evidence ->
    HumanProfileDiagnosticEvidence $ \eliminator ->
      Profile.foldProfileEvidence
        (eliminateHumanProfileCarrierOccurrence eliminator rule
           . projectCanonicalOccurrence)
        (eliminateHumanProfileClassificationOccurrence eliminator rule
           . projectCanonicalOccurrence)
        (\owner properties ->
           eliminateHumanProfileMetadataOwnerAndO2iPropertyOccurrences
             eliminator
             rule
             (projectCanonicalOccurrence owner)
             (map projectCanonicalOccurrence properties))
        (\property owner ->
           eliminateHumanProfilePropertyOccurrence
             eliminator
             rule
             (projectCanonicalOccurrence property)
             (projectCanonicalOccurrence owner))
        (\owner key properties ->
           eliminateHumanProfilePropertySlot
             eliminator
             rule
             (projectCanonicalOccurrence owner)
             key
             (map projectCanonicalOccurrence properties))
        (\property owner scalars ->
           eliminateHumanProfilePropertyValue
             eliminator
             rule
             (projectCanonicalOccurrence property)
             (projectCanonicalOccurrence owner)
             (map projectDraftScalar scalars))
        (eliminateHumanProfileProposalCarrierOccurrence eliminator rule
           . projectCanonicalOccurrence)
        (\reference proposal related ->
           eliminateHumanProfileProposalReferenceIncidence
             eliminator
             rule
             (projectCanonicalOccurrence reference)
             (projectCanonicalOccurrence proposal)
             (map projectCanonicalOccurrence related))
        (eliminateHumanProfileRelationshipOccurrence eliminator rule
           . projectCanonicalOccurrence)
        (\property owner key ->
           eliminateHumanProfileReservedPropertyOccurrence
             eliminator
             rule
             (projectCanonicalOccurrence property)
             (projectCanonicalOccurrence owner)
             key)
        (eliminateHumanProfileStructuredCarrierOccurrence eliminator rule
           . projectCanonicalOccurrence)
        (\incidence related ->
           eliminateHumanProfileStructuredIncidence
             eliminator
             rule
             (projectCanonicalOccurrence incidence)
             (map projectCanonicalOccurrence related))
        evidence

projectProfileClassificationDiagnosticEvidence ::
     Profile.ProfileClassificationEvidence profile document
  -> HumanProfileClassificationDiagnosticEvidence
projectProfileClassificationDiagnosticEvidence =
  Profile.foldProfileClassificationEvidence $ \graph qualification rule occurrence ->
    HumanProfileClassificationDiagnosticEvidence
      graph
      qualification
      rule
      (projectCanonicalOccurrence occurrence)

projectProfileMappingDiagnosticEvidence ::
     Profile.ProfileMappingProvenance profile document
  -> HumanProfileMappingDiagnosticEvidence
projectProfileMappingDiagnosticEvidence evidence =
  Profile.foldProfileMappingProvenance
    (\rule occurrence mapping ->
       HumanProfileCarrierMapping
         rule
         (projectOccurrenceIdentity occurrence)
         mapping)
    (\rule occurrence mapping source target ->
       HumanProfileRelationMapping
         rule
         (projectOccurrenceIdentity occurrence)
         mapping
         (projectOccurrenceIdentity source)
         (projectOccurrenceIdentity target))
    (\rule occurrence mapping ->
       HumanProfileConstructionMapping
         rule
         (projectOccurrenceIdentity occurrence)
         mapping
         (projectProfileEvidenceKind
            (Profile.profileMappingEvidenceKind evidence)))
    evidence

projectProfileInvariantDiagnosticEvidence ::
     Profile.ProfileInvariantEvidence profile document
  -> HumanProfileInvariantDiagnosticEvidence
projectProfileInvariantDiagnosticEvidence =
  Profile.foldProfileInvariantEvidence $ \rule evidence ->
    Profile.foldProfileEvidence
      (project rule)
      (project rule)
      (\owner _ -> project rule owner)
      (\property _ -> project rule property)
      (\owner _ _ -> project rule owner)
      (\property _ _ -> project rule property)
      (project rule)
      (\reference _ _ -> project rule reference)
      (project rule)
      (\property _ _ -> project rule property)
      (project rule)
      (\incidence _ -> project rule incidence)
      evidence
  where
    project rule =
      HumanProfileInvariantDiagnosticEvidence rule . projectCanonicalOccurrence

projectStructureZeroOrMultipleOccurrences ::
     Structure.StructureZeroOrMultipleOccurrences
  -> HumanStructureZeroOrMultipleOccurrences
projectStructureZeroOrMultipleOccurrences =
  Structure.foldStructureZeroOrMultipleOccurrences
    HumanNoStructureOccurrence
    (\first second remaining ->
       HumanMultipleStructureOccurrences
         (projectOccurrenceIdentity first)
         (projectOccurrenceIdentity second)
         (map projectOccurrenceIdentity remaining))

projectStructureDiagnosticEvidence ::
     Structure.StructureEvidence scope -> HumanStructureDiagnosticEvidence
projectStructureDiagnosticEvidence evidence =
  HumanStructureDiagnosticEvidence $ \eliminator ->
    Structure.foldStructureEvidence
      Structure.StructureDefectEliminator
        { Structure.eliminateQualifiedEndpointCatalogMembership =
            eliminateHumanQualifiedEndpointCatalogMembership eliminator
              . projectOccurrenceIdentity
              . Structure.qualifiedEndpointCatalogMembershipSubject
        , Structure.eliminateContextualizationSourceCategory =
            \value ->
              eliminateHumanContextualizationSourceCategory
                eliminator
                (projectOccurrenceIdentity
                   (Structure.contextualizationSourceCategorySegment value))
                (projectOccurrenceIdentity
                   (Structure.contextualizationSourceCategoryOwner value))
        , Structure.eliminateContextualizationTargetCategory =
            \value ->
              eliminateHumanContextualizationTargetCategory
                eliminator
                (projectOccurrenceIdentity
                   (Structure.contextualizationTargetCategorySegment value))
                (projectOccurrenceIdentity
                   (Structure.contextualizationTargetCategoryMember value))
        , Structure.eliminateContextualizationTargetOwnerCardinality =
            \value ->
              eliminateHumanContextualizationTargetOwnerCardinality
                eliminator
                (projectOccurrenceIdentity
                   (Structure.contextualizationTargetOwnerCardinalityMember
                      value))
                (projectStructureZeroOrMultipleOccurrences
                   (Structure.contextualizationTargetOwnerCardinalityOwners
                      value))
        , Structure.eliminateSemanticRelationCompatibility =
            \value ->
              eliminateHumanSemanticRelationCompatibility
                eliminator
                (projectOccurrenceIdentity
                   (Structure.semanticRelationCompatibilityRelation value))
                (projectOccurrenceIdentity
                   (Structure.semanticRelationCompatibilitySource value))
                (projectOccurrenceIdentity
                   (Structure.semanticRelationCompatibilityTarget value))
        , Structure.eliminateStructuredPropositionIdentity =
            \value ->
              eliminateHumanStructuredPropositionIdentity
                eliminator
                (projectOccurrenceIdentity
                   (Structure.structuredPropositionIdentitySubject value))
                (projectOccurrenceIdentity
                   (Structure.structuredPropositionIdentityFirstOccurrence value))
                (projectOccurrenceIdentity
                   (Structure.structuredPropositionIdentitySecondOccurrence
                      value))
                (map
                   projectOccurrenceIdentity
                   (Structure.structuredPropositionIdentityRemainingOccurrences
                      value))
        , Structure.eliminateCollectiveParticipantType =
            \value ->
              eliminateHumanCollectiveParticipantType
                eliminator
                (projectOccurrenceIdentity
                   (Structure.collectiveParticipantTypeClaim value))
                (projectOccurrenceIdentity
                   (Structure.collectiveParticipantTypeSegment value))
                (projectOccurrenceIdentity
                   (Structure.collectiveParticipantTypeEndpoint value))
        , Structure.eliminateCollectiveParticipantCardinality =
            \value ->
              eliminateHumanCollectiveParticipantCardinality
                eliminator
                (projectOccurrenceIdentity
                   (Structure.collectiveParticipantCardinalityClaim value))
                (projectOccurrenceIdentity
                   <$> Structure.collectiveParticipantCardinalitySoleEndpoint
                         value)
        , Structure.eliminateCollectiveParticipantUniqueness =
            \value ->
              eliminateHumanCollectiveParticipantUniqueness
                eliminator
                (projectOccurrenceIdentity
                   (Structure.collectiveParticipantUniquenessClaim value))
                (projectOccurrenceIdentity
                   <$> Structure.collectiveParticipantUniquenessDuplicateEndpoints
                         value)
        , Structure.eliminateCollectiveTargetType =
            \value ->
              eliminateHumanCollectiveTargetType
                eliminator
                (projectOccurrenceIdentity
                   (Structure.collectiveTargetTypeClaim value))
                (projectOccurrenceIdentity
                   (Structure.collectiveTargetTypeSegment value))
                (projectOccurrenceIdentity
                   (Structure.collectiveTargetTypeEndpoint value))
        , Structure.eliminateCollectiveTargetCardinality =
            \value ->
              eliminateHumanCollectiveTargetCardinality
                eliminator
                (projectOccurrenceIdentity
                   (Structure.collectiveTargetCardinalityClaim value))
                (projectStructureZeroOrMultipleOccurrences
                   (Structure.collectiveTargetCardinalityEndpoints value))
        , Structure.eliminateCollectiveTargetDistinctness =
            \value ->
              eliminateHumanCollectiveTargetDistinctness
                eliminator
                (projectOccurrenceIdentity
                   (Structure.collectiveTargetDistinctnessClaim value))
                (projectOccurrenceIdentity
                   <$> Structure.collectiveTargetDistinctnessOverlappingEndpoints
                         value)
        }
      evidence

projectSeverity :: DiagnosticSeverity -> HumanDiagnosticSeverity
projectSeverity = HumanDiagnosticSeverity . diagnosticSeverityText

projectDisposition :: DiagnosticDisposition -> HumanDiagnosticDisposition
projectDisposition = HumanDiagnosticDisposition . diagnosticDispositionText

diagnosticEvidenceCode :: HumanDiagnosticEvidence -> Text
diagnosticEvidenceCode =
  foldHumanDiagnosticEvidence
    (foldHumanNotationDiagnosticEvidence
       (\_ _ kind _ _ ->
          "archimate-notation-" <> humanNotationIssueKindToken kind))
    (\_ -> "activation-provenance")
    profileEvidenceCode
    (\_ -> "classification-occurrence")
    mappingEvidenceCode
    (\_ -> "proposal-carrier-occurrence")
    structureEvidenceCode
    semanticEvidenceCode
    (\_ _ _ -> "identity-unknown")
    (\_ _ _ -> "identity-ambiguous")
    (\_ _ _ -> "identity-wrong-type")
    (\_ _ _ -> "identity-out-of-selected-view")

humanNotationIssueKindToken :: HumanNotationIssueKind -> Text
humanNotationIssueKindToken =
  foldHumanNotationIssueKind
    (foldHumanViewInventoryIssueKind id)
    (foldHumanProfileMarkerIssueKind id)
    (foldHumanSelectedUniverseIssueKind id)

profileEvidenceCode :: HumanProfileDiagnosticEvidence -> Text
profileEvidenceCode =
  foldHumanProfileDiagnosticEvidence
    HumanProfileDiagnosticEliminator
      { eliminateHumanProfileCarrierOccurrence = \_ _ -> "carrier-occurrence"
      , eliminateHumanProfileClassificationOccurrence =
          \_ _ -> "classification-occurrence"
      , eliminateHumanProfileMetadataOwnerAndO2iPropertyOccurrences =
          \_ _ _ -> "metadata-owner-and-o2i-property-occurrences"
      , eliminateHumanProfilePropertyOccurrence =
          \_ _ _ -> "property-occurrence-evidence"
      , eliminateHumanProfilePropertySlot = \_ _ _ _ -> "property-slot-evidence"
      , eliminateHumanProfilePropertyValue =
          \_ _ _ _ -> "property-value-evidence"
      , eliminateHumanProfileProposalCarrierOccurrence =
          \_ _ -> "proposal-carrier-occurrence"
      , eliminateHumanProfileProposalReferenceIncidence =
          \_ _ _ _ -> "proposal-reference-incidence"
      , eliminateHumanProfileRelationshipOccurrence =
          \_ _ -> "relationship-occurrence"
      , eliminateHumanProfileReservedPropertyOccurrence =
          \_ _ _ _ -> "reserved-property-occurrence"
      , eliminateHumanProfileStructuredCarrierOccurrence =
          \_ _ -> "structured-carrier-occurrence"
      , eliminateHumanProfileStructuredIncidence =
          \_ _ _ -> "structured-incidence"
      }

mappingEvidenceCode :: HumanProfileMappingDiagnosticEvidence -> Text
mappingEvidenceCode =
  foldHumanProfileMappingDiagnosticEvidence
    (\_ _ _ -> "carrier-occurrence")
    (\_ _ _ _ _ -> "relationship-occurrence")
    (\_ _ _ kind -> profileKindText kind)

profileKindText :: HumanProfileEvidenceKind -> Text
profileKindText =
  foldHumanProfileEvidenceKind
    "carrier-occurrence"
    "classification-occurrence"
    "metadata-owner-and-o2i-property-occurrences"
    "property-occurrence-evidence"
    "property-slot-evidence"
    "property-value-evidence"
    "proposal-carrier-occurrence"
    "proposal-reference-incidence"
    "relationship-occurrence"
    "reserved-property-occurrence"
    "structured-carrier-occurrence"
    "structured-incidence"

structureEvidenceCode :: HumanStructureDiagnosticEvidence -> Text
structureEvidenceCode =
  foldHumanStructureDiagnosticEvidence
    HumanStructureDiagnosticEliminator
      { eliminateHumanQualifiedEndpointCatalogMembership =
          \_ -> "qualified-endpoint-catalog-membership"
      , eliminateHumanContextualizationSourceCategory =
          \_ _ -> "contextualization-source-category"
      , eliminateHumanContextualizationTargetCategory =
          \_ _ -> "contextualization-target-category"
      , eliminateHumanContextualizationTargetOwnerCardinality =
          \_ _ -> "contextualization-target-owner-cardinality"
      , eliminateHumanSemanticRelationCompatibility =
          \_ _ _ -> "semantic-relation-compatibility"
      , eliminateHumanStructuredPropositionIdentity =
          \_ _ _ _ -> "structured-proposition-identity"
      , eliminateHumanCollectiveParticipantType =
          \_ _ _ -> "collective-participant-type"
      , eliminateHumanCollectiveParticipantCardinality =
          \_ _ -> "collective-participant-cardinality"
      , eliminateHumanCollectiveParticipantUniqueness =
          \_ _ -> "collective-participant-uniqueness"
      , eliminateHumanCollectiveTargetType = \_ _ _ -> "collective-target-type"
      , eliminateHumanCollectiveTargetCardinality =
          \_ _ -> "collective-target-cardinality"
      , eliminateHumanCollectiveTargetDistinctness =
          \_ _ -> "collective-target-distinctness"
      }

projectSupplementalDiagnostic :: SupplementalDiagnostic -> HumanDiagnostic
projectSupplementalDiagnostic diagnostic =
  foldSupplementalDiagnostic
    (project "identity-unknown" HumanSupplementalIdentityUnknownEvidence)
    (project "identity-ambiguous" HumanSupplementalIdentityAmbiguousEvidence)
    (project "identity-wrong-type" HumanSupplementalIdentityWrongTypeEvidence)
    (project
       "identity-out-of-selected-view"
       HumanSupplementalIdentityOutOfSelectedViewEvidence)
    diagnostic
  where
    project kind constructor source pointer identity =
      HumanDiagnostic
        "supplemental-binding"
        "core"
        "capability-input"
        (supplementalDiagnosticRuleIdentity diagnostic)
        (HumanDiagnosticSeverity "error")
        (HumanDiagnosticDisposition "process-failure")
        kind
        (constructor
           (supplementalSourceIdentity source)
           pointer
           (projectModelIdentity identity))

supplementalSourceIdentity :: AcquiredSupplementalSource -> HumanSourceIdentity
supplementalSourceIdentity =
  foldAcquiredSupplementalSource
    (projectSourceIdentity . acquiredSourceIdentity)

projectSemanticDiagnosticEvidence ::
     Semantics.SemanticDiagnosticEvidence scope
  -> HumanSemanticDiagnosticEvidence
projectSemanticDiagnosticEvidence =
  Semantics.foldSemanticDiagnosticEvidence
    Semantics.SemanticDiagnosticEliminator
      { Semantics.eliminateCollectiveAssertedCollectiveCoverage =
          \claim occurrences ->
            projected $ \eliminator ->
              eliminateHumanCollectiveAssertedCollectiveCoverage
                eliminator
                (projectModelIdentity claim)
                (projectOccurrenceIdentity <$> occurrences)
      , Semantics.eliminateCollectiveAssertedCompleteness =
          \claim occurrence ->
            projected $ \eliminator ->
              eliminateHumanCollectiveAssertedCompleteness
                eliminator
                (projectModelIdentity claim)
                (projectOccurrenceIdentity occurrence)
      , Semantics.eliminateCollectiveAssertedMacroSupport =
          \claim participant claimOccurrence participantOccurrence targetOccurrence ->
            projected $ \eliminator ->
              eliminateHumanCollectiveAssertedMacroSupport
                eliminator
                (projectModelIdentity claim)
                (projectModelIdentity participant)
                (projectOccurrenceIdentity claimOccurrence)
                (projectOccurrenceIdentity participantOccurrence)
                (projectOccurrenceIdentity targetOccurrence)
      , Semantics.eliminateCollectiveAssertedParticipantPrimitiveSupport =
          \claim participant claimOccurrence participantOccurrence targetOccurrence ->
            projected $ \eliminator ->
              eliminateHumanCollectiveAssertedParticipantPrimitiveSupport
                eliminator
                (projectModelIdentity claim)
                (projectModelIdentity participant)
                (projectOccurrenceIdentity claimOccurrence)
                (projectOccurrenceIdentity participantOccurrence)
                (projectOccurrenceIdentity targetOccurrence)
      , Semantics.eliminateCollectiveFitPairwiseCoherence =
          projectFit eliminateHumanCollectiveFitPairwiseCoherence
      , Semantics.eliminateCollectiveFitParticipantBinding =
          projectFit eliminateHumanCollectiveFitParticipantBinding
      , Semantics.eliminateCollectiveFitParticipantCompatibility =
          projectFit eliminateHumanCollectiveFitParticipantCompatibility
      , Semantics.eliminateCollectiveFitTargetBinding =
          projectFit eliminateHumanCollectiveFitTargetBinding
      , Semantics.eliminateCollectiveFitTargetGuidingPolicy =
          projectFit eliminateHumanCollectiveFitTargetGuidingPolicy
      , Semantics.eliminateCollectiveFitTargetTradeOffs =
          projectFit eliminateHumanCollectiveFitTargetTradeOffs
      , Semantics.eliminateContextualizationAssertedDependency =
          \dependent endpoint context dependentOccurrence endpointOccurrence contextOccurrence ->
            projected $ \eliminator ->
              eliminateHumanContextualizationAssertedDependency
                eliminator
                (projectOccurrenceIdentity dependent)
                (projectOccurrenceIdentity endpoint)
                (projectOccurrenceIdentity context)
                (projectOccurrenceIdentity dependentOccurrence)
                (projectOccurrenceIdentity endpointOccurrence)
                (projectOccurrenceIdentity contextOccurrence)
      , Semantics.eliminateSituatedNeedDriverAnchoring =
          projectNeedMember eliminateHumanSituatedNeedDriverAnchoring
      , Semantics.eliminateSituatedNeedDriverCardinality =
          projectOne eliminateHumanSituatedNeedDriverCardinality
      , Semantics.eliminateSituatedNeedObjectiveCardinality =
          projectOne eliminateHumanSituatedNeedObjectiveCardinality
      , Semantics.eliminateSituatedNeedObjectiveGrounding =
          projectNeedMember eliminateHumanSituatedNeedObjectiveGrounding
      , Semantics.eliminateSituatedNeedSurfacingSituationAnchoring =
          projectNeedMember
            eliminateHumanSituatedNeedSurfacingSituationAnchoring
      , Semantics.eliminateSituatedNeedSurfacingSituationCardinality =
          projectOne eliminateHumanSituatedNeedSurfacingSituationCardinality
      , Semantics.eliminateStrategyFormulationActionContributions =
          projectNeedMember eliminateHumanStrategyFormulationActionContributions
      , Semantics.eliminateStrategyFormulationActions =
          \strategy occurrences ->
            projected $ \eliminator ->
              eliminateHumanStrategyFormulationActions
                eliminator
                (projectModelIdentity strategy)
                (projectOccurrenceIdentity <$> occurrences)
      , Semantics.eliminateStrategyFormulationDiagnosis =
          projectMany eliminateHumanStrategyFormulationDiagnosis
      , Semantics.eliminateStrategyFormulationDiagnosisGrounding =
          projectPair eliminateHumanStrategyFormulationDiagnosisGrounding
      , Semantics.eliminateStrategyFormulationGuidingPolicy =
          projectMany eliminateHumanStrategyFormulationGuidingPolicy
      , Semantics.eliminateStrategyFormulationGuidingPolicyActions =
          projectMemberPair
            eliminateHumanStrategyFormulationGuidingPolicyActions
      , Semantics.eliminateStrategyFormulationIntent =
          projectMany eliminateHumanStrategyFormulationIntent
      , Semantics.eliminateStrategyFormulationKeyResultSubstantiation =
          projectMemberPair
            eliminateHumanStrategyFormulationKeyResultSubstantiation
      , Semantics.eliminateStrategyFormulationKeyResults =
          \strategy occurrences ->
            projected $ \eliminator ->
              eliminateHumanStrategyFormulationKeyResults
                eliminator
                (projectModelIdentity strategy)
                (projectOccurrenceIdentity <$> occurrences)
      , Semantics.eliminateStrategyFormulationVisionOrientation =
          projectOne eliminateHumanStrategyFormulationVisionOrientation
      }
  where
    projected ::
         (forall result. HumanSemanticDiagnosticEliminator result -> result)
      -> HumanSemanticDiagnosticEvidence
    projected = HumanSemanticDiagnosticEvidence
    projectFit ::
         (forall result. HumanSemanticDiagnosticEliminator result -> HumanModelIdentity -> HumanOccurrenceIdentity -> result)
      -> ModelIdentity
      -> OccurrenceIdentity
      -> HumanSemanticDiagnosticEvidence
    projectFit consume identity occurrence =
      projected $ \eliminator ->
        consume
          eliminator
          (projectModelIdentity identity)
          (projectOccurrenceIdentity occurrence)
    projectNeedMember ::
         (forall result. HumanSemanticDiagnosticEliminator result -> HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> result)
      -> ModelIdentity
      -> ModelIdentity
      -> OccurrenceIdentity
      -> HumanSemanticDiagnosticEvidence
    projectNeedMember consume owner member occurrence =
      projected $ \eliminator ->
        consume
          eliminator
          (projectModelIdentity owner)
          (projectModelIdentity member)
          (projectOccurrenceIdentity occurrence)
    projectOne ::
         (forall result. HumanSemanticDiagnosticEliminator result -> HumanModelIdentity -> result)
      -> ModelIdentity
      -> HumanSemanticDiagnosticEvidence
    projectOne consume identity =
      projected $ \eliminator ->
        consume eliminator (projectModelIdentity identity)
    projectMany ::
         (forall result. HumanSemanticDiagnosticEliminator result -> HumanModelIdentity -> [HumanOccurrenceIdentity] -> result)
      -> ModelIdentity
      -> [OccurrenceIdentity]
      -> HumanSemanticDiagnosticEvidence
    projectMany consume identity occurrences =
      projected $ \eliminator ->
        consume
          eliminator
          (projectModelIdentity identity)
          (map projectOccurrenceIdentity occurrences)
    projectPair ::
         (forall result. HumanSemanticDiagnosticEliminator result -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result)
      -> ModelIdentity
      -> OccurrenceIdentity
      -> OccurrenceIdentity
      -> HumanSemanticDiagnosticEvidence
    projectPair consume identity first second =
      projected $ \eliminator ->
        consume
          eliminator
          (projectModelIdentity identity)
          (projectOccurrenceIdentity first)
          (projectOccurrenceIdentity second)
    projectMemberPair ::
         (forall result. HumanSemanticDiagnosticEliminator result -> HumanModelIdentity -> HumanModelIdentity -> HumanOccurrenceIdentity -> HumanOccurrenceIdentity -> result)
      -> ModelIdentity
      -> ModelIdentity
      -> OccurrenceIdentity
      -> OccurrenceIdentity
      -> HumanSemanticDiagnosticEvidence
    projectMemberPair consume owner member first second =
      projected $ \eliminator ->
        consume
          eliminator
          (projectModelIdentity owner)
          (projectModelIdentity member)
          (projectOccurrenceIdentity first)
          (projectOccurrenceIdentity second)

semanticEvidenceCode :: HumanSemanticDiagnosticEvidence -> Text
semanticEvidenceCode =
  foldHumanSemanticDiagnosticEvidence
    HumanSemanticDiagnosticEliminator
      { eliminateHumanCollectiveAssertedCollectiveCoverage =
          \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveAssertedCompleteness = \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveAssertedMacroSupport =
          \_ _ _ _ _ -> "ParticipantClaimKey"
      , eliminateHumanCollectiveAssertedParticipantPrimitiveSupport =
          \_ _ _ _ _ -> "ParticipantClaimKey"
      , eliminateHumanCollectiveFitPairwiseCoherence = \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveFitParticipantBinding = \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveFitParticipantCompatibility =
          \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveFitTargetBinding = \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveFitTargetGuidingPolicy = \_ _ -> "FitClaimKey"
      , eliminateHumanCollectiveFitTargetTradeOffs = \_ _ -> "FitClaimKey"
      , eliminateHumanContextualizationAssertedDependency =
          \_ _ _ _ _ _ -> "AssertedDependencyKey"
      , eliminateHumanSituatedNeedDriverAnchoring = \_ _ _ -> "NeedMemberKey"
      , eliminateHumanSituatedNeedDriverCardinality = \_ -> "NeedKey"
      , eliminateHumanSituatedNeedObjectiveCardinality = \_ -> "NeedKey"
      , eliminateHumanSituatedNeedObjectiveGrounding = \_ _ _ -> "NeedMemberKey"
      , eliminateHumanSituatedNeedSurfacingSituationAnchoring =
          \_ _ _ -> "NeedMemberKey"
      , eliminateHumanSituatedNeedSurfacingSituationCardinality =
          \_ -> "NeedKey"
      , eliminateHumanStrategyFormulationActionContributions =
          \_ _ _ -> "StrategyMemberKey"
      , eliminateHumanStrategyFormulationActions = \_ _ -> "StrategyKey"
      , eliminateHumanStrategyFormulationDiagnosis = \_ _ -> "StrategyKey"
      , eliminateHumanStrategyFormulationDiagnosisGrounding =
          \_ _ _ -> "StrategyKey"
      , eliminateHumanStrategyFormulationGuidingPolicy = \_ _ -> "StrategyKey"
      , eliminateHumanStrategyFormulationGuidingPolicyActions =
          \_ _ _ _ -> "StrategyMemberKey"
      , eliminateHumanStrategyFormulationIntent = \_ _ -> "StrategyKey"
      , eliminateHumanStrategyFormulationKeyResultSubstantiation =
          \_ _ _ _ -> "StrategyMemberKey"
      , eliminateHumanStrategyFormulationKeyResults = \_ _ -> "StrategyKey"
      , eliminateHumanStrategyFormulationVisionOrientation = \_ -> "StrategyKey"
      }

toList :: Foldable collection => collection value -> [value]
toList = foldr (:) []
