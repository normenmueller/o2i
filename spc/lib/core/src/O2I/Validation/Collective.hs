{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Notation-independent collective realization of one Strategy.
module O2I.Validation.Collective
  ( ClaimId(..)
  , CollectiveFitEvidenceRef(..)
  , RawMutualCoherenceEvidence(..)
  , RawContributorCompatibilityEvidence(..)
  , RawCollectiveFitEvidence(..)
  , RawCollectiveStrategyRealization(..)
  , CollectiveParticipantRole(..)
  , CollectiveFitDimension(..)
  , CollectiveStrategyRealizationIssue(..)
  , CollectiveStrategyRealizationStructuralError(..)
  , CollectiveStrategyRealizationError(..)
  , CollectiveStrategyRealization
  , CandidateCollectiveStrategyRealization
  , CollectiveStrategyRealizationAssessment
  , ValidatedCollectiveStrategyRealizations
  , assessCollectiveStrategyRealizations
  , collectiveStrategyRealizationErrors
  , validateCollectiveStrategyRealizations
  , collectiveStrategyRealizations
  , candidateCollectiveStrategyRealizations
  , lookupCollectiveStrategyRealization
  , collectiveRealizationsForTarget
  , collectiveRealizationId
  , collectiveContributors
  , collectiveTarget
  , collectiveFitEvidenceReference
  , collectiveContributionEvidence
  , candidateCollectiveClaim
  , candidateCollectiveIssues
  ) where

import Data.List (group, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Collective.Fit
import O2I.Validation.Collective.Types
import O2I.Validation.Semantics.Context
import O2I.Validation.Trace.Evidence

-- * Collective Strategy realization input
-- | Stable occurrence identity of one collective claim.
newtype ClaimId = ClaimId
  { claimIdText :: Text
  } deriving (Eq, Ord, Show)

-- | Unchecked collective Strategy-realization proposition.
--
-- Commitment belongs exclusively to the enclosing 'Claim'.
data RawCollectiveStrategyRealization = RawCollectiveStrategyRealization
  { rawRealizationId :: ClaimId
  , rawContributors :: [RawNodeId]
  , rawTarget :: RawNodeId
  , rawCollectiveFitEvidence :: CollectiveFitEvidenceRef
  } deriving (Eq, Show)

-- | Participant position used by precise typing diagnostics.
data CollectiveParticipantRole
  = CollectiveContributor
  | CollectiveTarget
  deriving (Eq, Ord, Show)

-- * Collective Strategy realization validation vocabulary
-- | Fatal structural defect of a collective proposition.
--
-- Structural validity is independent of commitment: Candidate and Asserted
-- claims must satisfy the same identity, topology, and participant contracts.
data CollectiveStrategyRealizationStructuralError
  = EmptyCollectiveRealizationClaimId
  | DuplicateCollectiveRealizationClaimId ClaimId
  | EmptyCollectiveFitEvidenceReference ClaimId
  | TooFewCollectiveContributors ClaimId
  | DuplicateCollectiveContributor ClaimId RawNodeId
  | CollectiveContributorIsTarget ClaimId RawNodeId
  | UnknownCollectiveParticipant ClaimId CollectiveParticipantRole RawNodeId
  | NonStrategyCollectiveParticipant
      ClaimId
      CollectiveParticipantRole
      RawNodeId
      NodeKindValue
  deriving (Eq, Show)

-- | Fatal structural defect or Asserted semantic deficiency.
--
-- A structurally valid Candidate is represented in the successful assessment,
-- never as an error. Its semantic issues remain diagnostic information because
-- Candidates cannot construct semantic witnesses.
data CollectiveStrategyRealizationError
  = CollectiveStructuralError CollectiveStrategyRealizationStructuralError
  | AssertedCollectiveIssue ClaimId CollectiveStrategyRealizationIssue
  deriving (Eq, Show)

-- | Internal representation with at least two values by construction.
data AtLeastTwo value =
  AtLeastTwo value value [value]

-- | Opaque validated Asserted collective realization.
data CollectiveStrategyRealization =
  CollectiveStrategyRealization
    ClaimId
    (AtLeastTwo (ContextRef 'Strategy))
    (ContextRef 'Strategy)
    CollectiveFitEvidenceRef
    [(ContextRef 'Strategy, NonEmpty MacroEvidenceWitness)]

-- | Opaque diagnostic assessment of one excluded Candidate claim.
data CandidateCollectiveStrategyRealization =
  CandidateCollectiveStrategyRealization
    (Claim RawCollectiveStrategyRealization)
    [CollectiveStrategyRealizationIssue]

-- | Opaque total assessment of every supplied collective claim.
--
-- Fatal errors, valid per-claim Asserted evaluations, and structurally valid
-- Candidate assessments coexist in source order. Aggregate witnesses are
-- available only through 'validateCollectiveStrategyRealizations'.
data CollectiveStrategyRealizationAssessment =
  CollectiveStrategyRealizationAssessment
    [CollectiveStrategyRealizationError]
    [SemanticEvaluation]
    [CandidateCollectiveStrategyRealization]

-- | Opaque aggregate of collective witnesses admitted as one valid set.
newtype ValidatedCollectiveStrategyRealizations =
  ValidatedCollectiveStrategyRealizations [CollectiveStrategyRealization]

data StructurallyValidCollective =
  StructurallyValidCollective
    (Claim RawCollectiveStrategyRealization)
    (AtLeastTwo (ContextRef 'Strategy))
    (ContextRef 'Strategy)

data SemanticEvaluation =
  SemanticEvaluation
    StructurallyValidCollective
    [CollectiveStrategyRealizationIssue]
    [(ContextRef 'Strategy, Maybe (NonEmpty MacroEvidenceWitness))]

-- * Collective Strategy realization assessment
-- | Assess every collective claim against one exact semantic model.
--
-- Structural defects and Asserted semantic deficiencies accumulate as fatal
-- errors. Independent structurally valid Candidates remain observable with
-- their semantic issues. Candidates never construct validated witnesses.
assessCollectiveStrategyRealizations ::
     ContextSemantics
  -> [RawCollectiveFitEvidence]
  -> [Claim RawCollectiveStrategyRealization]
  -> CollectiveStrategyRealizationAssessment
assessCollectiveStrategyRealizations semantic fitEvidence claims =
  CollectiveStrategyRealizationAssessment
    errors
    evaluations
    (mapMaybe candidateAssessment evaluations)
  where
    evidence = buildMacroEvidenceContext semantic
    identityErrors =
      [ CollectiveStructuralError
        (DuplicateCollectiveRealizationClaimId identifier)
      | identifier <-
          duplicates (map (rawRealizationId . claimedProposition) claims)
      ]
    structuralValidation = validateCollectiveStructure (contextGraph semantic)
    structuralResults = map structuralValidation claims
    structuralErrors =
      concat [NonEmpty.toList failures | Failure failures <- structuralResults]
    structuralClaims = [structural | Success structural <- structuralResults]
    fitIndex = buildCollectiveFitIndex fitEvidence
    evaluations =
      map (evaluateCollective semantic evidence fitIndex) structuralClaims
    errors =
      identityErrors
        ++ structuralErrors
        ++ concatMap evaluationErrors evaluations

-- | Enumerate every fatal error without discarding independent Candidates.
collectiveStrategyRealizationErrors ::
     CollectiveStrategyRealizationAssessment
  -> [CollectiveStrategyRealizationError]
collectiveStrategyRealizationErrors (CollectiveStrategyRealizationAssessment errors _ _) =
  errors

-- | Validate one total assessment as an indivisible aggregate.
--
-- A fatal error prevents all aggregate witness projection. Candidate
-- assessments remain diagnostic-only and cannot construct witnesses.
validateCollectiveStrategyRealizations ::
     CollectiveStrategyRealizationAssessment
  -> Validation
       (NonEmpty CollectiveStrategyRealizationError)
       ValidatedCollectiveStrategyRealizations
validateCollectiveStrategyRealizations assessment =
  case NonEmpty.nonEmpty (collectiveStrategyRealizationErrors assessment) of
    Just failures -> Failure failures
    Nothing ->
      Success
        (ValidatedCollectiveStrategyRealizations
           (mapMaybe assertedWitness (assessedEvaluations assessment)))

assessedEvaluations ::
     CollectiveStrategyRealizationAssessment -> [SemanticEvaluation]
assessedEvaluations (CollectiveStrategyRealizationAssessment _ evaluations _) =
  evaluations

-- | Enumerate validated Asserted collective realizations in source order.
collectiveStrategyRealizations ::
     ValidatedCollectiveStrategyRealizations -> [CollectiveStrategyRealization]
collectiveStrategyRealizations (ValidatedCollectiveStrategyRealizations realizations) =
  realizations

-- | Enumerate excluded Candidate assessments in source order.
candidateCollectiveStrategyRealizations ::
     CollectiveStrategyRealizationAssessment
  -> [CandidateCollectiveStrategyRealization]
candidateCollectiveStrategyRealizations (CollectiveStrategyRealizationAssessment _ _ candidates) =
  candidates

-- | Find one validated collective realization by its unique claim identity.
lookupCollectiveStrategyRealization ::
     ValidatedCollectiveStrategyRealizations
  -> ClaimId
  -> Maybe CollectiveStrategyRealization
lookupCollectiveStrategyRealization assessment identifier =
  findFirst
    ((== identifier) . collectiveRealizationId)
    (collectiveStrategyRealizations assessment)

-- | Find validated collective realizations targeting one Strategy.
collectiveRealizationsForTarget ::
     ValidatedCollectiveStrategyRealizations
  -> ContextRef 'Strategy
  -> [CollectiveStrategyRealization]
collectiveRealizationsForTarget assessment target =
  filter
    ((== target) . collectiveTarget)
    (collectiveStrategyRealizations assessment)

-- | Read the stable identity of a validated collective claim.
collectiveRealizationId :: CollectiveStrategyRealization -> ClaimId
collectiveRealizationId (CollectiveStrategyRealization identifier _ _ _ _) =
  identifier

-- | Read the contributor set, guaranteed to contain at least two members.
collectiveContributors ::
     CollectiveStrategyRealization -> NonEmpty (ContextRef 'Strategy)
collectiveContributors (CollectiveStrategyRealization _ contributors _ _ _) =
  atLeastTwoToNonEmpty contributors

-- | Read the one target Strategy, distinct from every contributor.
collectiveTarget :: CollectiveStrategyRealization -> ContextRef 'Strategy
collectiveTarget (CollectiveStrategyRealization _ _ target _ _) = target

-- | Read the validated structured collective-Fit evidence reference.
collectiveFitEvidenceReference ::
     CollectiveStrategyRealization -> CollectiveFitEvidenceRef
collectiveFitEvidenceReference (CollectiveStrategyRealization _ _ _ evidence _) =
  evidence

-- | Read every contributor's non-empty exact macro-evidence witnesses.
collectiveContributionEvidence ::
     CollectiveStrategyRealization
  -> [(ContextRef 'Strategy, NonEmpty MacroEvidenceWitness)]
collectiveContributionEvidence (CollectiveStrategyRealization _ _ _ _ evidence) =
  evidence

-- | Read the commitment-bearing Candidate claim retained for diagnostics.
candidateCollectiveClaim ::
     CandidateCollectiveStrategyRealization
  -> Claim RawCollectiveStrategyRealization
candidateCollectiveClaim (CandidateCollectiveStrategyRealization claim _) =
  claim

-- | Read semantic issues diagnosed for one excluded Candidate claim.
candidateCollectiveIssues ::
     CandidateCollectiveStrategyRealization
  -> [CollectiveStrategyRealizationIssue]
candidateCollectiveIssues (CandidateCollectiveStrategyRealization _ issues) =
  issues

validateCollectiveStructure ::
     WellFormedGraph
  -> Claim RawCollectiveStrategyRealization
  -> Validation
       (NonEmpty CollectiveStrategyRealizationError)
       StructurallyValidCollective
validateCollectiveStructure graph claim =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure (fmap CollectiveStructuralError failures)
    Nothing ->
      case distinctContributors of
        first:second:rest ->
          Success
            (StructurallyValidCollective
               claim
               (AtLeastTwo
                  (mkContextRef first)
                  (mkContextRef second)
                  (map mkContextRef rest))
               (mkContextRef target))
        _ ->
          Failure
            (CollectiveStructuralError (TooFewCollectiveContributors identifier)
               :| [])
  where
    proposition = claimedProposition claim
    identifier = rawRealizationId proposition
    contributors = rawContributors proposition
    distinctContributors = stableDistinct contributors
    target = rawTarget proposition
    errors =
      [EmptyCollectiveRealizationClaimId | blankClaimId identifier]
        ++ [ EmptyCollectiveFitEvidenceReference identifier
           | blankFitReference (rawCollectiveFitEvidence proposition)
           ]
        ++ [ TooFewCollectiveContributors identifier
           | length distinctContributors < 2
           ]
        ++ [ DuplicateCollectiveContributor identifier contributor
           | contributor <- duplicates contributors
           ]
        ++ [ CollectiveContributorIsTarget identifier target
           | target `elem` distinctContributors
           ]
        ++ concatMap
             (participantErrors graph identifier CollectiveContributor)
             distinctContributors
        ++ participantErrors graph identifier CollectiveTarget target

participantErrors ::
     WellFormedGraph
  -> ClaimId
  -> CollectiveParticipantRole
  -> RawNodeId
  -> [CollectiveStrategyRealizationStructuralError]
participantErrors graph claim role participant =
  case lookupNode graph participant of
    Nothing -> [UnknownCollectiveParticipant claim role participant]
    Just node
      | someNodeKind node == ContextNodeKind Strategy -> []
      | otherwise ->
        [ NonStrategyCollectiveParticipant
            claim
            role
            participant
            (someNodeKind node)
        ]

evaluateCollective ::
     ContextSemantics
  -> MacroEvidenceContext
  -> CollectiveFitIndex
  -> StructurallyValidCollective
  -> SemanticEvaluation
evaluateCollective semantic evidence fitIndex structural =
  SemanticEvaluation structural issues contributionEvidence
  where
    claim = claimedProposition (structurallyValidClaim structural)
    contributors = structurallyValidContributorIds structural
    target = contextRefId (structurallyValidTarget structural)
    contributionEvidence =
      [ ( mkContextRef contributor
        , NonEmpty.nonEmpty
            (macroEvidenceWitnessesForIn
               evidence
               contributor
               (relationCode (relationSpec contributesToStrategy))
               target))
      | contributor <- contributors
      ]
    contributionIssues =
      [ MissingContributorContribution contributor target
      | (contributor, (_, Nothing)) <- zip contributors contributionEvidence
      ]
    witnessPremiseEdges =
      concat
        [ concatMap
          (NonEmpty.toList . witnessPremises)
          (NonEmpty.toList witnesses)
        | (_, Just witnesses) <- contributionEvidence
        ]
    coverageIssues = targetCoverageIssues semantic target witnessPremiseEdges
    fitAssessment =
      assessCollectiveFit
        fitIndex
        contributors
        target
        (collectiveFitTargetExpectation semantic target)
        (rawCollectiveFitEvidence claim)
    fitIssues = collectiveFitAssessmentIssues fitAssessment
    issues = contributionIssues ++ coverageIssues ++ fitIssues

collectiveFitTargetExpectation ::
     ContextSemantics -> RawNodeId -> CollectiveFitTargetExpectation
collectiveFitTargetExpectation semantic target =
  case Map.lookup target (contextStrategyFormulations semantic) of
    Nothing -> MissingCollectiveFitTarget
    Just formulation ->
      ExpectedCollectiveFitTarget
        (rawFormulationGuidingPolicy raw)
        (strategyFormulationTradeOffs formulation)
      where raw = strategyFormulationData formulation

evaluationErrors :: SemanticEvaluation -> [CollectiveStrategyRealizationError]
evaluationErrors (SemanticEvaluation structural issues _)
  | claimCommitment claim == Asserted =
    map
      (AssertedCollectiveIssue (rawRealizationId (claimedProposition claim)))
      issues
  | otherwise = []
  where
    claim = structurallyValidClaim structural

assertedWitness :: SemanticEvaluation -> Maybe CollectiveStrategyRealization
assertedWitness (SemanticEvaluation structural issues evidence)
  | claimCommitment claim == Asserted
  , null issues
  , Just validatedEvidence <- traverse requireEvidence evidence =
    Just
      (CollectiveStrategyRealization
         (rawRealizationId proposition)
         (structurallyValidContributors structural)
         (structurallyValidTarget structural)
         (rawCollectiveFitEvidence proposition)
         validatedEvidence)
  | otherwise = Nothing
  where
    claim = structurallyValidClaim structural
    proposition = claimedProposition claim
    requireEvidence (contributor, Just witnesses) =
      Just (contributor, witnesses)
    requireEvidence (_, Nothing) = Nothing

candidateAssessment ::
     SemanticEvaluation -> Maybe CandidateCollectiveStrategyRealization
candidateAssessment (SemanticEvaluation structural issues _)
  | claimCommitment claim == Candidate =
    Just (CandidateCollectiveStrategyRealization claim issues)
  | otherwise = Nothing
  where
    claim = structurallyValidClaim structural

targetCoverageIssues ::
     ContextSemantics
  -> RawNodeId
  -> [RawEdge]
  -> [CollectiveStrategyRealizationIssue]
targetCoverageIssues semantic target premises =
  case Map.lookup target (contextStrategyFormulations semantic) of
    Nothing -> [MissingTargetStrategyFormulation target]
    Just formulation ->
      [ UncoveredTargetKeyResult keyResult
      | keyResult <- NonEmpty.toList (rawFormulationKeyResults raw)
      , not
          (coveredBy contributesStrategyKeyResultToKeyResult keyResult premises)
      ]
        ++ [ UncoveredTargetAction action
           | action <- NonEmpty.toList (rawFormulationActions raw)
           , not (coveredBy contributesStrategyActionToAction action premises)
           ]
      where raw = strategyFormulationData formulation

coveredBy :: Relation from to -> RawNodeId -> [RawEdge] -> Bool
coveredBy relation target =
  any
    (\edge ->
       rawEdgeRelation edge == relationNameFor relation
         && rawEdgeTo edge == target)

structurallyValidClaim ::
     StructurallyValidCollective -> Claim RawCollectiveStrategyRealization
structurallyValidClaim (StructurallyValidCollective claim _ _) = claim

structurallyValidContributors ::
     StructurallyValidCollective -> AtLeastTwo (ContextRef 'Strategy)
structurallyValidContributors (StructurallyValidCollective _ contributors _) =
  contributors

structurallyValidContributorIds :: StructurallyValidCollective -> [RawNodeId]
structurallyValidContributorIds =
  map contextRefId
    . NonEmpty.toList
    . atLeastTwoToNonEmpty
    . structurallyValidContributors

structurallyValidTarget :: StructurallyValidCollective -> ContextRef 'Strategy
structurallyValidTarget (StructurallyValidCollective _ _ target) = target

atLeastTwoToNonEmpty :: AtLeastTwo value -> NonEmpty value
atLeastTwoToNonEmpty (AtLeastTwo first second rest) = first :| (second : rest)

duplicates :: Ord value => [value] -> [value]
duplicates = map head . filter ((> 1) . length) . group . sort

stableDistinct :: Eq value => [value] -> [value]
stableDistinct = foldl add []
  where
    add values value
      | value `elem` values = values
      | otherwise = values ++ [value]

blankClaimId :: ClaimId -> Bool
blankClaimId = Text.null . Text.strip . claimIdText

blankFitReference :: CollectiveFitEvidenceRef -> Bool
blankFitReference = Text.null . Text.strip . collectiveFitEvidenceRefText

findFirst :: (value -> Bool) -> [value] -> Maybe value
findFirst _ [] = Nothing
findFirst predicate (value:values)
  | predicate value = Just value
  | otherwise = findFirst predicate values
