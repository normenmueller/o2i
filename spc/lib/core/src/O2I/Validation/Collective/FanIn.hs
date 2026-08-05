{-# LANGUAGE DataKinds #-}

-- | Shared structural kernel for the closed collective fan-in registry.
--
-- This module owns only the fixed fan-in shape and commitment/completeness
-- contract. Fachliche evidence remains owned by the selected family.
module O2I.Validation.Collective.FanIn
  ( RawCollectiveFanIn(..)
  , CollectiveFanInStructuralError(..)
  , CollectiveFanInStructuralWork(..)
  , StructuralStrategyParticipant
  , StructurallyValidCollectiveFanIn
  , AssertedClosedCollectiveFanIn
  , assessCollectiveFanInStructure
  , validatedFanInClaim
  , validatedFanInFamily
  , validatedFanInParticipants
  , validatedFanInParticipantIds
  , validatedFanInTarget
  , validatedFanInTargetId
  , validatedFanInEvidence
  , validatedFanInCompleteness
  , participantId
  , participantCommitment
  , candidateParticipantIssues
  , liftAssertedClosedFanIn
  , assertedFanInId
  , assertedFanInFamily
  , assertedFanInParticipants
  , assertedFanInTarget
  , assertedFanInEvidence
  , atLeastTwoToNonEmpty
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Language.Claim
import O2I.Language.Element
import O2I.Validation.Collective.Types
import O2I.Validation.Structure.Internal

-- | Family-neutral unchecked fan-in shape.
data RawCollectiveFanIn evidence = RawCollectiveFanIn
  { rawFanInId :: ClaimId
  , rawFanInParticipants :: [RawNodeId]
  , rawFanInTarget :: RawNodeId
  , rawFanInCompleteness :: ParticipantCompleteness
  , rawFanInEvidence :: evidence
  , rawFanInEvidenceReferenceText :: Text
  } deriving (Eq, Show)

-- | Shared fatal defect of the fixed fan-in shape.
data CollectiveFanInStructuralError
  = EmptyCollectiveFanInClaimId PropositionFamily
  | EmptyCollectiveFanInEvidenceReference PropositionFamily ClaimId
  | TooFewCollectiveFanInParticipants PropositionFamily ClaimId
  | DuplicateCollectiveFanInParticipant PropositionFamily ClaimId RawNodeId
  | CollectiveFanInParticipantIsTarget PropositionFamily ClaimId RawNodeId
  | UnknownCollectiveFanInParticipant
      PropositionFamily
      ClaimId
      CollectiveParticipantRole
      RawNodeId
  | NonStrategyCollectiveFanInParticipant
      PropositionFamily
      ClaimId
      CollectiveParticipantRole
      RawNodeId
      NodeKindValue
  | AssertedCollectiveFanInDependsOnCandidate
      PropositionFamily
      ClaimId
      CollectiveParticipantRole
      RawNodeId
  | AssertedOpenCollectiveFanIn PropositionFamily ClaimId
  deriving (Eq, Show)

-- | Exact structural work performed for one proposition.
data CollectiveFanInStructuralWork = CollectiveFanInStructuralWork
  { fanInClaimsRead :: !Int
  , fanInParticipantIdsRead :: !Int
  , fanInParticipantMembershipProbes :: !Int
  , fanInParticipantDeclarationLookups :: !Int
  , fanInTargetDeclarationLookups :: !Int
  } deriving (Eq, Show)

instance Semigroup CollectiveFanInStructuralWork where
  left <> right =
    CollectiveFanInStructuralWork
      { fanInClaimsRead = fanInClaimsRead left + fanInClaimsRead right
      , fanInParticipantIdsRead =
          fanInParticipantIdsRead left + fanInParticipantIdsRead right
      , fanInParticipantMembershipProbes =
          fanInParticipantMembershipProbes left
            + fanInParticipantMembershipProbes right
      , fanInParticipantDeclarationLookups =
          fanInParticipantDeclarationLookups left
            + fanInParticipantDeclarationLookups right
      , fanInTargetDeclarationLookups =
          fanInTargetDeclarationLookups left
            + fanInTargetDeclarationLookups right
      }

instance Monoid CollectiveFanInStructuralWork where
  mempty = CollectiveFanInStructuralWork 0 0 0 0 0

-- | Internal non-empty shape with a statically guaranteed second member.
data AtLeastTwo value =
  AtLeastTwo value value [value]

-- | Structurally accepted Strategy declaration with retained commitment.
data StructuralStrategyParticipant =
  StructuralStrategyParticipant RawNodeId Commitment

-- | Opaque structurally valid fan-in proposition.
data StructurallyValidCollectiveFanIn evidence =
  StructurallyValidCollectiveFanIn
    PropositionFamily
    (Claim (RawCollectiveFanIn evidence))
    (AtLeastTwo StructuralStrategyParticipant)
    StructuralStrategyParticipant

-- | Opaque fan-in shape proven Asserted, Closed, and participant-Asserted.
data AssertedClosedCollectiveFanIn evidence =
  AssertedClosedCollectiveFanIn
    ClaimId
    PropositionFamily
    (AtLeastTwo (ContextRef 'Strategy))
    (ContextRef 'Strategy)
    evidence

-- | Validate one fixed fan-in shape without evaluating family evidence.
--
-- Every participant is addressed exactly once through the structural index.
-- Diagnostics retain participant source order.
assessCollectiveFanInStructure ::
     StructuralAssessment
  -> PropositionFamily
  -> Claim (RawCollectiveFanIn evidence)
  -> ( [CollectiveFanInStructuralError]
     , Maybe (StructurallyValidCollectiveFanIn evidence)
     , CollectiveFanInStructuralWork)
assessCollectiveFanInStructure structure family claim =
  (errors, validated, work)
  where
    proposition = claimedProposition claim
    identifier = rawFanInId proposition
    participants = rawFanInParticipants proposition
    (distinctParticipants, duplicateParticipants, membershipProbes) =
      distinctAndDuplicates participants
    participantResults =
      map
        (resolveParticipant
           structure
           family
           (claimCommitment claim)
           identifier
           CollectiveContributor)
        distinctParticipants
    targetResult =
      resolveParticipant
        structure
        family
        (claimCommitment claim)
        identifier
        CollectiveTarget
        (rawFanInTarget proposition)
    participantErrors = [failure | Left failure <- participantResults]
    resolvedParticipants =
      [participant | Right participant <- participantResults]
    targetErrors = either (: []) (const []) targetResult
    errors =
      [EmptyCollectiveFanInClaimId family | blankClaimId identifier]
        ++ [ EmptyCollectiveFanInEvidenceReference family identifier
           | Text.null (Text.strip (rawFanInEvidenceReferenceText proposition))
           ]
        ++ [ TooFewCollectiveFanInParticipants family identifier
           | length distinctParticipants < 2
           ]
        ++ map
             (DuplicateCollectiveFanInParticipant family identifier)
             duplicateParticipants
        ++ [ CollectiveFanInParticipantIsTarget
             family
             identifier
             (rawFanInTarget proposition)
           | rawFanInTarget proposition `elem` distinctParticipants
           ]
        ++ [ AssertedOpenCollectiveFanIn family identifier
           | claimCommitment claim == Asserted
           , rawFanInCompleteness proposition == Open
           ]
        ++ participantErrors
        ++ targetErrors
    validated =
      case (errors, resolvedParticipants, targetResult) of
        ([], first:second:rest, Right target) ->
          Just
            (StructurallyValidCollectiveFanIn
               family
               claim
               (AtLeastTwo first second rest)
               target)
        _ -> Nothing
    work =
      CollectiveFanInStructuralWork
        { fanInClaimsRead = 1
        , fanInParticipantIdsRead = length participants
        , fanInParticipantMembershipProbes = membershipProbes
        , fanInParticipantDeclarationLookups = length distinctParticipants
        , fanInTargetDeclarationLookups = 1
        }

validatedFanInClaim ::
     StructurallyValidCollectiveFanIn evidence
  -> Claim (RawCollectiveFanIn evidence)
validatedFanInClaim (StructurallyValidCollectiveFanIn _ claim _ _) = claim

validatedFanInFamily ::
     StructurallyValidCollectiveFanIn evidence -> PropositionFamily
validatedFanInFamily (StructurallyValidCollectiveFanIn family _ _ _) = family

validatedFanInParticipants ::
     StructurallyValidCollectiveFanIn evidence
  -> NonEmpty StructuralStrategyParticipant
validatedFanInParticipants (StructurallyValidCollectiveFanIn _ _ participants _) =
  atLeastTwoToNonEmpty participants

validatedFanInParticipantIds ::
     StructurallyValidCollectiveFanIn evidence -> NonEmpty RawNodeId
validatedFanInParticipantIds = fmap participantId . validatedFanInParticipants

validatedFanInTarget ::
     StructurallyValidCollectiveFanIn evidence -> StructuralStrategyParticipant
validatedFanInTarget (StructurallyValidCollectiveFanIn _ _ _ target) = target

validatedFanInTargetId :: StructurallyValidCollectiveFanIn evidence -> RawNodeId
validatedFanInTargetId = participantId . validatedFanInTarget

validatedFanInEvidence :: StructurallyValidCollectiveFanIn evidence -> evidence
validatedFanInEvidence =
  rawFanInEvidence . claimedProposition . validatedFanInClaim

validatedFanInCompleteness ::
     StructurallyValidCollectiveFanIn evidence -> ParticipantCompleteness
validatedFanInCompleteness =
  rawFanInCompleteness . claimedProposition . validatedFanInClaim

participantId :: StructuralStrategyParticipant -> RawNodeId
participantId (StructuralStrategyParticipant identifier _) = identifier

participantCommitment :: StructuralStrategyParticipant -> Commitment
participantCommitment (StructuralStrategyParticipant _ commitment) = commitment

-- | Report Candidate declarations in participant order, then the target.
candidateParticipantIssues ::
     StructurallyValidCollectiveFanIn evidence
  -> [(CollectiveParticipantRole, RawNodeId)]
candidateParticipantIssues structural =
  [ (CollectiveContributor, participantId participant)
  | participant <- NonEmpty.toList (validatedFanInParticipants structural)
  , participantCommitment participant == Candidate
  ]
    ++ [ (CollectiveTarget, participantId target)
       | let target = validatedFanInTarget structural
       , participantCommitment target == Candidate
       ]

-- | Lift a structurally valid fan-in only across the Asserted/Closed boundary.
liftAssertedClosedFanIn ::
     StructurallyValidCollectiveFanIn evidence
  -> Maybe (AssertedClosedCollectiveFanIn evidence)
liftAssertedClosedFanIn structural
  | claimCommitment claim == Asserted
  , validatedFanInCompleteness structural == Closed
  , Just participants <- traverseAtLeastTwo liftParticipant storedParticipants
  , Just target <- liftParticipant (validatedFanInTarget structural) =
    Just
      (AssertedClosedCollectiveFanIn
         (rawFanInId proposition)
         (validatedFanInFamily structural)
         participants
         target
         (rawFanInEvidence proposition))
  | otherwise = Nothing
  where
    claim = validatedFanInClaim structural
    proposition = claimedProposition claim
    storedParticipants =
      case structural of
        StructurallyValidCollectiveFanIn _ _ participants _ -> participants

assertedFanInParticipants ::
     AssertedClosedCollectiveFanIn evidence -> NonEmpty (ContextRef 'Strategy)
assertedFanInParticipants (AssertedClosedCollectiveFanIn _ _ participants _ _) =
  atLeastTwoToNonEmpty participants

assertedFanInId :: AssertedClosedCollectiveFanIn evidence -> ClaimId
assertedFanInId (AssertedClosedCollectiveFanIn identifier _ _ _ _) = identifier

assertedFanInFamily ::
     AssertedClosedCollectiveFanIn evidence -> PropositionFamily
assertedFanInFamily (AssertedClosedCollectiveFanIn _ family _ _ _) = family

assertedFanInTarget ::
     AssertedClosedCollectiveFanIn evidence -> ContextRef 'Strategy
assertedFanInTarget (AssertedClosedCollectiveFanIn _ _ _ target _) = target

assertedFanInEvidence :: AssertedClosedCollectiveFanIn evidence -> evidence
assertedFanInEvidence (AssertedClosedCollectiveFanIn _ _ _ _ evidence) =
  evidence

resolveParticipant ::
     StructuralAssessment
  -> PropositionFamily
  -> Commitment
  -> ClaimId
  -> CollectiveParticipantRole
  -> RawNodeId
  -> Either CollectiveFanInStructuralError StructuralStrategyParticipant
resolveParticipant structure family collectiveCommitment claim role identifier =
  case lookupStructuralNodeDeclaration structure identifier of
    Nothing ->
      Left (UnknownCollectiveFanInParticipant family claim role identifier)
    Just declaration
      | structuralNodeDeclarationKind declaration /= ContextNodeKind Strategy ->
        Left
          (NonStrategyCollectiveFanInParticipant
             family
             claim
             role
             identifier
             (structuralNodeDeclarationKind declaration))
      | collectiveCommitment == Asserted
      , commitment == Candidate ->
        Left
          (AssertedCollectiveFanInDependsOnCandidate
             family
             claim
             role
             identifier)
      | otherwise -> Right (StructuralStrategyParticipant identifier commitment)
      where commitment = structuralNodeDeclarationCommitment declaration

liftParticipant :: StructuralStrategyParticipant -> Maybe (ContextRef 'Strategy)
liftParticipant participant
  | participantCommitment participant == Asserted =
    Just (mkContextRef (participantId participant))
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

blankClaimId :: ClaimId -> Bool
blankClaimId = Text.null . Text.strip . claimIdText

distinctAndDuplicates :: Ord value => [value] -> ([value], [value], Int)
distinctAndDuplicates = go Set.empty Set.empty [] [] 0
  where
    go _ _ distinct duplicates probes [] =
      (reverse distinct, reverse duplicates, probes)
    go seen reported distinct duplicates probes (value:rest)
      | Set.member value seen =
        go
          seen
          (Set.insert value reported)
          distinct
          (if Set.member value reported
             then duplicates
             else value : duplicates)
          (probes + 2)
          rest
      | otherwise =
        go
          (Set.insert value seen)
          reported
          (value : distinct)
          duplicates
          (probes + 1)
          rest
