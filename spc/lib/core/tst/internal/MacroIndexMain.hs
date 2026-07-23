{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.Text as Text
import O2I.Graph.Macro
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Relation
import Test.Tasty
import Test.Tasty.HUnit
import qualified Test.Tasty.QuickCheck as QC

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "private macro index contract"
    [ testCase "exact claim lookup addresses only its occurrence bucket"
        $ withAddressedClaim (sparseMacroIndexWith 1000)
        $ \index claim -> do
            macroLookupClaimOccurrences
              (macroClaimLookupWork
                 index
                 macroEthosId
                 (FixedRelation GuidesMissionCode)
                 macroMissionId)
              @?= 1
            map macroDependencyEdge (macroScopeDependencies index claim)
              @?= [2 :: Int]
    , testCase "sparse facts do not increase addressed premise work"
        $ withAddressedClaim baseMacroIndex
        $ \baseIndex baseClaim ->
            withAddressedClaim (sparseMacroIndexWith 1000) $ \sparseIndex sparseClaim -> do
              macroScopeDependencyWork sparseIndex sparseClaim
                @?= macroScopeDependencyWork baseIndex baseClaim
              macroLookupNodeOccurrences
                (macroScopeDependencyWork sparseIndex sparseClaim)
                @?= 2
              macroLookupEdgeBucketProbes
                (macroScopeDependencyWork sparseIndex sparseClaim)
                @?= 2
              macroLookupEdgeOccurrences
                (macroScopeDependencyWork sparseIndex sparseClaim)
                @?= 1
    , QC.testProperty "addressed work is invariant under unrelated claims" $ \(QC.NonNegative rawCount) ->
        let sparseSize = rawCount `mod` 200
         in addressedContract (sparseMacroIndexWith sparseSize)
              == addressedContract baseMacroIndex
    , testCase "degree skew selects the lower-occurrence target adjacency"
        $ withAddressedClaim (denseMacroIndex 1 2 1000 0)
        $ \index claim -> do
            let work = macroScopeDependencyWork index claim
            macroLookupNodeOccurrences work @?= 3
            macroLookupEdgeBucketProbes work @?= 3
            macroLookupEdgeOccurrences work @?= 3
            map macroDependencyEdge (macroScopeDependencies index claim)
              @?= [91, 17, 44 :: Int]
    , testCase "degree skew selects the lower-occurrence source adjacency"
        $ withAddressedClaim (denseMacroIndex 2 1 0 1000)
        $ \index claim -> do
            let work = macroScopeDependencyWork index claim
            macroLookupNodeOccurrences work @?= 3
            macroLookupEdgeBucketProbes work @?= 3
            macroLookupEdgeOccurrences work @?= 3
            map macroDependencyEdge (macroScopeDependencies index claim)
              @?= [91, 17, 44 :: Int]
    , testCase "visited work includes filtered selected-side occurrences"
        $ withAddressedClaim (denseMacroIndex 3 40 8 20)
        $ \index claim -> do
            let work = macroScopeDependencyWork index claim
            macroLookupNodeOccurrences work @?= 43
            macroLookupEdgeBucketProbes work @?= 43
            macroLookupEdgeOccurrences work @?= 11
            map macroDependencyEdge (macroScopeDependencies index claim)
              @?= [91, 17, 44 :: Int]
    , QC.testProperty
        "dense selector lookup scales with the lower occurrence degree" $ \(QC.Positive rawSources) (QC.Positive rawTargets) (QC.NonNegative rawSourceDecoys) (QC.NonNegative rawTargetDecoys) ->
        let sourceCount = 1 + rawSources `mod` 60
            targetCount = 1 + rawTargets `mod` 60
            sourceDecoys = rawSourceDecoys `mod` 40
            targetDecoys = rawTargetDecoys `mod` 40
         in case addressedContract
                   (denseMacroIndex
                      sourceCount
                      targetCount
                      sourceDecoys
                      targetDecoys) of
              Nothing -> QC.counterexample "missing addressed dense claim" False
              Just (work, dependencies) ->
                QC.conjoin
                  [ macroLookupNodeOccurrences work QC.=== sourceCount
                      + targetCount
                  , macroLookupEdgeBucketProbes work QC.=== sourceCount
                      + targetCount
                  , macroLookupEdgeOccurrences work QC.=== 3
                      + min sourceDecoys targetDecoys
                  , dependencies QC.=== [91, 17, 44]
                  ]
    ]

addressedContract :: MacroFactIndex Int Int -> Maybe (MacroLookupWork, [Int])
addressedContract index = do
  claim <- addressedClaim index
  pure
    ( macroScopeDependencyWork index claim
    , map macroDependencyEdge (macroScopeDependencies index claim))

withAddressedClaim ::
     MacroFactIndex Int Int
  -> (MacroFactIndex Int Int -> MacroClaim Int -> Assertion)
  -> Assertion
withAddressedClaim index action =
  case addressedClaim index of
    Just claim -> action index claim
    Nothing -> assertFailure "expected exactly one addressed macro claim"

addressedClaim :: MacroFactIndex Int Int -> Maybe (MacroClaim Int)
addressedClaim index =
  case macroClaimsFor
         index
         macroEthosId
         (FixedRelation GuidesMissionCode)
         macroMissionId of
    [(_, claim)] -> Just claim
    _ -> Nothing

baseMacroIndex :: MacroFactIndex Int Int
baseMacroIndex =
  buildMacroFactIndex
    macroTestNodes
    [(1, macroTestClaim), (2, macroTestPremise)]

sparseMacroIndexWith :: Int -> MacroFactIndex Int Int
sparseMacroIndexWith sparseSize =
  buildMacroFactIndex
    (macroTestNodes ++ concatMap unrelatedNodes [1 .. sparseSize])
    ([(1, macroTestClaim), (2, macroTestPremise)]
       ++ map unrelatedClaim [1 .. sparseSize])
  where
    unrelatedNodes ordinal =
      [ (1000 + ordinal * 2, RawContextNode (unrelatedEthosId ordinal) Ethos)
      , ( 1001 + ordinal * 2
        , RawContextNode (unrelatedMissionId ordinal) Mission)
      ]
    unrelatedClaim ordinal =
      ( 10000 + ordinal
      , relationEdge
          (unrelatedEthosId ordinal)
          guidesMission
          (unrelatedMissionId ordinal))

denseMacroIndex :: Int -> Int -> Int -> Int -> MacroFactIndex Int Int
denseMacroIndex sourceCount targetCount sourceDecoys targetDecoys =
  buildMacroFactIndex nodes edges
  where
    sourceIds = map denseSourceId [1 .. sourceCount]
    targetIds = map denseTargetId [1 .. targetCount]
    externalSourceIds = map denseExternalSourceId [1 .. targetDecoys]
    externalTargetIds = map denseExternalTargetId [1 .. sourceDecoys]
    nodes =
      [ (1, RawContextNode macroEthosId Ethos)
      , (2, RawContextNode macroMissionId Mission)
      , (3, RawContextNode denseExternalEthosId Ethos)
      , (4, RawContextNode denseExternalMissionId Mission)
      ]
        ++ zipWith
             (\occurrence identifier ->
                (occurrence, RawPrimitiveNode identifier macroEthosId Principle))
             [100 ..]
             sourceIds
        ++ zipWith
             (\occurrence identifier ->
                (occurrence, RawPrimitiveNode identifier macroMissionId Driver))
             [1000 ..]
             targetIds
        ++ zipWith
             (\occurrence identifier ->
                ( occurrence
                , RawPrimitiveNode identifier denseExternalEthosId Principle))
             [2000 ..]
             externalSourceIds
        ++ zipWith
             (\occurrence identifier ->
                ( occurrence
                , RawPrimitiveNode identifier denseExternalMissionId Driver))
             [3000 ..]
             externalTargetIds
    edges =
      [ (1, macroTestClaim)
      , (91, densePremise (last sourceIds) (last targetIds))
      , (17, densePremise (head sourceIds) (head targetIds))
      , (44, densePremise (head sourceIds) (head targetIds))
      ]
        ++ zipWith
             (\occurrence target ->
                (occurrence, densePremise (head sourceIds) target))
             [4000 ..]
             externalTargetIds
        ++ zipWith
             (\occurrence source ->
                (occurrence, densePremise source (head targetIds)))
             [5000 ..]
             externalSourceIds

densePremise :: RawNodeId -> RawNodeId -> RawEdge
densePremise source target =
  relationEdge source guidesEthosPrincipleToMissionDriver target

denseSourceId :: Int -> RawNodeId
denseSourceId ordinal =
  RawNodeId ("dense-principle-" <> Text.pack (show ordinal))

denseTargetId :: Int -> RawNodeId
denseTargetId ordinal = RawNodeId ("dense-driver-" <> Text.pack (show ordinal))

denseExternalSourceId :: Int -> RawNodeId
denseExternalSourceId ordinal =
  RawNodeId ("external-principle-" <> Text.pack (show ordinal))

denseExternalTargetId :: Int -> RawNodeId
denseExternalTargetId ordinal =
  RawNodeId ("external-driver-" <> Text.pack (show ordinal))

denseExternalEthosId, denseExternalMissionId :: RawNodeId
denseExternalEthosId = RawNodeId "dense-external-ethos"

denseExternalMissionId = RawNodeId "dense-external-mission"

macroTestNodes :: [(Int, RawNode)]
macroTestNodes =
  [ (1, RawContextNode macroEthosId Ethos)
  , (2, RawContextNode macroMissionId Mission)
  , (3, RawPrimitiveNode macroPrincipleId macroEthosId Principle)
  , (4, RawPrimitiveNode macroDriverId macroMissionId Driver)
  ]

macroTestClaim :: RawEdge
macroTestClaim = relationEdge macroEthosId guidesMission macroMissionId

macroTestPremise :: RawEdge
macroTestPremise =
  relationEdge
    macroPrincipleId
    guidesEthosPrincipleToMissionDriver
    macroDriverId

relationEdge :: RawNodeId -> Relation from to -> RawNodeId -> RawEdge
relationEdge from relation to =
  RawEdge from (relationName (relationSpec relation)) to

unrelatedEthosId :: Int -> RawNodeId
unrelatedEthosId ordinal =
  RawNodeId ("unrelated-ethos-" <> Text.pack (show ordinal))

unrelatedMissionId :: Int -> RawNodeId
unrelatedMissionId ordinal =
  RawNodeId ("unrelated-mission-" <> Text.pack (show ordinal))

macroEthosId, macroMissionId, macroPrincipleId, macroDriverId :: RawNodeId
macroEthosId = RawNodeId "macro-ethos"

macroMissionId = RawNodeId "macro-mission"

macroPrincipleId = RawNodeId "macro-principle"

macroDriverId = RawNodeId "macro-driver"
