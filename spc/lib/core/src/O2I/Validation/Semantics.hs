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

import Data.List (group, sort)
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
  ( CollectiveContributionClaimStructureAssessment
  , CollectiveStrategyContributionAssessment
  , assessCollectiveContributionClaimStructure
  , assessCollectiveStrategyContributions
  , blockedCollectiveStrategyContributionAssessment
  , candidateCollectiveStrategyContributions
  , collectiveStrategyContributionErrors
  , contributionAssessmentPreparationWork
  , contributionAssessmentWork
  , validateCollectiveStrategyContributions
  )
import O2I.Validation.Collective.Contribution.Index
  ( prepareCollectiveContribution
  )
import O2I.Validation.Collective.Registry
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
  | CandidateCollectiveRealization ClaimId
    -- ^ Structurally admissible proposed collective Strategy realization.
  | CandidateCollectiveContribution ClaimId
    -- ^ Structurally admissible proposed collective Strategy contribution.
  deriving (Eq, Show)

-- | Fatal semantic defect from one part of the complete assessment boundary.
data ModelSemanticError
  = ContextSemanticError ModelInvariantError
  | MacroEvidenceSemanticError MacroEvidenceError
  | CollectiveSemanticError CollectiveStrategyRealizationError
  | CollectiveContributionSemanticError CollectiveStrategyContributionError
  | DuplicateCollectiveFanInClaimId ClaimId
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
  , assessedCollective :: CollectiveStrategyRealizationAssessment
  , assessedCollectiveValidation :: Maybe
      ValidatedCollectiveStrategyRealizations
  , assessedContribution :: Maybe CollectiveStrategyContributionAssessment
  , assessedContributionValidation :: Maybe
      ValidatedCollectiveStrategyContributions
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
    ValidatedCollectiveStrategyRealizations
    ValidatedCollectiveStrategyContributions

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
    , assessedCollective = collectiveAssessment
    , assessedCollectiveValidation = collectiveValidation
    , assessedContribution = contributionAssessment
    , assessedContributionValidation = contributionValidation
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
    collectiveStructure =
      assessCollectiveClaimStructure structure realizationClaims
    blockedCollective =
      blockedCollectiveStrategyRealizationAssessment collectiveStructure
    contributionStructure =
      assessCollectiveContributionClaimStructure structure contributionClaims
    blockedContribution =
      blockedCollectiveStrategyContributionAssessment contributionStructure
    (collectiveAssessment, collectiveValidation, contributionAssessment, contributionValidation, candidates, status) =
      case contextAssessmentStatus contextAssessment of
        ContextRejected errors ->
          ( blockedCollective
          , Nothing
          , Just blockedContribution
          , Nothing
          , contextCandidates
              ++ collectiveCandidates blockedCollective
              ++ contributionCandidates blockedContribution
          , SemanticsRejected
              (appendNonEmpty
                 (fmap ContextSemanticError errors)
                 (map DuplicateCollectiveFanInClaimId duplicateFamilyIds
                    ++ map
                         CollectiveSemanticError
                         (collectiveStrategyRealizationErrors blockedCollective)
                    ++ map
                         CollectiveContributionSemanticError
                         (collectiveStrategyContributionErrors
                            blockedContribution))))
        ContextPending context pendingContexts ->
          let (prepared, assessment) =
                assessCollectiveWithPreparedMacroEvidence
                  inputs
                  collectiveStructure
                  context
              contribution =
                assessContributionWithPrepared
                  structure
                  inputs
                  contributionStructure
                  context
                  prepared
              (validatedCollective, validatedContribution, semanticValidation) =
                validateSemanticBoundary
                  duplicateFamilyIds
                  prepared
                  assessment
                  contribution
              pending =
                appendNonEmpty
                  (fmap contextCandidate pendingContexts)
                  (collectiveCandidates assessment
                     ++ contributionCandidates contribution)
              pendingCandidates = NonEmpty.toList pending
           in case semanticValidation of
                Failure errors ->
                  ( assessment
                  , validatedCollective
                  , Just contribution
                  , validatedContribution
                  , pendingCandidates
                  , SemanticsRejected errors)
                Success (_, validated, validatedContributions) ->
                  ( assessment
                  , Just validated
                  , Just contribution
                  , Just validatedContributions
                  , pendingCandidates
                  , SemanticsPending pending)
        ContextAccepted context ->
          let (prepared, assessment) =
                assessCollectiveWithPreparedMacroEvidence
                  inputs
                  collectiveStructure
                  context
              contribution =
                assessContributionWithPrepared
                  structure
                  inputs
                  contributionStructure
                  context
                  prepared
              (validatedCollective, validatedContribution, semanticValidation) =
                validateSemanticBoundary
                  duplicateFamilyIds
                  prepared
                  assessment
                  contribution
              pendingCandidates =
                collectiveCandidates assessment
                  ++ contributionCandidates contribution
           in case semanticValidation of
                Failure errors ->
                  ( assessment
                  , validatedCollective
                  , Just contribution
                  , validatedContribution
                  , pendingCandidates
                  , SemanticsRejected errors)
                Success (validatedPrepared, validated, validatedContributions) ->
                  case NonEmpty.nonEmpty pendingCandidates of
                    Just pending ->
                      ( assessment
                      , Just validated
                      , Just contribution
                      , Just validatedContributions
                      , pendingCandidates
                      , SemanticsPending pending)
                    Nothing ->
                      ( assessment
                      , Just validated
                      , Just contribution
                      , Just validatedContributions
                      , []
                      , SemanticsAccepted
                          (SemanticallyValidModel
                             context
                             validatedPrepared
                             validated
                             validatedContributions))
    realizationClaims =
      [ claim
      | CollectiveStrategyRealizationClaim claim <- modelCollectiveClaims inputs
      ]
    contributionClaims =
      [ claim
      | CollectiveStrategyContributionClaim claim <-
          modelCollectiveClaims inputs
      ]
    duplicateFamilyIds =
      duplicates (map collectiveFanInClaimId (modelCollectiveClaims inputs))

