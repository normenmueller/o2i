-- | Positive, branch-separated selected-View Profile closure.
--
-- Operation selects one View descriptor. Profile derives its displayed
-- occurrences, computes graph and qualification closure independently, and
-- retains every activation and closure reason.
module O2I.ArchiMate.Profile.Closure
  ( -- | One subject occurrence displayed by one selected View.
    DisplayedOccurrence
  , displayedViewOccurrence
  , displayedSubjectOccurrence
  , -- | Closed Profile closure branch: graph or qualification.
    ClosureBranch
  , foldClosureBranch
  , -- | Exact generated rule evidence that activated one closure branch.
    ActivationProvenance
  , foldActivationProvenance
  , -- | Exact generated rule evidence that included one occurrence.
    ClosureProvenance
  , foldClosureProvenance
  , -- | Opaque positive closure of one selected native View.
    ClosedView
  , closeSelectedView
  , closedCanonicalDocument
  , closedSelectedViewOccurrence
  , closedDisplayedOccurrences
  , closedGraphOccurrences
  , closedQualificationOccurrences
  , closedViewUniverse
  , closedActivationProvenance
  , closedClosureProvenance
  ) where

import qualified Data.Set as Set
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Closure
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , CanonicalOccurrence
  , ViewDescriptor
  )

-- | Canonical occurrence of the native View displaying the subject.
displayedViewOccurrence :: DisplayedOccurrence -> CanonicalOccurrence
displayedViewOccurrence = displayedViewOccurrenceValue

-- | Canonical occurrence displayed in the native View.
displayedSubjectOccurrence :: DisplayedOccurrence -> CanonicalOccurrence
displayedSubjectOccurrence = displayedSubjectOccurrenceValue

-- | Consume both closed branch alternatives.
foldClosureBranch :: result -> result -> ClosureBranch -> result
foldClosureBranch graph qualification branch =
  case branch of
    GraphBranch -> graph
    QualificationBranch -> qualification

-- | Consume all activation evidence without exposing its constructor.
--
-- The evidence binds generated Profile rules to notation occurrences; it
-- introduces no independent fachliche semantics.
foldActivationProvenance ::
     (Text -> Text -> ClosureBranch -> Text -> CanonicalOccurrence -> CanonicalOccurrence -> [Text] -> result)
  -> ActivationProvenance
  -> result
foldActivationProvenance consume provenance =
  consume
    (activationProvenanceProfileIdentityValue provenance)
    (activationProvenanceProfileDigestValue provenance)
    (activationProvenanceBranchValue provenance)
    (activationProvenanceRuleIdValue provenance)
    (activationProvenanceOwnerValue provenance)
    (activationProvenanceTriggerValue provenance)
    (activationProvenanceSourceRuleIdsValue provenance)

-- | Consume all closure evidence without exposing its constructor.
foldClosureProvenance ::
     (Text -> Text -> ClosureBranch -> Text -> CanonicalOccurrence -> CanonicalOccurrence -> [CanonicalOccurrence] -> result)
  -> ClosureProvenance
  -> result
foldClosureProvenance consume provenance =
  consume
    (closureProvenanceProfileIdentityValue provenance)
    (closureProvenanceProfileDigestValue provenance)
    (closureProvenanceBranchValue provenance)
    (closureProvenanceRuleIdValue provenance)
    (closureProvenanceTriggerValue provenance)
    (closureProvenanceIncludedValue provenance)
    (closureProvenanceContextValue provenance)

-- | Derive branch-separated Profile closure for one selected View.
--
-- Closure is positive inventory material. Profile validation and Core
-- semantics remain separate assessment capabilities.
closeSelectedView :: ViewDescriptor -> ClosedView
closeSelectedView = closeView

-- | Canonical document from which the selected View was closed.
closedCanonicalDocument :: ClosedView -> CanonicalDocument
closedCanonicalDocument = closedViewDocumentValue

-- | Canonical occurrence of the selected native View.
closedSelectedViewOccurrence :: ClosedView -> CanonicalOccurrence
closedSelectedViewOccurrence = closedViewOccurrenceValue

-- | Exact displayed occurrences retained from the selected View.
closedDisplayedOccurrences :: ClosedView -> [DisplayedOccurrence]
closedDisplayedOccurrences = closedViewDisplayedOccurrencesValue

-- | Deterministic graph-branch occurrence closure.
closedGraphOccurrences :: ClosedView -> [CanonicalOccurrence]
closedGraphOccurrences = Set.toAscList . closedViewGraphOccurrencesValue

-- | Deterministic qualification-branch occurrence closure.
closedQualificationOccurrences :: ClosedView -> [CanonicalOccurrence]
closedQualificationOccurrences =
  Set.toAscList . closedViewQualificationOccurrencesValue

-- | Complete deterministic occurrence universe of both closure branches.
closedViewUniverse :: ClosedView -> [CanonicalOccurrence]
closedViewUniverse = Set.toAscList . closedViewUniverseValue

-- | Deterministic activation provenance retained for both branches.
closedActivationProvenance :: ClosedView -> [ActivationProvenance]
closedActivationProvenance = Set.toAscList . closedViewActivationProvenanceValue

-- | Deterministic inclusion provenance retained for both branches.
closedClosureProvenance :: ClosedView -> [ClosureProvenance]
closedClosureProvenance = Set.toAscList . closedViewClosureProvenanceValue
