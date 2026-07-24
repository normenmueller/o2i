{-# LANGUAGE DataKinds #-}

-- | Complete semantic assessment of one O2I model boundary.
--
-- Context content and collective Strategy realization are assessed as one
-- normative unit. Model maturity is derived exactly once from this complete
-- boundary.
module O2I.Validation.Semantics
  ( StrategyAnchoring(..)
  , RawStrategyFormulation(..)
  , StrategyFormulation
  , Elaboration(..)
  , Maturity(..)
  , ModelSemanticsInput(..)
  , CandidateModelProposition(..)
  , ModelSemanticError(..)
  , ModelAssessmentStatus(..)
  , ModelAssessment
  , StrategyTextField(..)
  , StrategyPrimitiveRole(..)
  , ModelInvariantError(..)
  , SemanticallyValidModel
  , assessModelSemantics
  , modelAssessmentStatus
  , assessedSemanticModel
  , assessmentInvariantErrors
  , assessmentCollectiveErrors
  , assessmentCandidatePropositions
  , assessmentCandidateCollectiveStrategyRealizations
  , assessmentValidatedCollectiveStrategyRealizations
  , contextElaboration
  , modelMaturity
  , modelGraph
  , modelContextSemantics
  , strategyFormulations
  , strategyFormulationData
  , validatedCollectiveStrategyRealizations
  , lookupSemanticContextRef
  , qualifyingStrategies
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Validation (Validation(..))
import O2I.Graph.Raw (RawEdge, RawNode)
import O2I.Graph.Typed
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Validation.Collective
import O2I.Validation.Semantics.Context
import O2I.Validation.Structure (StructuralAssessment)

-- | Derived semantic maturity of one complete assessed model boundary.
data Maturity
  = Skeleton
    -- ^ No Context in scope has a complete validated content bundle.
  | Draft
    -- ^ Some content is elaborated while unresolved or invalid claims remain.
  | SemanticallyValid
    -- ^ The complete semantic boundary is valid and contains no Candidate.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Complete raw input to one normative semantic assessment.
data ModelSemanticsInput = ModelSemanticsInput
  { modelStrategyClaims :: [Claim RawStrategyFormulation]
    -- ^ Strategy content claims in source order.
  , modelCollectiveClaims :: [Claim RawCollectiveStrategyRealization]
    -- ^ Collective Strategy-realization claims in source order.
  , modelCollectiveFitEvidence :: [RawCollectiveFitEvidence]
    -- ^ Structured Fit evidence available to the collective claims.
  } deriving (Eq, Show)

-- | Candidate proposition retained by complete model assessment and excluded
-- from validated semantics.
data CandidateModelProposition
  = CandidateModelNode RawNode
    -- ^ Proposed element declaration.
  | CandidateModelEdge RawEdge
    -- ^ Proposed relation declaration.
  | CandidateStrategyFormulation RawNodeId
    -- ^ Proposed Strategy content bundle.
  | CandidateCollectiveRealization ClaimId
    -- ^ Structurally admissible proposed collective Strategy realization.
  deriving (Eq, Show)

-- | Fatal semantic defect from one part of the complete assessment boundary.
data ModelSemanticError
  = ContextSemanticError ModelInvariantError
  | CollectiveSemanticError CollectiveStrategyRealizationError
  deriving (Eq, Show)

-- | Closed result state of one complete semantic assessment.
data ModelAssessmentStatus
  = SemanticsRejected (NonEmpty ModelSemanticError)
    -- ^ At least one fatal asserted or structural defect exists.
  | SemanticsPending (NonEmpty CandidateModelProposition)
    -- ^ No fatal defect exists, but at least one Candidate remains.
  | SemanticsAccepted SemanticallyValidModel
    -- ^ Every applicable semantic obligation has passed.

-- | Opaque result of assessing the complete model-semantic boundary.
data ModelAssessment = ModelAssessment
  { assessedContext :: ContextAssessment
  , assessedCollective :: Maybe CollectiveStrategyRealizationAssessment
  , assessedCollectiveValidation :: Maybe
      ValidatedCollectiveStrategyRealizations
  , assessedCandidates :: [CandidateModelProposition]
  , assessedStatus :: ModelAssessmentStatus
  , assessedMaturity :: Maturity
  }

-- | Opaque model whose complete Context and collective semantics are valid.
data SemanticallyValidModel =
  SemanticallyValidModel
    ContextSemantics
    ValidatedCollectiveStrategyRealizations

-- | Assess all semantic claims within one exact structural boundary.
--
-- Fatal errors dominate pending Candidates without discarding Candidate
-- diagnostics. Collective semantics is assessed only after Context semantics
-- has established its required graph and Strategy-formulation invariants.
assessModelSemantics ::
     StructuralAssessment -> ModelSemanticsInput -> ModelAssessment
assessModelSemantics structure inputs =
  ModelAssessment
    { assessedContext = contextAssessment
    , assessedCollective = collectiveAssessment
    , assessedCollectiveValidation = collectiveValidation
    , assessedCandidates = candidates
    , assessedStatus = status
    , assessedMaturity = deriveMaturity elaborations status
    }
  where
    contextAssessment =
      assessContextSemantics structure (modelStrategyClaims inputs)
    elaborations = contextAssessmentElaborations contextAssessment
    contextCandidates =
      map
        contextCandidate
        (contextAssessmentCandidatePropositions contextAssessment)
    (collectiveAssessment, collectiveValidation, candidates, status) =
      case contextAssessmentStatus contextAssessment of
        ContextRejected errors ->
          ( Nothing
          , Nothing
          , contextCandidates
          , SemanticsRejected (fmap ContextSemanticError errors))
        ContextPending pendingContexts ->
          let pending = fmap contextCandidate pendingContexts
           in ( Nothing
              , Nothing
              , NonEmpty.toList pending
              , SemanticsPending pending)
        ContextAccepted context ->
          let assessment =
                assessCollectiveStrategyRealizations
                  context
                  (modelCollectiveFitEvidence inputs)
                  (modelCollectiveClaims inputs)
              collectiveCandidates =
                map
                  collectiveCandidate
                  (candidateCollectiveStrategyRealizations assessment)
           in case validateCollectiveStrategyRealizations assessment of
                Failure errors ->
                  ( Just assessment
                  , Nothing
                  , collectiveCandidates
                  , SemanticsRejected (fmap CollectiveSemanticError errors))
                Success validated ->
                  case NonEmpty.nonEmpty collectiveCandidates of
                    Just pending ->
                      ( Just assessment
                      , Just validated
                      , collectiveCandidates
                      , SemanticsPending pending)
                    Nothing ->
                      ( Just assessment
                      , Just validated
                      , []
                      , SemanticsAccepted
                          (SemanticallyValidModel context validated))

-- | Read the closed result state derived by the normative Core.
modelAssessmentStatus :: ModelAssessment -> ModelAssessmentStatus
modelAssessmentStatus = assessedStatus

-- | Read the exact semantic model only after the complete boundary has passed.
assessedSemanticModel :: ModelAssessment -> Maybe SemanticallyValidModel
assessedSemanticModel assessment =
  case assessedStatus assessment of
    SemanticsAccepted model -> Just model
    SemanticsRejected _ -> Nothing
    SemanticsPending _ -> Nothing

-- | Read failed Context and Strategy-content invariants.
assessmentInvariantErrors :: ModelAssessment -> [ModelInvariantError]
assessmentInvariantErrors = contextAssessmentInvariantErrors . assessedContext

-- | Read failed collective Strategy-realization invariants.
assessmentCollectiveErrors ::
     ModelAssessment -> [CollectiveStrategyRealizationError]
assessmentCollectiveErrors =
  maybe [] collectiveStrategyRealizationErrors . assessedCollective

-- | Read every Candidate excluded from validated model semantics.
assessmentCandidatePropositions ::
     ModelAssessment -> [CandidateModelProposition]
assessmentCandidatePropositions = assessedCandidates

-- | Read detailed collective Candidate assessments retained for diagnostics.
assessmentCandidateCollectiveStrategyRealizations ::
     ModelAssessment -> [CandidateCollectiveStrategyRealization]
assessmentCandidateCollectiveStrategyRealizations =
  maybe [] candidateCollectiveStrategyRealizations . assessedCollective

-- | Read validated collective realizations available within this assessment.
--
-- A pending Candidate does not invalidate independent Asserted realizations.
-- Fatal collective errors prevent aggregate witness projection.
assessmentValidatedCollectiveStrategyRealizations ::
     ModelAssessment -> Maybe ValidatedCollectiveStrategyRealizations
assessmentValidatedCollectiveStrategyRealizations = assessedCollectiveValidation

-- | Read one Context's elaboration from the complete assessment boundary.
contextElaboration :: ModelAssessment -> RawNodeId -> Maybe Elaboration
contextElaboration = contextAssessmentElaboration . assessedContext

-- | Read the maturity derived exactly once for this complete boundary.
modelMaturity :: ModelAssessment -> Maturity
modelMaturity = assessedMaturity

-- | Access the structurally valid graph underlying complete semantics.
modelGraph :: SemanticallyValidModel -> WellFormedGraph
modelGraph (SemanticallyValidModel context _) = contextGraph context

-- | Project Context semantics for internal downstream validation.
modelContextSemantics :: SemanticallyValidModel -> ContextSemantics
modelContextSemantics (SemanticallyValidModel context _) = context

-- | Access complete Strategy formulations indexed by Strategy Context.
strategyFormulations ::
     SemanticallyValidModel -> Map RawNodeId StrategyFormulation
strategyFormulations (SemanticallyValidModel context _) =
  contextStrategyFormulations context

-- | Access validated collective Strategy realizations.
validatedCollectiveStrategyRealizations ::
     SemanticallyValidModel -> ValidatedCollectiveStrategyRealizations
validatedCollectiveStrategyRealizations (SemanticallyValidModel _ collective) =
  collective

-- | Resolve a raw identifier as a typed Context in a semantic model.
lookupSemanticContextRef ::
     SemanticallyValidModel
  -> SContext context
  -> RawNodeId
  -> Maybe (ContextRef context)
lookupSemanticContextRef (SemanticallyValidModel context _) =
  lookupContextSemanticsRef context

-- | Find Strategies that qualify one situated Need.
qualifyingStrategies ::
     SemanticallyValidModel -> ContextRef 'Need -> [ContextRef 'Strategy]
qualifyingStrategies (SemanticallyValidModel context _) =
  qualifyingStrategiesInContext context

deriveMaturity :: Map RawNodeId Elaboration -> ModelAssessmentStatus -> Maturity
deriveMaturity elaborations status =
  case status of
    SemanticsAccepted _ -> SemanticallyValid
    SemanticsRejected _
      | Elaborated `elem` Map.elems elaborations -> Draft
      | otherwise -> Skeleton
    SemanticsPending _
      | Elaborated `elem` Map.elems elaborations -> Draft
      | otherwise -> Skeleton

contextCandidate :: CandidateContextProposition -> CandidateModelProposition
contextCandidate candidate =
  case candidate of
    CandidateContextNode node -> CandidateModelNode node
    CandidateContextEdge edge -> CandidateModelEdge edge
    CandidateContextStrategyFormulation strategy ->
      CandidateStrategyFormulation strategy

collectiveCandidate ::
     CandidateCollectiveStrategyRealization -> CandidateModelProposition
collectiveCandidate =
  CandidateCollectiveRealization
    . rawRealizationId
    . claimedProposition
    . candidateCollectiveClaim