assessCollectiveWithPreparedMacroEvidence ::
     ModelSemanticsInput
  -> CollectiveClaimStructureAssessment
  -> ContextSemantics
  -> (PreparedMacroEvidence, CollectiveStrategyRealizationAssessment)
assessCollectiveWithPreparedMacroEvidence inputs structure context =
  (prepared, assessment)
  where
    prepared = prepareMacroEvidence context
    assessment =
      assessCollectiveStrategyRealizations
        context
        (collectiveMacroEvidenceFor prepared)
        [ evidence
        | CollectiveStrategyRealizationEvidence evidence <-
            modelCollectiveEvidence inputs
        ]
        structure

assessContributionWithPrepared ::
     StructuralAssessment
  -> ModelSemanticsInput
  -> CollectiveContributionClaimStructureAssessment
  -> ContextSemantics
  -> PreparedMacroEvidence
  -> CollectiveStrategyContributionAssessment
assessContributionWithPrepared structural inputs contributionStructure context prepared =
  assessCollectiveStrategyContributions
    contributionPreparation
    contributionStructure
  where
    contributionEvidence =
      [ evidence
      | CollectiveStrategyContributionEvidence evidence <-
          modelCollectiveEvidence inputs
      ]
    contributionPreparation =
      prepareCollectiveContribution
        structural
        context
        prepared
        contributionEvidence

validateSemanticBoundary ::
     [ClaimId]
  -> PreparedMacroEvidence
  -> CollectiveStrategyRealizationAssessment
  -> CollectiveStrategyContributionAssessment
  -> ( Maybe ValidatedCollectiveStrategyRealizations
     , Maybe ValidatedCollectiveStrategyContributions
     , Validation
         (NonEmpty ModelSemanticError)
         ( PreparedMacroEvidence
         , ValidatedCollectiveStrategyRealizations
         , ValidatedCollectiveStrategyContributions))
