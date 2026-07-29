{-# LANGUAGE OverloadedStrings #-}

-- | Deterministic unit contracts for the constructive relational evaluator.
module O2I.Validation.Relational.Test.Contracts
  ( tests
  ) where

import Data.List (nub, sort)
import Data.Text (Text)
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Test.Fixture
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

tests :: TestTree
tests =
  testGroup
    "constructive evaluator contracts"
    [ testCase "accounts for index construction exactly" exactIndexBuildWork
    , testCase "joins three connected axes without pair products" multiAxisJoin
    , testCase "rejects inconsistent siblings before occurrences" deadEndJoin
    , testCase "retains distinct exact edge occurrences" distinctOccurrences
    , testCase "emits declaration-ordered canonical rows" canonicalOrder
    , testCase "is invariant under graph input permutation" permutationInvariant
    , testCase "exists agrees with non-empty enumeration" existsEnumerateLaw
    , testCase "exists short-circuits before full enumeration" shortCircuit
    , testCase "reports truthful occurrence work" truthfulOccurrenceWork
    ]

exactIndexBuildWork :: IO ()
exactIndexBuildWork = do
  let graph =
        graphFrom
          [ contextNode "s" SStrategy
          , contextNode "i" SIntervention
          , contextNode "n" SNeed
          ]
          [ relationEdge "s" directsIntervention "i"
          , relationEdge "i" addressesNeed "n"
          ]
      work = indexBuildWork (buildRelationalIndex graph)
  work
    @?= IndexBuildWork
          { buildNodesRead = 3
          , buildNodeDomainInsertions = 3
          , buildEdgesRead = 2
          , buildCanonicalOccurrencesAssigned = 2
          , buildProjectionInsertions = 2
          , buildExactOccurrenceInsertions = 2
          , buildRelationProjectionsCreated = 2
          }

multiAxisJoin :: IO ()
multiAxisJoin = do
  let index = buildRelationalIndex matchingGraph
      Evaluation rows work = runEnumerate index (trianglePlan index)
  length rows @?= 4
  map (map relationOf . rowSignature) rows
    @?= replicate
          4
          [ FixedRelation DirectsInterventionCode
          , FixedRelation AddressesNeedCode
          , FixedRelation QualifiesNeedCode
          ]
  workCompleteNodeBindings work @?= 4
  workResultsEmitted work @?= 4
  where
    relationOf (_, relation, _, _) = relation

deadEndJoin :: IO ()
deadEndJoin = do
  let index = buildRelationalIndex inconsistentGraph
      Evaluation rows work = runEnumerate index (trianglePlan index)
  null rows @?= True
  workCompleteNodeBindings work @?= 0
  workExactOccurrenceReads work @?= 0
  workResultsEmitted work @?= 0

distinctOccurrences :: IO ()
distinctOccurrences = do
  let index = buildRelationalIndex duplicateGraph
      Evaluation rows work = runEnumerate index (qualificationPlan index)
      ordinals = concatMap (map fourth . rowSignature) rows
  length rows @?= 2
  length (nub ordinals) @?= 2
  workExactOccurrenceReads work @?= 2
  workResultsEmitted work @?= 2
  where
    fourth (_, _, _, ordinal) = ordinal

canonicalOrder :: IO ()
canonicalOrder = do
  let index = buildRelationalIndex unorderedGraph
      Evaluation rows _ = runEnumerate index (trianglePlan index)
      signatures = map rowSignature rows
  signatures @?= sort signatures

permutationInvariant :: IO ()
permutationInvariant = do
  let nodes = graphNodes unorderedGraph
      edges = graphEdges unorderedGraph
      forwardIndex = buildRelationalIndex (graphFrom nodes edges)
      reverseIndex =
        buildRelationalIndex (graphFrom (reverse nodes) (reverse edges))
      forward = runEnumerate forwardIndex (trianglePlan forwardIndex)
      reversed = runEnumerate reverseIndex (trianglePlan reverseIndex)
  map rowSignature (evaluationResult forward)
    @?= map rowSignature (evaluationResult reversed)
  evaluationWork forward @?= evaluationWork reversed
  indexBuildWork forwardIndex @?= indexBuildWork reverseIndex

existsEnumerateLaw :: IO ()
existsEnumerateLaw =
  mapM_ check [matchingGraph, inconsistentGraph, unorderedGraph, emptyGraph]
  where
    check graph = do
      let index = buildRelationalIndex graph
          plan = trianglePlan index
      evaluationResult (runExists index plan)
        @?= not (null (evaluationResult (runEnumerate index plan)))

shortCircuit :: IO ()
shortCircuit = do
  let index = buildRelationalIndex matchingGraph
      plan = trianglePlan index
      Evaluation found existsWork = runExists index plan
      Evaluation rows enumerateWork = runEnumerate index plan
  found @?= True
  assertBool "fixture must contain multiple rows" (length rows > 1)
  workResultsEmitted existsWork @?= 0
  assertBool
    "existence mode did not short-circuit exact occurrence reads"
    (workExactOccurrenceReads existsWork
       < workExactOccurrenceReads enumerateWork)

truthfulOccurrenceWork :: IO ()
truthfulOccurrenceWork = do
  let index = buildRelationalIndex matchingGraph
      Evaluation rows work = runEnumerate index (trianglePlan index)
      premiseCount = 3 * length rows
  workEdgeBucketProbes work @?= premiseCount
  workExactOccurrenceReads work @?= premiseCount
  workResultsEmitted work @?= length rows

matchingGraph :: WellFormedGraph
matchingGraph =
  graphFrom
    triangleNodes
    (directEdges
       ++ qualifyEdges
       ++ zipWith
            (\intervention need -> relationEdge intervention addressesNeed need)
            interventionNames
            needNames)

inconsistentGraph :: WellFormedGraph
inconsistentGraph =
  graphFrom
    (contextNode "n-x" SNeed : triangleNodes)
    (directEdges
       ++ qualifyEdges
       ++ [ relationEdge intervention addressesNeed "n-x"
          | intervention <- interventionNames
          ])

duplicateGraph :: WellFormedGraph
duplicateGraph =
  graphFrom
    [contextNode "s" SStrategy, contextNode "n" SNeed]
    [relationEdge "s" qualifiesNeed "n", relationEdge "s" qualifiesNeed "n"]

unorderedGraph :: WellFormedGraph
unorderedGraph =
  graphFrom
    [ contextNode "n-b" SNeed
    , contextNode "i-b" SIntervention
    , contextNode "s" SStrategy
    , contextNode "n-a" SNeed
    , contextNode "i-a" SIntervention
    ]
    [ relationEdge "i-b" addressesNeed "n-b"
    , relationEdge "s" qualifiesNeed "n-b"
    , relationEdge "s" directsIntervention "i-b"
    , relationEdge "i-a" addressesNeed "n-a"
    , relationEdge "s" qualifiesNeed "n-a"
    , relationEdge "s" directsIntervention "i-a"
    ]

emptyGraph :: WellFormedGraph
emptyGraph = graphFrom [] []

triangleNodes :: [SomeNode]
triangleNodes =
  contextNode "s" SStrategy
    : [contextNode name SIntervention | name <- interventionNames]
    ++ [contextNode name SNeed | name <- needNames]

interventionNames :: [Text]
interventionNames = ["i-1", "i-2", "i-3", "i-4"]

needNames :: [Text]
needNames = ["n-1", "n-2", "n-3", "n-4"]

directEdges :: [SomeEdge]
directEdges =
  [ relationEdge "s" directsIntervention intervention
  | intervention <- interventionNames
  ]

qualifyEdges :: [SomeEdge]
qualifyEdges = [relationEdge "s" qualifiesNeed need | need <- needNames]
