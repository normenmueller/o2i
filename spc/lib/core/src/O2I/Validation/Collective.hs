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
  , CollectiveClaimStructureAssessment
  , CollectiveStrategyRealizationAssessment
  , ValidatedCollectiveStrategyRealizations
  , assessCollectiveClaimStructure
  , blockedCollectiveStrategyRealizationAssessment
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

import Data.Either (partitionEithers)
import Data.List (group, sort)
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Validation (Validation(..))
import O2I.Graph.Raw
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Collective.Fit
import O2I.Validation.Collective.Types
import O2I.Validation.MacroEvidence.Types
import O2I.Validation.Semantics.Context
import O2I.Validation.Structure.Internal

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

-- * Collective Strategy realization validation vocabulary
-- | Fatal structural defect of a collective proposition.
--
-- Candidate and Asserted claims satisfy the same identity, topology, and
-- participant typing contracts. An Asserted claim additionally requires every
-- participant declaration to be Asserted.
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
  | AssertedCollectiveDependsOnCandidate
      ClaimId
      CollectiveParticipantRole
      RawNodeId
    -- ^ An Asserted collective claim references a Candidate Strategy.
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

-- | Opaque context-independent structural assessment of collective claims.
--
-- Structurally valid claims remain available for semantic evaluation or
-- blocked Candidate diagnostics. No contribution, coverage, or Fit obligation
-- is evaluated at this stage. Candidate claims may retain Candidate or Asserted
-- Strategy participants without constructing semantic references.
data CollectiveClaimStructureAssessment =
  CollectiveClaimStructureAssessment
    [CollectiveStrategyRealizationError]
    [StructurallyValidCollective]

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
    (AtLeastTwo StructuralStrategyParticipant)
    StructuralStrategyParticipant

-- | Structurally accepted Strategy declaration with retained commitment.
--
-- This assessment-only representation is not a semantic witness. It can be
-- lifted to a 'ContextRef' only when its commitment is Asserted.
data StructuralStrategyParticipant =
  StructuralStrategyParticipant RawNodeId Commitment

data SemanticEvaluation =
  SemanticEvaluation
    StructurallyValidCollective
    [CollectiveStrategyRealizationIssue]
    [(StructuralStrategyParticipant, Maybe (NonEmpty MacroEvidenceWitness))]

-- * Collective Strategy realization assessment
-- | Capture every collective claim against the structurally valid graph.
--
-- Identity, topology, and participant typing are independent of Context
-- semantic completeness and therefore remain diagnosable when Context
-- semantics is unavailable. Resolution uses the private commitment-aware
-- structural declaration index rather than the Asserted-only graph.
assessCollectiveClaimStructure ::
     StructuralAssessment
  -> [Claim RawCollectiveStrategyRealization]
  -> CollectiveClaimStructureAssessment
assessCollectiveClaimStructure structure claims =
  CollectiveClaimStructureAssessment errors structuralClaims
  where
    identityErrors =
      [ CollectiveStructuralError
        (DuplicateCollectiveRealizationClaimId identifier)
      | identifier <-
          duplicates (map (rawRealizationId . claimedProposition) claims)
      ]
    structuralResults = map (validateCollectiveStructure structure) claims
    structuralErrors =
      concat [NonEmpty.toList failures | Failure failures <- structuralResults]
    structuralClaims = [structural | Success structural <- structuralResults]
    errors = identityErrors ++ structuralErrors

-- | Retain structurally valid Candidates when Context semantics blocks their
-- semantic assessment.
--
-- Structurally valid Asserted claims remain unevaluated and construct no
-- witness. Structural defects remain fatal and available through the ordinary
-- collective-error accessor.
blockedCollectiveStrategyRealizationAssessment ::
     CollectiveClaimStructureAssessment
  -> CollectiveStrategyRealizationAssessment
blockedCollectiveStrategyRealizationAssessment (CollectiveClaimStructureAssessment errors structuralClaims) =
  CollectiveStrategyRealizationAssessment
    errors
    []
    (mapMaybe blockedCandidateAssessment structuralClaims)