validateSemanticBoundary duplicateIds prepared assessment contribution =
  (validatedCollective, validatedContribution, boundaryValidation)
  where
    boundaryValidation =
      (\_ validatedPrepared realizations contributions ->
         (validatedPrepared, realizations, contributions))
        <$> identityValidation
        <*> macroValidation
        <*> collectiveValidation
        <*> contributionValidation
    identityValidation =
      case NonEmpty.nonEmpty duplicateIds of
        Nothing -> Success ()
        Just identifiers ->
          Failure (fmap DuplicateCollectiveFanInClaimId identifiers)
    macroValidation =
      case validatePreparedMacroEvidence prepared of
        Failure errors -> Failure (fmap MacroEvidenceSemanticError errors)
        Success validated -> Success validated
    rawCollectiveValidation = validateCollectiveStrategyRealizations assessment
    collectiveValidation =
      case rawCollectiveValidation of
        Failure errors -> Failure (fmap CollectiveSemanticError errors)
        Success validated -> Success validated
    rawContributionValidation =
      validateCollectiveStrategyContributions contribution
    contributionValidation =
      case rawContributionValidation of
        Failure errors ->
          Failure (fmap CollectiveContributionSemanticError errors)
        Success validated -> Success validated
    validatedCollective =
      case rawCollectiveValidation of
        Failure _ -> Nothing
        Success validated -> Just validated
    validatedContribution =
      case rawContributionValidation of
        Failure _ -> Nothing
        Success validated -> Just validated

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
  collectiveStrategyRealizationErrors . assessedCollective

-- | Read failed collective Strategy-contribution invariants.
assessmentCollectiveContributionErrors ::
     ModelAssessment -> [CollectiveStrategyContributionError]
assessmentCollectiveContributionErrors assessment =
  maybe
    []
    collectiveStrategyContributionErrors
    (assessedContribution assessment)

-- | Read exact one-time contribution index preparation work.
assessmentCollectiveContributionPreparationWork ::
     ModelAssessment -> Maybe CollectiveContributionPreparationWork
assessmentCollectiveContributionPreparationWork =
  fmap contributionAssessmentPreparationWork . assessedContribution

-- | Read exact contribution-validation work when Context semantics existed.
assessmentCollectiveContributionWork ::
     ModelAssessment -> Maybe CollectiveContributionValidationWork
assessmentCollectiveContributionWork =
  fmap contributionAssessmentWork . assessedContribution

-- | Read every Candidate excluded from validated model semantics.
assessmentCandidatePropositions ::
     ModelAssessment -> [CandidateModelProposition]
assessmentCandidatePropositions = assessedCandidates

-- | Read detailed collective Candidate assessments retained for diagnostics.
assessmentCandidateCollectiveStrategyRealizations ::
     ModelAssessment -> [CandidateCollectiveStrategyRealization]
assessmentCandidateCollectiveStrategyRealizations =
  candidateCollectiveStrategyRealizations . assessedCollective

-- | Read validated collective realizations available within this assessment.
--
-- A pending Candidate does not invalidate independent Asserted realizations.
-- Fatal collective errors prevent aggregate witness projection.
assessmentValidatedCollectiveStrategyRealizations ::
     ModelAssessment -> Maybe ValidatedCollectiveStrategyRealizations
assessmentValidatedCollectiveStrategyRealizations = assessedCollectiveValidation

-- | Read detailed collective-contribution Candidates retained for diagnostics.
assessmentCandidateCollectiveStrategyContributions ::
     ModelAssessment -> [CandidateCollectiveStrategyContribution]
assessmentCandidateCollectiveStrategyContributions assessment =
  maybe
    []
    candidateCollectiveStrategyContributions
    (assessedContribution assessment)

