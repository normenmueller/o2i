{-# LANGUAGE RoleAnnotations #-}

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
  , -- | Opaque selected-Profile and source-bound assessment universe.
    ProfileAssessmentUniverse
  , deriveProfileAssessmentUniverse
  , assessmentCanonicalDocument
  , assessmentSelectedViewOccurrence
  , assessmentDisplayedOccurrences
  , assessmentGraphOccurrences
  , assessmentQualificationOccurrences
  , assessmentUniverse
  , assessmentActivationProvenance
  , assessmentClosureProvenance
  ) where

import qualified Data.Set as Set
import Data.Text (Text)
import O2I.ArchiMate.Profile.Internal.Closure hiding
  ( ActivationProvenance
  , ClosureProvenance
  )
import qualified O2I.ArchiMate.Profile.Internal.Closure as Internal
import O2I.ArchiMate.Profile.Internal.Closure.Witness
import qualified O2I.ArchiMate.Profile.Internal.Notation.Witness as Witness
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , CanonicalOccurrence
  , CanonicalView
  )
import O2I.ArchiMate.Profile.Resolution (SelectedArchiMateProfile)

-- | Activation provenance nominal in its selected Profile document.
newtype ActivationProvenance profile document =
  ActivationProvenance Internal.ActivationProvenance

type role ActivationProvenance nominal nominal

-- | Closure provenance nominal in its selected Profile document.
newtype ClosureProvenance profile document =
  ClosureProvenance Internal.ClosureProvenance

type role ClosureProvenance nominal nominal

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
  -> ActivationProvenance profile document
  -> result
foldActivationProvenance consume (ActivationProvenance provenance) =
  consume
    (Internal.activationProvenanceProfileIdentityValue provenance)
    (Internal.activationProvenanceProfileDigestValue provenance)
    (Internal.activationProvenanceBranchValue provenance)
    (Internal.activationProvenanceRuleIdValue provenance)
    (Internal.activationProvenanceOwnerValue provenance)
    (Internal.activationProvenanceTriggerValue provenance)
    (Internal.activationProvenanceSourceRuleIdsValue provenance)

-- | Consume all closure evidence without exposing its constructor.
foldClosureProvenance ::
     (Text -> Text -> ClosureBranch -> Text -> CanonicalOccurrence -> CanonicalOccurrence -> [CanonicalOccurrence] -> result)
  -> ClosureProvenance profile document
  -> result
foldClosureProvenance consume (ClosureProvenance provenance) =
  consume
    (Internal.closureProvenanceProfileIdentityValue provenance)
    (Internal.closureProvenanceProfileDigestValue provenance)
    (Internal.closureProvenanceBranchValue provenance)
    (Internal.closureProvenanceRuleIdValue provenance)
    (Internal.closureProvenanceTriggerValue provenance)
    (Internal.closureProvenanceIncludedValue provenance)
    (Internal.closureProvenanceContextValue provenance)

-- | Derive branch-separated positive closure for one selected Profile and View.
--
-- Closure is positive inventory material. Profile validation and Core
-- semantics remain separate assessment capabilities.
deriveProfileAssessmentUniverse ::
     SelectedArchiMateProfile profile
  -> CanonicalDocument document
  -> CanonicalView document
  -> ProfileAssessmentUniverse profile document
deriveProfileAssessmentUniverse = deriveProfileAssessmentUniverseValue

-- | Canonical document from which the selected View was closed.
assessmentCanonicalDocument ::
     ProfileAssessmentUniverse profile document -> CanonicalDocument document
assessmentCanonicalDocument =
  Witness.CanonicalDocument
    . closedViewDocumentValue
    . profileAssessmentUniverseValue

-- | Canonical occurrence of the selected native View.
assessmentSelectedViewOccurrence ::
     ProfileAssessmentUniverse profile document -> CanonicalOccurrence
assessmentSelectedViewOccurrence =
  closedViewOccurrenceValue . profileAssessmentUniverseValue

-- | Exact displayed occurrences retained from the selected View.
assessmentDisplayedOccurrences ::
     ProfileAssessmentUniverse profile document -> [DisplayedOccurrence]
assessmentDisplayedOccurrences =
  closedViewDisplayedOccurrencesValue . profileAssessmentUniverseValue

-- | Deterministic graph-branch occurrence closure.
assessmentGraphOccurrences ::
     ProfileAssessmentUniverse profile document -> [CanonicalOccurrence]
assessmentGraphOccurrences =
  Set.toAscList
    . closedViewGraphOccurrencesValue
    . profileAssessmentUniverseValue

-- | Deterministic qualification-branch occurrence closure.
assessmentQualificationOccurrences ::
     ProfileAssessmentUniverse profile document -> [CanonicalOccurrence]
assessmentQualificationOccurrences =
  Set.toAscList
    . closedViewQualificationOccurrencesValue
    . profileAssessmentUniverseValue

-- | Complete deterministic occurrence universe of both closure branches.
assessmentUniverse ::
     ProfileAssessmentUniverse profile document -> [CanonicalOccurrence]
assessmentUniverse =
  Set.toAscList . closedViewUniverseValue . profileAssessmentUniverseValue

-- | Deterministic activation provenance retained for both branches.
assessmentActivationProvenance ::
     ProfileAssessmentUniverse profile document
  -> [ActivationProvenance profile document]
assessmentActivationProvenance =
  map ActivationProvenance
    . Set.toAscList
    . closedViewActivationProvenanceValue
    . profileAssessmentUniverseValue

-- | Deterministic inclusion provenance retained for both branches.
assessmentClosureProvenance ::
     ProfileAssessmentUniverse profile document
  -> [ClosureProvenance profile document]
assessmentClosureProvenance =
  map ClosureProvenance
    . Set.toAscList
    . closedViewClosureProvenanceValue
    . profileAssessmentUniverseValue