-- | Assess structurally captured collective claims against one exact semantic
-- model.
--
-- Structural defects and Asserted semantic deficiencies accumulate as fatal
-- errors. Independent structurally valid Candidates remain observable with
-- their semantic issues. Candidates never construct validated witnesses.
assessCollectiveStrategyRealizations ::
     ContextSemantics
  -> CollectiveMacroEvidence
  -> [RawCollectiveFitEvidence]
  -> CollectiveClaimStructureAssessment
  -> CollectiveStrategyRealizationAssessment
assessCollectiveStrategyRealizations semantic evidence fitEvidence (CollectiveClaimStructureAssessment structuralErrors structuralClaims) =
  CollectiveStrategyRealizationAssessment
    errors
    evaluations
    (mapMaybe candidateAssessment evaluations)
  where
    fitIndex = buildCollectiveFitIndex fitEvidence
    evaluations =
      map (evaluateCollective semantic evidence fitIndex) structuralClaims
    errors = structuralErrors ++ concatMap evaluationErrors evaluations

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
     StructuralAssessment
  -> Claim RawCollectiveStrategyRealization
  -> Validation
       (NonEmpty CollectiveStrategyRealizationError)
       StructurallyValidCollective
validateCollectiveStructure structure claim =
  case NonEmpty.nonEmpty errors of
    Just failures -> Failure (fmap CollectiveStructuralError failures)
    Nothing ->
      case (resolvedContributors, targetResult) of
        (first:second:rest, Right resolvedTarget) ->
          Success
            (StructurallyValidCollective
               claim
               (AtLeastTwo first second rest)
               resolvedTarget)
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
    (contributorErrors, resolvedContributors) =
      partitionEithers
        (map
           (resolveCollectiveParticipant
              structure
              (claimCommitment claim)
              identifier
              CollectiveContributor)
           distinctContributors)
    targetResult =
      resolveCollectiveParticipant
        structure
        (claimCommitment claim)
        identifier
        CollectiveTarget
        target
    targetErrors =
      case targetResult of
        Left failure -> [failure]
        Right _ -> []
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
        ++ contributorErrors
        ++ targetErrors

resolveCollectiveParticipant ::
     StructuralAssessment
  -> Commitment
  -> ClaimId
  -> CollectiveParticipantRole
  -> RawNodeId
  -> Either
       CollectiveStrategyRealizationStructuralError
       StructuralStrategyParticipant
resolveCollectiveParticipant structure collectiveCommitment claim role participant =
  case lookupStructuralNodeDeclaration structure participant of
    Nothing -> Left (UnknownCollectiveParticipant claim role participant)
    Just declaration
      | structuralNodeDeclarationKind declaration /= ContextNodeKind Strategy ->
        Left
          (NonStrategyCollectiveParticipant
             claim
             role
             participant
             (structuralNodeDeclarationKind declaration))
      | collectiveCommitment == Asserted
      , participantCommitment == Candidate ->
        Left (AssertedCollectiveDependsOnCandidate claim role participant)
      | otherwise ->
        Right (StructuralStrategyParticipant participant participantCommitment)
      where participantCommitment =
              structuralNodeDeclarationCommitment declaration

evaluateCollective ::
     ContextSemantics
  -> CollectiveMacroEvidence
  -> CollectiveFitIndex
  -> StructurallyValidCollective
  -> SemanticEvaluation
