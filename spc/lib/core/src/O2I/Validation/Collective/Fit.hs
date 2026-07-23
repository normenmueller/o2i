-- | Indexed assessment of structured collective-Fit evidence.
--
-- Evidence bundles are indexed once by exact reference. Each selected bundle
-- retains source occurrences while providing set- and map-based membership,
-- coherence-pair, and contributor-compatibility lookup.
module O2I.Validation.Collective.Fit
  ( CollectiveFitIndex
  , CollectiveFitTargetExpectation(..)
  , CollectiveFitAssessment
  , CollectiveFitWork
  , collectiveFitReferenceBucketProbes
  , collectiveFitResolvedEvidenceOccurrences
  , collectiveFitContributorMembershipChecks
  , collectiveFitCoherenceOccurrences
  , collectiveFitCoherencePairLookups
  , collectiveFitCompatibilityOccurrences
  , collectiveFitCompatibilityBucketLookups
  , buildCollectiveFitIndex
  , assessCollectiveFit
  , collectiveFitAssessmentIssues
  , collectiveFitAssessmentWork
  ) where

import Data.List (foldl')
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Language.Element (RawNodeId)
import O2I.Validation.Collective.Types

type CoherencePair = (RawNodeId, RawNodeId)

-- | One source-ordered bucket with a cached occurrence count.
data OccurrenceBucket value = OccurrenceBucket
  { occurrenceBucketCardinality :: !Int
  , occurrenceBucketValues :: [value]
  }

-- | One evidence bundle with occurrence-preserving internal indexes.
data IndexedCollectiveFit = IndexedCollectiveFit
  { indexedRawFit :: RawCollectiveFitEvidence
  , indexedFitContributorSet :: Set RawNodeId
  , indexedFitContributorCardinality :: !Int
  , indexedCoherenceInOrder :: [RawMutualCoherenceEvidence]
  , indexedCoherenceByPair :: Map
      CoherencePair
      (OccurrenceBucket RawMutualCoherenceEvidence)
  , indexedCompatibilityInOrder :: [RawContributorCompatibilityEvidence]
  , indexedCompatibilityByContributor :: Map
      RawNodeId
      (OccurrenceBucket RawContributorCompatibilityEvidence)
  }

-- | Immutable occurrence-preserving index of every supplied Fit bundle.
newtype CollectiveFitIndex = CollectiveFitIndex
  { indexedFitsByReference :: Map
      CollectiveFitEvidenceRef
      (OccurrenceBucket IndexedCollectiveFit)
  }

-- | Validated target-Strategy expectations available to Fit assessment.
data CollectiveFitTargetExpectation
  = MissingCollectiveFitTarget
  | ExpectedCollectiveFitTarget RawNodeId [Text]

-- | Total private result of one exact Fit-reference assessment.
data CollectiveFitAssessment =
  CollectiveFitAssessment [CollectiveStrategyRealizationIssue] CollectiveFitWork

-- | Deterministic addressed work of one indexed Fit assessment.
data CollectiveFitWork = CollectiveFitWork
  { collectiveFitReferenceBucketProbes :: Int
    -- ^ Exact evidence-reference buckets addressed.
  , collectiveFitResolvedEvidenceOccurrences :: Int
    -- ^ Unambiguous evidence-bundle occurrences inspected.
  , collectiveFitContributorMembershipChecks :: Int
    -- ^ Set-membership checks for coherence and compatibility occurrences.
  , collectiveFitCoherenceOccurrences :: Int
    -- ^ Coherence evidence occurrences inspected in source order.
  , collectiveFitCoherencePairLookups :: Int
    -- ^ Expected canonical pairs addressed in the coherence map.
  , collectiveFitCompatibilityOccurrences :: Int
    -- ^ Contributor-compatibility occurrences inspected in source order.
  , collectiveFitCompatibilityBucketLookups :: Int
    -- ^ Required contributors addressed in the compatibility map.
  } deriving (Eq, Show)

-- | Build all reference and bundle-local indexes exactly once.
buildCollectiveFitIndex :: [RawCollectiveFitEvidence] -> CollectiveFitIndex
buildCollectiveFitIndex evidence =
  CollectiveFitIndex
    (stableBuckets
       (rawFitEvidenceRef . indexedRawFit)
       (map indexCollectiveFit evidence))

-- | Assess one exact evidence reference without scanning unrelated bundles.
assessCollectiveFit ::
     CollectiveFitIndex
  -> [RawNodeId]
  -> RawNodeId
  -> CollectiveFitTargetExpectation
  -> CollectiveFitEvidenceRef
  -> CollectiveFitAssessment
assessCollectiveFit index contributors target expectation evidenceRef =
  case occurrenceBucketCardinality bucket of
    0 ->
      CollectiveFitAssessment
        [CollectiveFitEvidenceNotFound evidenceRef]
        referenceWork
    1 ->
      case occurrenceBucketValues bucket of
        [fit] -> assessIndexedFit contributors target expectation fit
        _ ->
          CollectiveFitAssessment
            [CollectiveFitEvidenceAmbiguous evidenceRef]
            referenceWork
    _ ->
      CollectiveFitAssessment
        [CollectiveFitEvidenceAmbiguous evidenceRef]
        referenceWork
  where
    bucket =
      Map.findWithDefault
        emptyOccurrenceBucket
        evidenceRef
        (indexedFitsByReference index)
    referenceWork = emptyCollectiveFitWork 1

-- | Project issues in the canonical diagnostic order.
collectiveFitAssessmentIssues ::
     CollectiveFitAssessment -> [CollectiveStrategyRealizationIssue]
collectiveFitAssessmentIssues (CollectiveFitAssessment issues _) = issues

-- | Project deterministic indexed work for private scaling contracts.
collectiveFitAssessmentWork :: CollectiveFitAssessment -> CollectiveFitWork
collectiveFitAssessmentWork (CollectiveFitAssessment _ work) = work

assessIndexedFit ::
     [RawNodeId]
  -> RawNodeId
  -> CollectiveFitTargetExpectation
  -> IndexedCollectiveFit
  -> CollectiveFitAssessment
assessIndexedFit contributors target expectation fit =
  CollectiveFitAssessment issues work
  where
    contributorSet = Set.fromList contributors
    coherence = indexedCoherenceInOrder fit
    compatibility = indexedCompatibilityInOrder fit
    expectedPairs = unorderedPairs contributors
    issues =
      participantIssues contributorSet contributors target fit
        ++ coherenceIssues contributorSet expectedPairs fit
        ++ targetExpectationIssues target expectation (indexedRawFit fit)
        ++ compatibilityIssues contributorSet contributors fit
        ++ statementIssues
             ViableInteractionFit
             (rawViableInteractionEvidence (indexedRawFit fit))
    coherenceCardinality = length coherence
    compatibilityCardinality = length compatibility
    work =
      CollectiveFitWork
        { collectiveFitReferenceBucketProbes = 1
        , collectiveFitResolvedEvidenceOccurrences = 1
        , collectiveFitContributorMembershipChecks =
            coherenceCardinality * 2 + compatibilityCardinality
        , collectiveFitCoherenceOccurrences = coherenceCardinality
        , collectiveFitCoherencePairLookups = pairCardinality contributors
        , collectiveFitCompatibilityOccurrences = compatibilityCardinality
        , collectiveFitCompatibilityBucketLookups = length contributors
        }

participantIssues ::
     Set RawNodeId
  -> [RawNodeId]
  -> RawNodeId
  -> IndexedCollectiveFit
  -> [CollectiveStrategyRealizationIssue]
participantIssues contributors contributorOccurrences target fit =
  [ CollectiveFitContributorsMismatch
  | indexedFitContributorSet fit /= contributors
      || indexedFitContributorCardinality fit /= length contributorOccurrences
  ]
    ++ [ CollectiveFitTargetMismatch target (rawFitTarget raw)
       | rawFitTarget raw /= target
       ]
  where
    raw = indexedRawFit fit

coherenceIssues ::
     Set RawNodeId
  -> [CoherencePair]
  -> IndexedCollectiveFit
  -> [CollectiveStrategyRealizationIssue]
coherenceIssues contributors expectedPairs fit =
  invalidPairIssues
    ++ duplicatePairIssues
    ++ missingPairIssues
    ++ blankRationaleIssues
  where
    evidence = indexedCoherenceInOrder fit
    pairBuckets = indexedCoherenceByPair fit
    invalidPairIssues =
      [ InvalidMutualCoherencePair left right
      | item <- evidence
      , let left = rawCoherenceContributorA item
      , let right = rawCoherenceContributorB item
      , left == right
          || Set.notMember left contributors
          || Set.notMember right contributors
      ]
    duplicatePairIssues =
      [ uncurry DuplicateMutualCoherencePair pair
      | (pair, bucket) <- Map.toAscList pairBuckets
      , occurrenceBucketCardinality bucket > 1
      ]
    missingPairIssues =
      [ uncurry MissingMutualCoherencePair pair
      | pair <- expectedPairs
      , Map.notMember pair pairBuckets
      ]
    blankRationaleIssues =
      [ EmptyCollectiveFitEvidence MutualCoherenceFit
      | item <- evidence
      , Text.null (Text.strip (rawCoherenceRationale item))
      ]

targetExpectationIssues ::
     RawNodeId
  -> CollectiveFitTargetExpectation
  -> RawCollectiveFitEvidence
  -> [CollectiveStrategyRealizationIssue]
targetExpectationIssues target expectation fit =
  case expectation of
    MissingCollectiveFitTarget -> [MissingTargetStrategyFormulation target]
    ExpectedCollectiveFitTarget guidingPolicy tradeOffs ->
      [ CollectiveFitGuidingPolicyMismatch
        guidingPolicy
        (rawFitTargetGuidingPolicy fit)
      | rawFitTargetGuidingPolicy fit /= guidingPolicy
      ]
        ++ [ CollectiveFitTradeOffsMismatch
           | rawFitTargetTradeOffs fit /= tradeOffs
           ]

compatibilityIssues ::
     Set RawNodeId
  -> [RawNodeId]
  -> IndexedCollectiveFit
  -> [CollectiveStrategyRealizationIssue]
compatibilityIssues contributors contributorOccurrences fit =
  invalidContributorIssues
    ++ duplicateContributorIssues
    ++ missingContributorIssues
    ++ emptyRationaleIssues
  where
    evidence = indexedCompatibilityInOrder fit
    buckets = indexedCompatibilityByContributor fit
    invalidContributorIssues =
      [ InvalidContributorCompatibilityContributor contributor
      | item <- evidence
      , let contributor = rawCompatibilityContributor item
      , Set.notMember contributor contributors
      ]
    duplicateContributorIssues =
      [ DuplicateContributorCompatibilityContributor contributor
      | (contributor, bucket) <- Map.toAscList buckets
      , occurrenceBucketCardinality bucket > 1
      ]
    missingContributorIssues =
      [ MissingContributorCompatibilityEvidence contributor dimension
      | contributor <- contributorOccurrences
      , Map.notMember contributor buckets
      , dimension <- [GuidingPolicyCompatibilityFit, TradeOffCompatibilityFit]
      ]
    emptyRationaleIssues = concatMap emptyRationales evidence
    emptyRationales item =
      [ EmptyContributorCompatibilityEvidence
        (rawCompatibilityContributor item)
        GuidingPolicyCompatibilityFit
      | Text.null (Text.strip (rawGuidingPolicyCompatibilityRationale item))
      ]
        ++ [ EmptyContributorCompatibilityEvidence
             (rawCompatibilityContributor item)
             TradeOffCompatibilityFit
           | Text.null (Text.strip (rawTradeOffCompatibilityRationale item))
           ]

statementIssues ::
     CollectiveFitDimension -> [Text] -> [CollectiveStrategyRealizationIssue]
statementIssues dimension statements =
  [ EmptyCollectiveFitEvidence dimension
  | null statements || any (Text.null . Text.strip) statements
  ]

indexCollectiveFit :: RawCollectiveFitEvidence -> IndexedCollectiveFit
indexCollectiveFit fit =
  IndexedCollectiveFit
    { indexedRawFit = fit
    , indexedFitContributorSet = Set.fromList (rawFitContributors fit)
    , indexedFitContributorCardinality = length (rawFitContributors fit)
    , indexedCoherenceInOrder = coherence
    , indexedCoherenceByPair =
        stableBuckets
          (\item ->
             canonicalPair
               (rawCoherenceContributorA item)
               (rawCoherenceContributorB item))
          coherence
    , indexedCompatibilityInOrder = compatibility
    , indexedCompatibilityByContributor =
        stableBuckets rawCompatibilityContributor compatibility
    }
  where
    coherence = rawMutualCoherenceEvidence fit
    compatibility = rawContributorCompatibilityEvidence fit

stableBuckets ::
     Ord key => (value -> key) -> [value] -> Map key (OccurrenceBucket value)
stableBuckets keyOf =
  Map.map (occurrenceBucket . reverse)
    . foldl'
        (\buckets value -> Map.insertWith (++) (keyOf value) [value] buckets)
        Map.empty

occurrenceBucket :: [value] -> OccurrenceBucket value
occurrenceBucket values = OccurrenceBucket (length values) values

emptyOccurrenceBucket :: OccurrenceBucket value
emptyOccurrenceBucket = OccurrenceBucket 0 []

emptyCollectiveFitWork :: Int -> CollectiveFitWork
emptyCollectiveFitWork referenceProbes =
  CollectiveFitWork
    { collectiveFitReferenceBucketProbes = referenceProbes
    , collectiveFitResolvedEvidenceOccurrences = 0
    , collectiveFitContributorMembershipChecks = 0
    , collectiveFitCoherenceOccurrences = 0
    , collectiveFitCoherencePairLookups = 0
    , collectiveFitCompatibilityOccurrences = 0
    , collectiveFitCompatibilityBucketLookups = 0
    }

unorderedPairs :: Ord value => [value] -> [(value, value)]
unorderedPairs values =
  [ canonicalPair left right
  | (position, left) <- zip [0 :: Int ..] values
  , right <- drop (position + 1) values
  ]

canonicalPair :: Ord value => value -> value -> (value, value)
canonicalPair left right
  | left <= right = (left, right)
  | otherwise = (right, left)

pairCardinality :: [value] -> Int
pairCardinality values = cardinality * (cardinality - 1) `div` 2
  where
    cardinality = length values