-- | Read validated collective contributions available within this assessment.
assessmentValidatedCollectiveStrategyContributions ::
     ModelAssessment -> Maybe ValidatedCollectiveStrategyContributions
assessmentValidatedCollectiveStrategyContributions =
  assessedContributionValidation

-- | Read one Context's elaboration from the complete assessment boundary.
contextElaboration :: ModelAssessment -> RawNodeId -> Maybe Elaboration
contextElaboration = contextAssessmentElaboration . assessedContext

-- | Read the maturity derived exactly once for this complete boundary.
modelMaturity :: ModelAssessment -> Maturity
modelMaturity = assessedMaturity

-- | Access the structurally valid graph underlying complete semantics.
modelGraph :: SemanticallyValidModel -> WellFormedGraph
modelGraph (SemanticallyValidModel context _ _ _) = contextGraph context

-- | Project Context semantics for internal downstream validation.
modelContextSemantics :: SemanticallyValidModel -> ContextSemantics
modelContextSemantics (SemanticallyValidModel context _ _ _) = context

-- | Reuse the exact validated macro evidence of this semantic model.
modelPreparedMacroEvidence :: SemanticallyValidModel -> PreparedMacroEvidence
modelPreparedMacroEvidence (SemanticallyValidModel _ prepared _ _) = prepared

-- | Interpret one canonical macro rule against validated model evidence.
macroEvidenceWitnesses ::
     SemanticallyValidModel -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnesses semantic =
  Evidence.macroEvidenceWitnessesIn (modelPreparedMacroEvidence semantic)

-- | Access complete Strategy formulations indexed by Strategy Context.
strategyFormulations ::
     SemanticallyValidModel -> Map RawNodeId StrategyFormulation
strategyFormulations (SemanticallyValidModel context _ _ _) =
  contextStrategyFormulations context

-- | Access validated collective Strategy realizations.
validatedCollectiveStrategyRealizations ::
     SemanticallyValidModel -> ValidatedCollectiveStrategyRealizations
validatedCollectiveStrategyRealizations (SemanticallyValidModel _ _ collective _) =
  collective

-- | Access validated collective Strategy contributions.
validatedCollectiveStrategyContributions ::
     SemanticallyValidModel -> ValidatedCollectiveStrategyContributions
validatedCollectiveStrategyContributions (SemanticallyValidModel _ _ _ contributions) =
  contributions

-- | Resolve a raw identifier as a typed Context in a semantic model.
lookupSemanticContextRef ::
     SemanticallyValidModel
  -> SContext context
  -> RawNodeId
  -> Maybe (ContextRef context)
lookupSemanticContextRef (SemanticallyValidModel context _ _ _) =
  lookupContextSemanticsRef context

-- | Find Strategies that qualify one situated Need.
qualifyingStrategies ::
     SemanticallyValidModel -> ContextRef 'Need -> [ContextRef 'Strategy]
qualifyingStrategies (SemanticallyValidModel context _ _ _) =
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

collectiveCandidates ::
     CollectiveStrategyRealizationAssessment -> [CandidateModelProposition]
collectiveCandidates =
  map collectiveCandidate . candidateCollectiveStrategyRealizations

contributionCandidate ::
     CandidateCollectiveStrategyContribution -> CandidateModelProposition
contributionCandidate =
  CandidateCollectiveContribution
    . rawContributionId
    . claimedProposition
    . candidateCollectiveContributionClaim

contributionCandidates ::
     CollectiveStrategyContributionAssessment -> [CandidateModelProposition]
contributionCandidates =
  map contributionCandidate . candidateCollectiveStrategyContributions

duplicates :: Ord value => [value] -> [value]
duplicates = map head . filter ((> 1) . length) . group . sort

appendNonEmpty :: NonEmpty value -> [value] -> NonEmpty value
appendNonEmpty (first :| rest) suffix = first :| (rest ++ suffix)
