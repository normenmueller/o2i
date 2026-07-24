{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Text as Text
import O2I.Language.Element
import O2I.Validation.Collective.Fit
import O2I.Validation.Collective.Types
import O2I.Validation.Semantics.Context.TradeOffSet
import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "private collective Fit index contract"
    [ testCase
        "exact reference work is invariant under unrelated bundles"
        exactReferenceContract
    , testCase
        "large collective addresses canonical pairs and contributors once"
        largeCollectiveContract
    , QC.testProperty
        "collective work follows quadratic pairs and linear compatibility"
        collectiveScalingProperty
    , testCase
        "Fit diagnostics retain source and canonical pair order"
        diagnosticOrderContract
    ]

exactReferenceContract :: Assertion
exactReferenceContract = do
  let contributors = contributorIds 2
      selected = completeFit selectedReference contributors
      base =
        assess
          (buildCollectiveFitIndex [selected])
          contributors
          selectedReference
      sparse =
        assess
          (buildCollectiveFitIndex (map unrelatedFit [1 .. 2000] ++ [selected]))
          contributors
          selectedReference
  collectiveFitAssessmentIssues base @?= []
  collectiveFitAssessmentIssues sparse @?= []
  collectiveFitAssessmentWork sparse @?= collectiveFitAssessmentWork base
  collectiveFitReferenceBucketProbes (collectiveFitAssessmentWork sparse) @?= 1
  collectiveFitResolvedEvidenceOccurrences (collectiveFitAssessmentWork sparse)
    @?= 1

largeCollectiveContract :: Assertion
largeCollectiveContract = do
  let cardinality = 100
      contributors = contributorIds cardinality
      assessment =
        assess
          (buildCollectiveFitIndex [completeFit selectedReference contributors])
          contributors
          selectedReference
      work = collectiveFitAssessmentWork assessment
      pairs = pairCardinality cardinality
  collectiveFitAssessmentIssues assessment @?= []
  collectiveFitReferenceBucketProbes work @?= 1
  collectiveFitResolvedEvidenceOccurrences work @?= 1
  collectiveFitContributorMembershipChecks work @?= pairs * 2 + cardinality
  collectiveFitCoherenceOccurrences work @?= pairs
  collectiveFitCoherencePairLookups work @?= pairs
  collectiveFitCompatibilityOccurrences work @?= cardinality
  collectiveFitCompatibilityBucketLookups work @?= cardinality

collectiveScalingProperty :: QC.Positive Int -> QC.Property
collectiveScalingProperty (QC.Positive rawCardinality) =
  let cardinality = 2 + rawCardinality `mod` 50
      contributors = contributorIds cardinality
      assessment =
        assess
          (buildCollectiveFitIndex [completeFit selectedReference contributors])
          contributors
          selectedReference
      work = collectiveFitAssessmentWork assessment
      pairs = pairCardinality cardinality
   in QC.conjoin
        [ collectiveFitAssessmentIssues assessment QC.=== []
        , collectiveFitReferenceBucketProbes work QC.=== 1
        , collectiveFitResolvedEvidenceOccurrences work QC.=== 1
        , collectiveFitContributorMembershipChecks work QC.=== pairs * 2
            + cardinality
        , collectiveFitCoherenceOccurrences work QC.=== pairs
        , collectiveFitCoherencePairLookups work QC.=== pairs
        , collectiveFitCompatibilityOccurrences work QC.=== cardinality
        , collectiveFitCompatibilityBucketLookups work QC.=== cardinality
        ]

diagnosticOrderContract :: Assertion
diagnosticOrderContract = do
  let contributorA = RawNodeId "a"
      contributorB = RawNodeId "b"
      contributorC = RawNodeId "c"
      external = RawNodeId "external"
      contributors = [contributorB, contributorA, contributorC]
      evidence =
        (completeFit selectedReference contributors)
          { rawMutualCoherenceEvidence =
              [ RawMutualCoherenceEvidence external contributorB " "
              , RawMutualCoherenceEvidence
                  contributorC
                  contributorC
                  "Self-coherence is invalid."
              , RawMutualCoherenceEvidence
                  contributorB
                  contributorA
                  "The pair is coherent."
              , RawMutualCoherenceEvidence
                  contributorA
                  contributorB
                  "The duplicate is coherent."
              ]
          }
      assessment =
        assess
          (buildCollectiveFitIndex [evidence])
          contributors
          selectedReference
  collectiveFitAssessmentIssues assessment
    @?= [ InvalidMutualCoherencePair external contributorB
        , InvalidMutualCoherencePair contributorC contributorC
        , DuplicateMutualCoherencePair contributorA contributorB
        , MissingMutualCoherencePair contributorB contributorC
        , MissingMutualCoherencePair contributorA contributorC
        , EmptyCollectiveFitEvidence MutualCoherenceFit
        ]

assess ::
     CollectiveFitIndex
  -> [RawNodeId]
  -> CollectiveFitEvidenceRef
  -> CollectiveFitAssessment
assess index contributors reference =
  assessCollectiveFit
    index
    contributors
    targetId
    (ExpectedCollectiveFitTarget targetPolicyId targetTradeOffs)
    reference

completeFit ::
     CollectiveFitEvidenceRef -> [RawNodeId] -> RawCollectiveFitEvidence
completeFit reference contributors =
  RawCollectiveFitEvidence
    { rawFitEvidenceRef = reference
    , rawFitContributors = contributors
    , rawFitTarget = targetId
    , rawMutualCoherenceEvidence =
        [ RawMutualCoherenceEvidence
          left
          right
          "The contributor pair is mutually coherent."
        | (left, right) <- unorderedPairs contributors
        ]
    , rawFitTargetGuidingPolicy = targetPolicyId
    , rawFitTargetTradeOffs = NonEmpty.toList targetTradeOffInput
    , rawContributorCompatibilityEvidence =
        [ RawContributorCompatibilityEvidence
          contributor
          "The contributor follows the target Guiding Policy."
          "The contributor respects the target Trade-offs."
        | contributor <- contributors
        ]
    , rawViableInteractionEvidence =
        ["The contributor interactions are jointly viable."]
    }

unrelatedFit :: Int -> RawCollectiveFitEvidence
unrelatedFit ordinal =
  completeFit
    (CollectiveFitEvidenceRef ("unrelated-fit-" <> Text.pack (show ordinal)))
    [ RawNodeId ("unrelated-a-" <> Text.pack (show ordinal))
    , RawNodeId ("unrelated-b-" <> Text.pack (show ordinal))
    ]

contributorIds :: Int -> [RawNodeId]
contributorIds cardinality =
  [ RawNodeId ("contributor-" <> Text.pack (show ordinal))
  | ordinal <- [1 .. cardinality]
  ]

unorderedPairs :: [value] -> [(value, value)]
unorderedPairs values =
  [ (left, right)
  | (position, left) <- zip [0 :: Int ..] values
  , right <- drop (position + 1) values
  ]

pairCardinality :: Int -> Int
pairCardinality cardinality = cardinality * (cardinality - 1) `div` 2

selectedReference :: CollectiveFitEvidenceRef
selectedReference = CollectiveFitEvidenceRef "selected-fit"

targetId, targetPolicyId :: RawNodeId
targetId = RawNodeId "target"

targetPolicyId = RawNodeId "target-policy"

targetTradeOffs :: TradeOffSet
targetTradeOffs = validatedTradeOffSet targetTradeOffInput

targetTradeOffInput :: NonEmpty Text.Text
targetTradeOffInput = "Target trade-off" :| []
