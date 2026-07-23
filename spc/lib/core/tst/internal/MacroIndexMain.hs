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
              macroLookupEdgeOccurrences
                (macroScopeDependencyWork sparseIndex sparseClaim)
                @?= 1
    , QC.testProperty "addressed work is invariant under unrelated claims" $ \(QC.NonNegative rawCount) ->
        let sparseSize = rawCount `mod` 200
         in addressedContract (sparseMacroIndexWith sparseSize)
              == addressedContract baseMacroIndex
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
