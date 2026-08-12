{-# LANGUAGE DataKinds #-}

-- | Closed registry and single routing boundary for collective fan-in families.
--
-- The registry owns global claim identity, source routing, shared Candidate
-- occurrence preparation, and exhaustive family dispatch. Family modules own
-- only their fachliche evidence rules and witnesses.
module O2I.Validation.Collective.Registry.Internal
  ( RawCollectiveFanInClaim(..)
  , RawCollectiveFanInEvidence(..)
  , CollectiveRegistryError(..)
  , CollectiveRegistryCandidate(..)
  , CollectiveRegistryPreparationWork(..)
  , PreparedCollectiveRegistry
  , CollectiveRegistryAssessment
  , EvaluatedCollectiveRegistry
  , ValidatedCollectiveRegistry
  , collectiveFanInClaimFamily
  , collectiveFanInClaimId
  , prepareCollectiveRegistry
  , blockCollectiveRegistry
  , assessCollectiveRegistry
  , evaluatedCollectiveRegistryAssessment
  , collectiveRegistryErrors
  , collectiveRegistryCandidates
  , collectiveRegistryPreparationWork
  , registryRealizationAssessment
  , registryContributionAssessment
  , registryContributionPreparationWork
  , registryContributionWork
  , registryValidatedRealizations
  , registryValidatedContributions
  , validateCollectiveRegistry
  , validatedRegistryRealizations
  , validatedRegistryContributions
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import Data.Maybe (mapMaybe)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Validation (Validation(..))
import O2I.Graph.Raw (CandidateGraphProposition(..), RawEdge)
import O2I.Language.Claim
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
import O2I.Validation.MacroEvidence
import O2I.Validation.Semantics.Context
import O2I.Validation.Structure.Internal

-- | One commitment-bearing proposition from the closed collective fan-in
-- family registry.
data RawCollectiveFanInClaim
  = CollectiveStrategyRealizationClaim (Claim RawCollectiveStrategyRealization)
  | CollectiveStrategyContributionClaim
      (Claim RawCollectiveStrategyContribution)
  deriving (Eq, Show)

-- | One family-owned evidence bundle supplied to collective evaluation.
data RawCollectiveFanInEvidence
  = CollectiveStrategyRealizationEvidence RawCollectiveFitEvidence
  | CollectiveStrategyContributionEvidence RawCollectiveContributionEvidence
  deriving (Eq, Show)

-- | Fatal global or family-owned defect reported by collective evaluation.
data CollectiveRegistryError
  = DuplicateCollectiveFanInClaimId ClaimId
  | CollectiveRegistryRealizationError CollectiveStrategyRealizationError
  | CollectiveRegistryContributionError CollectiveStrategyContributionError
  deriving (Eq, Show)

data CollectiveRegistryCandidate = CollectiveRegistryCandidate
  { registryCandidateFamily :: PropositionFamily
  , registryCandidateId :: ClaimId
  } deriving (Eq, Show)

-- | Exact once-only operations performed while routing collective input.
data CollectiveRegistryPreparationWork = CollectiveRegistryPreparationWork
  { registryClaimSourceReads :: !Int
  , registryClaimIdentityProbes :: !Int
  , registryFitEvidenceInsertions :: !Int
  , registryContributionEvidenceInsertions :: !Int
  , registryEvidenceSourceReads :: !Int
  , registryStructuralCandidateSourceReads :: !Int
  , registryCandidateEdgeInsertions :: !Int
  } deriving (Eq, Show)

data PreparedCollectiveRegistry =
  PreparedCollectiveRegistry
    StructuralAssessment
    [ClaimId]
    [RoutedClaimOccurrence]
    [Claim RawCollectiveStrategyRealization]
    [Claim RawCollectiveStrategyContribution]
    CollectiveClaimStructureAssessment
    CollectiveContributionClaimStructureAssessment
    [RawCollectiveFitEvidence]
    [RawCollectiveContributionEvidence]
    (Set RawEdge)
    CollectiveRegistryPreparationWork

data CollectiveRegistryAssessment
  = BlockedCollectiveRegistryAssessment
      CollectiveStrategyRealizationAssessment
      CollectiveStrategyContributionAssessment
      [CollectiveRegistryError]
      [CollectiveRegistryCandidate]
      CollectiveRegistryPreparationWork
  | EvaluatedCollectiveRegistryAssessment EvaluatedCollectiveRegistry

data EvaluatedCollectiveRegistry =
  EvaluatedCollectiveRegistry
    CollectiveStrategyRealizationAssessment
    CollectiveStrategyContributionAssessment
    [CollectiveRegistryCandidate]
    (Validation (NonEmpty CollectiveRegistryError) ValidatedCollectiveRegistry)
    CollectiveRegistryPreparationWork

data ValidatedCollectiveRegistry =
  ValidatedCollectiveRegistry
    ValidatedCollectiveStrategyRealizations
    ValidatedCollectiveStrategyContributions

data RoutedClaimOccurrence =
  RoutedClaimOccurrence PropositionFamily Int ClaimId

data ClaimRouting = ClaimRouting
  { routedSeenClaimIds :: !(Set ClaimId)
  , routedDuplicateClaimIds :: !(Set ClaimId)
  , routedDuplicateIdsReversed :: [ClaimId]
  , routedClaimOrderReversed :: [RoutedClaimOccurrence]
  , routedRealizationClaimsReversed :: [Claim RawCollectiveStrategyRealization]
  , routedContributionClaimsReversed :: [Claim RawCollectiveStrategyContribution]
  , routedClaimReads :: !Int
  , routedClaimIdentityProbes :: !Int
  , routedRealizationClaimCount :: !Int
  , routedContributionClaimCount :: !Int
  }

data EvidenceRouting = EvidenceRouting
  { routedFitEvidenceReversed :: [RawCollectiveFitEvidence]
  , routedContributionEvidenceReversed :: [RawCollectiveContributionEvidence]
  , routedEvidenceReads :: !Int
  , routedFitInsertions :: !Int
  , routedContributionInsertions :: !Int
  }

data CandidateRouting = CandidateRouting
  { routedCandidateEdges :: !(Set RawEdge)
  , routedCandidateReads :: !Int
  , routedCandidateEdgeInsertions :: !Int
  }

-- | Identify the closed proposition family that owns one claim.
collectiveFanInClaimFamily :: RawCollectiveFanInClaim -> PropositionFamily
collectiveFanInClaimFamily claim =
  case claim of
    CollectiveStrategyRealizationClaim _ -> CollectiveStrategyRealizationFamily
    CollectiveStrategyContributionClaim _ ->
      CollectiveStrategyContributionFamily

-- | Read the globally unique identity carried by one collective claim.
collectiveFanInClaimId :: RawCollectiveFanInClaim -> ClaimId
collectiveFanInClaimId claim =
  case claim of
    CollectiveStrategyRealizationClaim realization ->
      rawRealizationId (claimedProposition realization)
    CollectiveStrategyContributionClaim contribution ->
      rawContributionId (claimedProposition contribution)

prepareCollectiveRegistry ::
     StructuralAssessment
  -> [RawCollectiveFanInClaim]
  -> [RawCollectiveFanInEvidence]
  -> PreparedCollectiveRegistry
prepareCollectiveRegistry structure claims evidence =
  PreparedCollectiveRegistry
    structure
    (reverse (routedDuplicateIdsReversed claimRouting))
    (reverse (routedClaimOrderReversed claimRouting))
    realizationClaims
    contributionClaims
    (assessCollectiveClaimStructure structure realizationClaims)
    (assessCollectiveContributionClaimStructure structure contributionClaims)
    (reverse (routedFitEvidenceReversed evidenceRouting))
    (reverse (routedContributionEvidenceReversed evidenceRouting))
    (routedCandidateEdges candidateRouting)
    work
  where
    claimRouting = foldl' routeClaim emptyClaimRouting claims
    realizationClaims = reverse (routedRealizationClaimsReversed claimRouting)
    contributionClaims = reverse (routedContributionClaimsReversed claimRouting)
    evidenceRouting = foldl' routeEvidence emptyEvidenceRouting evidence
    candidateRouting =
      foldl'
        routeCandidate
        emptyCandidateRouting
        (structuralAssessmentCandidates structure)
    work =
      CollectiveRegistryPreparationWork
        { registryClaimSourceReads = routedClaimReads claimRouting
        , registryClaimIdentityProbes = routedClaimIdentityProbes claimRouting
        , registryFitEvidenceInsertions = routedFitInsertions evidenceRouting
        , registryContributionEvidenceInsertions =
            routedContributionInsertions evidenceRouting
        , registryEvidenceSourceReads = routedEvidenceReads evidenceRouting
        , registryStructuralCandidateSourceReads =
            routedCandidateReads candidateRouting
        , registryCandidateEdgeInsertions =
            routedCandidateEdgeInsertions candidateRouting
        }

blockCollectiveRegistry ::
     PreparedCollectiveRegistry -> CollectiveRegistryAssessment
blockCollectiveRegistry prepared =
  BlockedCollectiveRegistryAssessment
    realizationAssessment
    contributionAssessment
    errors
    candidates
    preparationWork
  where
    PreparedCollectiveRegistry _structure duplicateIds claimOrder realizationClaims contributionClaims realizationStructure contributionStructure _fitEvidence _contributionEvidence _candidateEdges preparationWork =
      prepared
    realizationAssessment =
      blockedCollectiveStrategyRealizationAssessment realizationStructure
    contributionAssessment =
      blockedCollectiveStrategyContributionAssessment contributionStructure
    errors =
      map DuplicateCollectiveFanInClaimId duplicateIds
        ++ map
             CollectiveRegistryRealizationError
             (collectiveStrategyRealizationErrors realizationAssessment)
        ++ map
             CollectiveRegistryContributionError
             (collectiveStrategyContributionErrors contributionAssessment)
    candidates =
      registryCandidatesInSourceOrder
        claimOrder
        realizationClaims
        contributionClaims
        realizationAssessment
        contributionAssessment

assessCollectiveRegistry ::
     ContextSemantics
  -> PreparedMacroEvidence
  -> PreparedCollectiveRegistry
  -> EvaluatedCollectiveRegistry
assessCollectiveRegistry context macro prepared =
  EvaluatedCollectiveRegistry
    realizationAssessment
    contributionAssessment
    candidates
    validation
    preparationWork
  where
    PreparedCollectiveRegistry structure duplicateIds claimOrder realizationClaims contributionClaims realizationStructure contributionStructure fitEvidence contributionEvidence candidateEdges preparationWork =
      prepared
    realizationAssessment =
      assessCollectiveStrategyRealizations
        context
        (collectiveMacroEvidenceFor macro)
        fitEvidence
        realizationStructure
    contributionAssessment =
      assessCollectiveStrategyContributions
        (prepareCollectiveContribution
           structure
           context
           macro
           candidateEdges
           contributionEvidence)
        contributionStructure
    rawRealizationValidation =
      validateCollectiveStrategyRealizations realizationAssessment
    rawContributionValidation =
      validateCollectiveStrategyContributions contributionAssessment
    validation =
      (\_ realizations contributions ->
         ValidatedCollectiveRegistry realizations contributions)
        <$> duplicateValidation
        <*> mapValidation
              CollectiveRegistryRealizationError
              rawRealizationValidation
        <*> mapValidation
              CollectiveRegistryContributionError
              rawContributionValidation
    duplicateValidation =
      case duplicateIds of
        [] -> Success ()
        first:rest ->
          Failure
            (DuplicateCollectiveFanInClaimId first
               :| map DuplicateCollectiveFanInClaimId rest)
    candidates =
      registryCandidatesInSourceOrder
        claimOrder
        realizationClaims
        contributionClaims
        realizationAssessment
        contributionAssessment

evaluatedCollectiveRegistryAssessment ::
     EvaluatedCollectiveRegistry -> CollectiveRegistryAssessment
evaluatedCollectiveRegistryAssessment = EvaluatedCollectiveRegistryAssessment

collectiveRegistryErrors ::
     CollectiveRegistryAssessment -> [CollectiveRegistryError]
collectiveRegistryErrors assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment _ _ errors _ _ -> errors
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryErrors evaluated

collectiveRegistryCandidates ::
     CollectiveRegistryAssessment -> [CollectiveRegistryCandidate]
collectiveRegistryCandidates assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment _ _ _ candidates _ -> candidates
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryCandidates evaluated

collectiveRegistryPreparationWork ::
     CollectiveRegistryAssessment -> CollectiveRegistryPreparationWork
collectiveRegistryPreparationWork assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment _ _ _ _ work -> work
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryPreparationWork evaluated

registryRealizationAssessment ::
     CollectiveRegistryAssessment -> CollectiveStrategyRealizationAssessment
registryRealizationAssessment assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment realization _ _ _ _ -> realization
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryRealizationAssessment evaluated

registryContributionAssessment ::
     CollectiveRegistryAssessment -> CollectiveStrategyContributionAssessment
registryContributionAssessment assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment _ contribution _ _ _ -> contribution
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryContributionAssessment evaluated

registryContributionPreparationWork ::
     CollectiveRegistryAssessment -> Maybe CollectiveContributionPreparationWork
registryContributionPreparationWork assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment {} -> Nothing
    EvaluatedCollectiveRegistryAssessment evaluated ->
      Just
        (contributionAssessmentPreparationWork
           (evaluatedRegistryContributionAssessment evaluated))

registryContributionWork ::
     CollectiveRegistryAssessment -> Maybe CollectiveContributionValidationWork
registryContributionWork assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment {} -> Nothing
    EvaluatedCollectiveRegistryAssessment evaluated ->
      Just
        (contributionAssessmentWork
           (evaluatedRegistryContributionAssessment evaluated))

registryValidatedRealizations ::
     CollectiveRegistryAssessment
  -> Maybe ValidatedCollectiveStrategyRealizations
registryValidatedRealizations assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment {} -> Nothing
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryValidatedRealizations evaluated

registryValidatedContributions ::
     CollectiveRegistryAssessment
  -> Maybe ValidatedCollectiveStrategyContributions
registryValidatedContributions assessment =
  case assessment of
    BlockedCollectiveRegistryAssessment {} -> Nothing
    EvaluatedCollectiveRegistryAssessment evaluated ->
      evaluatedRegistryValidatedContributions evaluated

validateCollectiveRegistry ::
     EvaluatedCollectiveRegistry
  -> Validation (NonEmpty CollectiveRegistryError) ValidatedCollectiveRegistry
validateCollectiveRegistry = evaluatedRegistryValidation

evaluatedRegistryRealizationAssessment ::
     EvaluatedCollectiveRegistry -> CollectiveStrategyRealizationAssessment
evaluatedRegistryRealizationAssessment (EvaluatedCollectiveRegistry assessment _ _ _ _) =
  assessment

evaluatedRegistryContributionAssessment ::
     EvaluatedCollectiveRegistry -> CollectiveStrategyContributionAssessment
evaluatedRegistryContributionAssessment (EvaluatedCollectiveRegistry _ assessment _ _ _) =
  assessment

evaluatedRegistryValidatedRealizations ::
     EvaluatedCollectiveRegistry
  -> Maybe ValidatedCollectiveStrategyRealizations
evaluatedRegistryValidatedRealizations evaluated =
  case evaluatedRegistryValidation evaluated of
    Failure _ -> Nothing
    Success validated -> Just (validatedRegistryRealizations validated)

evaluatedRegistryValidatedContributions ::
     EvaluatedCollectiveRegistry
  -> Maybe ValidatedCollectiveStrategyContributions
evaluatedRegistryValidatedContributions evaluated =
  case evaluatedRegistryValidation evaluated of
    Failure _ -> Nothing
    Success validated -> Just (validatedRegistryContributions validated)

evaluatedRegistryErrors ::
     EvaluatedCollectiveRegistry -> [CollectiveRegistryError]
evaluatedRegistryErrors evaluated =
  case evaluatedRegistryValidation evaluated of
    Failure failures -> nonEmptyToList failures
    Success _ -> []

evaluatedRegistryCandidates ::
     EvaluatedCollectiveRegistry -> [CollectiveRegistryCandidate]
evaluatedRegistryCandidates (EvaluatedCollectiveRegistry _ _ candidates _ _) =
  candidates

evaluatedRegistryValidation ::
     EvaluatedCollectiveRegistry
  -> Validation (NonEmpty CollectiveRegistryError) ValidatedCollectiveRegistry
evaluatedRegistryValidation (EvaluatedCollectiveRegistry _ _ _ validation _) =
  validation

evaluatedRegistryPreparationWork ::
     EvaluatedCollectiveRegistry -> CollectiveRegistryPreparationWork
evaluatedRegistryPreparationWork (EvaluatedCollectiveRegistry _ _ _ _ work) =
  work

validatedRegistryRealizations ::
     ValidatedCollectiveRegistry -> ValidatedCollectiveStrategyRealizations
validatedRegistryRealizations (ValidatedCollectiveRegistry realizations _) =
  realizations

validatedRegistryContributions ::
     ValidatedCollectiveRegistry -> ValidatedCollectiveStrategyContributions
validatedRegistryContributions (ValidatedCollectiveRegistry _ contributions) =
  contributions

emptyClaimRouting :: ClaimRouting
emptyClaimRouting =
  ClaimRouting
    { routedSeenClaimIds = Set.empty
    , routedDuplicateClaimIds = Set.empty
    , routedDuplicateIdsReversed = []
    , routedClaimOrderReversed = []
    , routedRealizationClaimsReversed = []
    , routedContributionClaimsReversed = []
    , routedClaimReads = 0
    , routedClaimIdentityProbes = 0
    , routedRealizationClaimCount = 0
    , routedContributionClaimCount = 0
    }

routeClaim :: ClaimRouting -> RawCollectiveFanInClaim -> ClaimRouting
routeClaim routing claim =
  routed
    { routedSeenClaimIds = Set.insert identifier (routedSeenClaimIds routing)
    , routedDuplicateClaimIds = duplicateIds
    , routedDuplicateIdsReversed = duplicateOrder
    , routedClaimOrderReversed =
        RoutedClaimOccurrence family familyOrdinal identifier
          : routedClaimOrderReversed routing
    , routedClaimReads = routedClaimReads routing + 1
    , routedClaimIdentityProbes =
        routedClaimIdentityProbes routing
          + if repeated
              then 2
              else 1
    }
  where
    identifier = collectiveFanInClaimId claim
    repeated = Set.member identifier (routedSeenClaimIds routing)
    firstDuplicate =
      repeated && Set.notMember identifier (routedDuplicateClaimIds routing)
    duplicateIds
      | firstDuplicate = Set.insert identifier (routedDuplicateClaimIds routing)
      | otherwise = routedDuplicateClaimIds routing
    duplicateOrder
      | firstDuplicate = identifier : routedDuplicateIdsReversed routing
      | otherwise = routedDuplicateIdsReversed routing
    (family, familyOrdinal, routed) =
      case claim of
        CollectiveStrategyRealizationClaim realization ->
          ( CollectiveStrategyRealizationFamily
          , routedRealizationClaimCount routing
          , routing
              { routedRealizationClaimsReversed =
                  realization : routedRealizationClaimsReversed routing
              , routedRealizationClaimCount =
                  routedRealizationClaimCount routing + 1
              })
        CollectiveStrategyContributionClaim contribution ->
          ( CollectiveStrategyContributionFamily
          , routedContributionClaimCount routing
          , routing
              { routedContributionClaimsReversed =
                  contribution : routedContributionClaimsReversed routing
              , routedContributionClaimCount =
                  routedContributionClaimCount routing + 1
              })

emptyEvidenceRouting :: EvidenceRouting
emptyEvidenceRouting = EvidenceRouting [] [] 0 0 0

routeEvidence ::
     EvidenceRouting -> RawCollectiveFanInEvidence -> EvidenceRouting
routeEvidence routing evidence =
  case evidence of
    CollectiveStrategyRealizationEvidence fit ->
      routing
        { routedFitEvidenceReversed = fit : routedFitEvidenceReversed routing
        , routedEvidenceReads = routedEvidenceReads routing + 1
        , routedFitInsertions = routedFitInsertions routing + 1
        }
    CollectiveStrategyContributionEvidence contribution ->
      routing
        { routedContributionEvidenceReversed =
            contribution : routedContributionEvidenceReversed routing
        , routedEvidenceReads = routedEvidenceReads routing + 1
        , routedContributionInsertions =
            routedContributionInsertions routing + 1
        }

emptyCandidateRouting :: CandidateRouting
emptyCandidateRouting = CandidateRouting Set.empty 0 0

routeCandidate ::
     CandidateRouting -> CandidateGraphProposition -> CandidateRouting
routeCandidate routing candidate =
  case candidate of
    CandidateNodeProposition _ ->
      routing {routedCandidateReads = routedCandidateReads routing + 1}
    CandidateEdgeProposition edge ->
      routing
        { routedCandidateEdges = Set.insert edge edges
        , routedCandidateReads = routedCandidateReads routing + 1
        , routedCandidateEdgeInsertions =
            routedCandidateEdgeInsertions routing + 1
        }
      where edges = routedCandidateEdges routing

registryCandidatesInSourceOrder ::
     [RoutedClaimOccurrence]
  -> [Claim RawCollectiveStrategyRealization]
  -> [Claim RawCollectiveStrategyContribution]
  -> CollectiveStrategyRealizationAssessment
  -> CollectiveStrategyContributionAssessment
  -> [CollectiveRegistryCandidate]
registryCandidatesInSourceOrder claimOrder realizationClaims contributionClaims realizationAssessment contributionAssessment =
  mapMaybe candidateAt claimOrder
  where
    realizationCandidateOrdinals =
      candidateClaimOrdinals
        realizationClaims
        (map
           candidateCollectiveClaim
           (candidateCollectiveStrategyRealizations realizationAssessment))
    contributionCandidateOrdinals =
      candidateClaimOrdinals
        contributionClaims
        (map
           candidateCollectiveContributionClaim
           (candidateCollectiveStrategyContributions contributionAssessment))
    candidateAt (RoutedClaimOccurrence family ordinal identifier) =
      case family of
        CollectiveStrategyRealizationFamily
          | Set.member ordinal realizationCandidateOrdinals ->
            Just (CollectiveRegistryCandidate family identifier)
          | otherwise -> Nothing
        CollectiveStrategyContributionFamily
          | Set.member ordinal contributionCandidateOrdinals ->
            Just (CollectiveRegistryCandidate family identifier)
          | otherwise -> Nothing

candidateClaimOrdinals ::
     Eq proposition => [Claim proposition] -> [Claim proposition] -> Set Int
candidateClaimOrdinals claims candidates = go 0 claims candidates Set.empty
  where
    go _ _ [] ordinals = ordinals
    go _ [] _ ordinals = ordinals
    go ordinal (claim:remainingClaims) pending@(candidate:remainingCandidates) ordinals
      | claim == candidate =
        go
          (ordinal + 1)
          remainingClaims
          remainingCandidates
          (Set.insert ordinal ordinals)
      | otherwise = go (ordinal + 1) remainingClaims pending ordinals

mapValidation ::
     (sourceError -> targetError)
  -> Validation (NonEmpty sourceError) value
  -> Validation (NonEmpty targetError) value
mapValidation mapError validation =
  case validation of
    Failure errors -> Failure (fmap mapError errors)
    Success value -> Success value

nonEmptyToList :: NonEmpty value -> [value]
nonEmptyToList (first :| rest) = first : rest
