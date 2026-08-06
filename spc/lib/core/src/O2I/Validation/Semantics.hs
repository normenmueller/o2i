{-# LANGUAGE DataKinds #-}

-- | Complete semantic assessment of one O2I model boundary.
--
-- Context content, asserted macrorelation evidence, and collective Strategy
-- realization are assessed as one normative unit. Model maturity is derived
-- exactly once from this complete boundary.
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
  , MacroEvidenceWitness
  , macroEvidenceWitnesses
  , witnessPremises
  , assessModelSemantics
  , modelAssessmentStatus
  , assessedSemanticModel
  , assessmentInvariantErrors
  , assessmentCollectiveErrors
  , assessmentCollectiveContributionErrors
  , assessmentCollectiveRegistryPreparationWork
  , assessmentCollectiveContributionPreparationWork
  , assessmentCollectiveContributionWork
  , assessmentCandidatePropositions
  , assessmentCandidateCollectiveStrategyRealizations
  , assessmentValidatedCollectiveStrategyRealizations
  , assessmentCandidateCollectiveStrategyContributions
  , assessmentValidatedCollectiveStrategyContributions
  , contextElaboration
  , modelMaturity
  , modelGraph
  , modelContextSemantics
  , modelPreparedMacroEvidence
  , strategyFormulations
  , strategyFormulationData
  , validatedCollectiveStrategyRealizations
  , validatedCollectiveStrategyContributions
  , lookupSemanticContextRef
  , qualifyingStrategies
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Validation (Validation(..))
import O2I.Graph.Raw (RawEdge, RawNode)
import O2I.Graph.Typed
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Language.Macro (MacroClaim)
import O2I.Validation.Collective
import O2I.Validation.Collective.Contribution
import O2I.Validation.Collective.Contribution.Eval
  ( candidateCollectiveStrategyContributions
  , collectiveStrategyContributionErrors
  )
import O2I.Validation.Collective.Registry
import O2I.Validation.Collective.Registry.Internal
import O2I.Validation.MacroEvidence
import qualified O2I.Validation.MacroEvidence as Evidence
import O2I.Validation.Semantics.Context
import O2I.Validation.Structure (StructuralAssessment)

-- * Complete model assessment state
-- | Derived semantic maturity of one complete assessed model boundary.
data Maturity
  = Skeleton
    -- ^ No Context in scope has a complete validated content bundle.
  | Draft
    -- ^ Some content is elaborated while unresolved or invalid claims remain.
  | SemanticallyValid
    -- ^ The complete semantic boundary is valid and contains no Candidate.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- * Complete semantic input
-- | Complete raw input to one normative semantic assessment.
data ModelSemanticsInput = ModelSemanticsInput
  { modelStrategyClaims :: [Claim RawStrategyFormulation]
    -- ^ Strategy content claims in source order.
  , modelCollectiveClaims :: [RawCollectiveFanInClaim]
    -- ^ Typed collective fan-in claims in source order.
  , modelCollectiveEvidence :: [RawCollectiveFanInEvidence]
    -- ^ Family-owned evidence bundles in source order.
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
  | CandidateCollectiveProposition PropositionFamily ClaimId
    -- ^ Structurally admissible proposed collective fan-in proposition.
  deriving (Eq, Show)

-- | Fatal semantic defect from one part of the complete assessment boundary.
data ModelSemanticError
  = ContextSemanticError ModelInvariantError
  | MacroEvidenceSemanticError MacroEvidenceError
  | CollectiveSemanticError CollectiveRegistryError
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
  , assessedCollectiveRegistry :: CollectiveRegistryAssessment
  , assessedCandidates :: [CandidateModelProposition]
  , assessedStatus :: ModelAssessmentStatus
  , assessedMaturity :: Maturity
  }

-- | Opaque model whose Context invariants, asserted macrorelation evidence,
-- and collective Strategy-realization semantics are valid.
data SemanticallyValidModel =
  SemanticallyValidModel
    ContextSemantics
    PreparedMacroEvidence
    ValidatedCollectiveRegistry

-- * Complete semantic validation interface
-- | Assess all semantic claims within one exact structural boundary.
--
-- Fatal errors dominate pending Candidates without discarding Candidate
-- diagnostics. Macrorelation evidence and collective semantics are assessed
-- only after Context semantics has established the required graph and
-- Strategy-formulation invariants.
assessModelSemantics ::
     StructuralAssessment -> ModelSemanticsInput -> ModelAssessment
-- * Complete semantic validation implementation
assessModelSemantics structure inputs =
  ModelAssessment
    { assessedContext = contextAssessment
    , assessedCollectiveRegistry = registryAssessment
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
    preparedRegistry =
      prepareCollectiveRegistry
        structure
        (modelCollectiveClaims inputs)
        (modelCollectiveEvidence inputs)
    (registryAssessment, candidates, status) =
      case contextAssessmentStatus contextAssessment of
        ContextRejected errors ->
          let registry = blockCollectiveRegistry preparedRegistry
              registryCandidates =
                map registryCandidate (collectiveRegistryCandidates registry)
           in ( registry
              , contextCandidates ++ registryCandidates
              , SemanticsRejected
                  (appendNonEmpty
                     (fmap ContextSemanticError errors)
                     (map
                        CollectiveSemanticError
                        (collectiveRegistryErrors registry))))
        ContextPending context pendingContexts ->
          let prepared = prepareMacroEvidence context
              evaluated =
                assessCollectiveRegistry context prepared preparedRegistry
              registry = evaluatedCollectiveRegistryAssessment evaluated
              semanticValidation = validateSemanticBoundary prepared evaluated
              pending =
                appendNonEmpty
                  (fmap contextCandidate pendingContexts)
                  (map registryCandidate (collectiveRegistryCandidates registry))
              pendingCandidates = NonEmpty.toList pending
           in case semanticValidation of
                Failure errors ->
                  (registry, pendingCandidates, SemanticsRejected errors)
                Success _ ->
                  (registry, pendingCandidates, SemanticsPending pending)
        ContextAccepted context ->
          let prepared = prepareMacroEvidence context
              evaluated =
                assessCollectiveRegistry context prepared preparedRegistry
              registry = evaluatedCollectiveRegistryAssessment evaluated
              semanticValidation = validateSemanticBoundary prepared evaluated
              pendingCandidates =
                map registryCandidate (collectiveRegistryCandidates registry)
           in case semanticValidation of
                Failure errors ->
                  (registry, pendingCandidates, SemanticsRejected errors)
                Success (validatedPrepared, validatedRegistry) ->
                  case NonEmpty.nonEmpty pendingCandidates of
                    Just pending ->
                      (registry, pendingCandidates, SemanticsPending pending)
                    Nothing ->
                      ( registry
                      , []
                      , SemanticsAccepted
                          (SemanticallyValidModel
                             context
                             validatedPrepared
                             validatedRegistry))

validateSemanticBoundary ::
     PreparedMacroEvidence
  -> EvaluatedCollectiveRegistry
  -> Validation
       (NonEmpty ModelSemanticError)
       (PreparedMacroEvidence, ValidatedCollectiveRegistry)
validateSemanticBoundary prepared registry =
  (,) <$> macroValidation <*> registryValidation
  where
    macroValidation =
      case validatePreparedMacroEvidence prepared of
        Failure errors -> Failure (fmap MacroEvidenceSemanticError errors)
        Success validated -> Success validated
    registryValidation =
      case validateCollectiveRegistry registry of
        Failure errors -> Failure (fmap CollectiveSemanticError errors)
        Success validated -> Success validated

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
  collectiveStrategyRealizationErrors
    . registryRealizationAssessment
    . assessedCollectiveRegistry

-- | Read failed collective Strategy-contribution invariants.
assessmentCollectiveContributionErrors ::
     ModelAssessment -> [CollectiveStrategyContributionError]
assessmentCollectiveContributionErrors assessment =
  collectiveStrategyContributionErrors
    (registryContributionAssessment (assessedCollectiveRegistry assessment))

-- | Read exact once-only routing work for the complete collective registry.
assessmentCollectiveRegistryPreparationWork ::
     ModelAssessment -> CollectiveRegistryPreparationWork
assessmentCollectiveRegistryPreparationWork =
  collectiveRegistryPreparationWork . assessedCollectiveRegistry

-- | Read exact one-time contribution index preparation work.
assessmentCollectiveContributionPreparationWork ::
     ModelAssessment -> Maybe CollectiveContributionPreparationWork
assessmentCollectiveContributionPreparationWork =
  registryContributionPreparationWork . assessedCollectiveRegistry

-- | Read exact contribution-validation work when Context semantics existed.
assessmentCollectiveContributionWork ::
     ModelAssessment -> Maybe CollectiveContributionValidationWork
assessmentCollectiveContributionWork =
  registryContributionWork . assessedCollectiveRegistry

-- | Read every Candidate excluded from validated model semantics.
assessmentCandidatePropositions ::
     ModelAssessment -> [CandidateModelProposition]
assessmentCandidatePropositions = assessedCandidates

-- | Read detailed collective Candidate assessments retained for diagnostics.
assessmentCandidateCollectiveStrategyRealizations ::
     ModelAssessment -> [CandidateCollectiveStrategyRealization]
assessmentCandidateCollectiveStrategyRealizations =
  candidateCollectiveStrategyRealizations
    . registryRealizationAssessment
    . assessedCollectiveRegistry

-- | Read validated collective realizations available within this assessment.
--
-- A pending Candidate does not invalidate independent Asserted realizations.
-- Fatal collective errors prevent aggregate witness projection.
assessmentValidatedCollectiveStrategyRealizations ::
     ModelAssessment -> Maybe ValidatedCollectiveStrategyRealizations
assessmentValidatedCollectiveStrategyRealizations =
  registryValidatedRealizations . assessedCollectiveRegistry

-- | Read detailed collective-contribution Candidates retained for diagnostics.
assessmentCandidateCollectiveStrategyContributions ::
     ModelAssessment -> [CandidateCollectiveStrategyContribution]
assessmentCandidateCollectiveStrategyContributions assessment =
  candidateCollectiveStrategyContributions
    (registryContributionAssessment (assessedCollectiveRegistry assessment))

-- | Read validated collective contributions available within this assessment.
assessmentValidatedCollectiveStrategyContributions ::
     ModelAssessment -> Maybe ValidatedCollectiveStrategyContributions
assessmentValidatedCollectiveStrategyContributions =
  registryValidatedContributions . assessedCollectiveRegistry

-- | Read one Context's elaboration from the complete assessment boundary.
contextElaboration :: ModelAssessment -> RawNodeId -> Maybe Elaboration
contextElaboration = contextAssessmentElaboration . assessedContext

-- | Read the maturity derived exactly once for this complete boundary.
modelMaturity :: ModelAssessment -> Maturity
modelMaturity = assessedMaturity

-- | Access the structurally valid graph underlying complete semantics.
modelGraph :: SemanticallyValidModel -> WellFormedGraph
modelGraph (SemanticallyValidModel context _ _) = contextGraph context

-- | Project Context semantics for internal downstream validation.
modelContextSemantics :: SemanticallyValidModel -> ContextSemantics
modelContextSemantics (SemanticallyValidModel context _ _) = context

-- | Reuse the exact validated macro evidence of this semantic model.
modelPreparedMacroEvidence :: SemanticallyValidModel -> PreparedMacroEvidence
modelPreparedMacroEvidence (SemanticallyValidModel _ prepared _) = prepared

-- | Interpret one canonical macro rule against validated model evidence.
macroEvidenceWitnesses ::
     SemanticallyValidModel -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnesses semantic =
  Evidence.macroEvidenceWitnessesIn (modelPreparedMacroEvidence semantic)

-- | Access complete Strategy formulations indexed by Strategy Context.
strategyFormulations ::
     SemanticallyValidModel -> Map RawNodeId StrategyFormulation
strategyFormulations (SemanticallyValidModel context _ _) =
  contextStrategyFormulations context

-- | Access validated collective Strategy realizations.
validatedCollectiveStrategyRealizations ::
     SemanticallyValidModel -> ValidatedCollectiveStrategyRealizations
validatedCollectiveStrategyRealizations (SemanticallyValidModel _ _ registry) =
  validatedRegistryRealizations registry

-- | Access validated collective Strategy contributions.
validatedCollectiveStrategyContributions ::
     SemanticallyValidModel -> ValidatedCollectiveStrategyContributions
validatedCollectiveStrategyContributions (SemanticallyValidModel _ _ registry) =
  validatedRegistryContributions registry

-- | Resolve a raw identifier as a typed Context in a semantic model.
lookupSemanticContextRef ::
     SemanticallyValidModel
  -> SContext context
  -> RawNodeId
  -> Maybe (ContextRef context)
lookupSemanticContextRef (SemanticallyValidModel context _ _) =
  lookupContextSemanticsRef context

-- | Find Strategies that qualify one situated Need.
qualifyingStrategies ::
     SemanticallyValidModel -> ContextRef 'Need -> [ContextRef 'Strategy]
qualifyingStrategies (SemanticallyValidModel context _ _) =
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

registryCandidate :: CollectiveRegistryCandidate -> CandidateModelProposition
registryCandidate candidate =
  CandidateCollectiveProposition
    (registryCandidateFamily candidate)
    (registryCandidateId candidate)

appendNonEmpty :: NonEmpty value -> [value] -> NonEmpty value
appendNonEmpty (first :| rest) suffix = first :| (rest ++ suffix)
