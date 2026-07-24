-- | Private commitment-aware state retained across structural assessment.
module O2I.Validation.Structure.Internal
  ( StructuralAssessment
  , StructuralNodeIndex
  , StructuralNodeDeclaration
  , mkStructuralAssessment
  , mkStructuralNodeIndex
  , mkStructuralNodeDeclaration
  , structuralAssessmentGraph
  , structuralAssessmentCandidates
  , lookupStructuralNodeDeclaration
  , structuralNodeDeclarationCommitment
  , structuralNodeDeclarationKind
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Claim
import O2I.Language.Element

-- | Opaque structural result separating asserted semantics from Candidates.
--
-- The graph contains only Asserted propositions. The private declaration index
-- retains Candidate commitments solely for dependency validation and precise
-- diagnostics.
data StructuralAssessment =
  StructuralAssessment
    WellFormedGraph
    [CandidateGraphProposition]
    StructuralNodeIndex

-- | Opaque index of every structurally accepted node declaration.
newtype StructuralNodeIndex =
  StructuralNodeIndex (Map RawNodeId StructuralNodeDeclaration)

-- | Opaque commitment-aware declaration accepted at the structural boundary.
data StructuralNodeDeclaration =
  StructuralNodeDeclaration Commitment NodeKindValue

mkStructuralAssessment ::
     WellFormedGraph
  -> [CandidateGraphProposition]
  -> StructuralNodeIndex
  -> StructuralAssessment
mkStructuralAssessment = StructuralAssessment

mkStructuralNodeIndex ::
     [(RawNodeId, StructuralNodeDeclaration)] -> StructuralNodeIndex
mkStructuralNodeIndex = StructuralNodeIndex . Map.fromList

mkStructuralNodeDeclaration ::
     Commitment -> NodeKindValue -> StructuralNodeDeclaration
mkStructuralNodeDeclaration = StructuralNodeDeclaration

structuralAssessmentGraph :: StructuralAssessment -> WellFormedGraph
structuralAssessmentGraph (StructuralAssessment graph _ _) = graph

structuralAssessmentCandidates ::
     StructuralAssessment -> [CandidateGraphProposition]
structuralAssessmentCandidates (StructuralAssessment _ candidates _) =
  candidates

lookupStructuralNodeDeclaration ::
     StructuralAssessment -> RawNodeId -> Maybe StructuralNodeDeclaration
lookupStructuralNodeDeclaration (StructuralAssessment _ _ (StructuralNodeIndex declarations)) identifier =
  Map.lookup identifier declarations

structuralNodeDeclarationCommitment :: StructuralNodeDeclaration -> Commitment
structuralNodeDeclarationCommitment (StructuralNodeDeclaration commitment _) =
  commitment

structuralNodeDeclarationKind :: StructuralNodeDeclaration -> NodeKindValue
structuralNodeDeclarationKind (StructuralNodeDeclaration _ kind) = kind