evaluateCollective semantic evidence fitIndex structural =
  case candidateParticipantIssues structural of
    [] -> SemanticEvaluation structural issues contributionEvidence
    candidateIssues -> SemanticEvaluation structural candidateIssues []
  where
    claim = claimedProposition (structurallyValidClaim structural)
    contributors = structurallyValidContributorIds structural
    target = structurallyValidTargetId structural
    contributionEvidence =
      [ ( contributor
        , NonEmpty.nonEmpty
            (collectiveContributionWitnesses
               evidence
               (structuralParticipantId contributor)
               target))
      | contributor <- structurallyValidContributorList structural
      ]
    contributionIssues =
      [ MissingContributorContribution
        (structuralParticipantId contributor)
        target
      | (contributor, Nothing) <- contributionEvidence
      ]
    witnessPremiseEdges =
      concat
        [ concatMap
          (NonEmpty.toList . validatedWitnessPremises)
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
  , Just contributors <-
      traverseAtLeastTwo
        liftAssertedStrategyParticipant
        (structurallyValidContributors structural)
  , Just target <-
      liftAssertedStrategyParticipant (structurallyValidTarget structural)
  , Just validatedEvidence <- traverse requireEvidence evidence =
    Just
      (CollectiveStrategyRealization
         (rawRealizationId proposition)
         contributors
         target
         (rawCollectiveFitEvidence proposition)
         validatedEvidence)
  | otherwise = Nothing
  where
    claim = structurallyValidClaim structural
    proposition = claimedProposition claim
    requireEvidence (participant, Just witnesses) = do
      contributor <- liftAssertedStrategyParticipant participant
      pure (contributor, witnesses)
    requireEvidence (_, Nothing) = Nothing

candidateAssessment ::
     SemanticEvaluation -> Maybe CandidateCollectiveStrategyRealization
candidateAssessment (SemanticEvaluation structural issues _)
  | claimCommitment claim == Candidate =
    Just (CandidateCollectiveStrategyRealization claim issues)
  | otherwise = Nothing
  where
    claim = structurallyValidClaim structural

blockedCandidateAssessment ::
     StructurallyValidCollective -> Maybe CandidateCollectiveStrategyRealization
blockedCandidateAssessment structural
  | claimCommitment claim == Candidate =
    Just
      (CandidateCollectiveStrategyRealization
         claim
         [CollectiveSemanticEvaluationBlocked])
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
     StructurallyValidCollective -> AtLeastTwo StructuralStrategyParticipant
structurallyValidContributors (StructurallyValidCollective _ contributors _) =
  contributors

structurallyValidContributorIds :: StructurallyValidCollective -> [RawNodeId]
structurallyValidContributorIds =
  map structuralParticipantId . structurallyValidContributorList

structurallyValidContributorList ::
     StructurallyValidCollective -> [StructuralStrategyParticipant]
structurallyValidContributorList =
  NonEmpty.toList . atLeastTwoToNonEmpty . structurallyValidContributors

structurallyValidTarget ::
     StructurallyValidCollective -> StructuralStrategyParticipant
structurallyValidTarget (StructurallyValidCollective _ _ target) = target

structurallyValidTargetId :: StructurallyValidCollective -> RawNodeId
structurallyValidTargetId = structuralParticipantId . structurallyValidTarget

structuralParticipantId :: StructuralStrategyParticipant -> RawNodeId
structuralParticipantId (StructuralStrategyParticipant identifier _) =
  identifier

structuralParticipantCommitment :: StructuralStrategyParticipant -> Commitment
structuralParticipantCommitment (StructuralStrategyParticipant _ commitment) =
  commitment

-- | Report every Candidate participant in contributor order, then the target.
--
-- Context semantics exists on this path, but Candidate Strategy declarations
-- cannot supply the validated Context references required by a witness.
candidateParticipantIssues ::
     StructurallyValidCollective -> [CollectiveStrategyRealizationIssue]
candidateParticipantIssues structural =
  mapMaybe candidateIssue contributors ++ mapMaybe candidateIssue [target]
  where
    contributors =
      map
        (\participant -> (CollectiveContributor, participant))
        (structurallyValidContributorList structural)
    target = (CollectiveTarget, structurallyValidTarget structural)
    candidateIssue (role, participant)
      | structuralParticipantCommitment participant == Candidate =
        Just
          (CandidateParticipantSemanticsUnavailable
             role
             (structuralParticipantId participant))
      | otherwise = Nothing

-- | Lift one assessed Strategy participant into asserted semantics.
--
-- Candidate declarations have no 'ContextRef' representation by construction.
liftAssertedStrategyParticipant ::
     StructuralStrategyParticipant -> Maybe (ContextRef 'Strategy)
liftAssertedStrategyParticipant participant
  | structuralParticipantCommitment participant == Asserted =
    Just (mkContextRef (structuralParticipantId participant))
  | otherwise = Nothing

traverseAtLeastTwo ::
     (left -> Maybe right) -> AtLeastTwo left -> Maybe (AtLeastTwo right)
traverseAtLeastTwo transform (AtLeastTwo first second rest) =
  AtLeastTwo
    <$> transform first
    <*> transform second
    <*> traverse transform rest

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
