{-# LANGUAGE OverloadedStrings #-}

-- | Independent size and shape contracts for constructive evaluation.
module O2I.Validation.Relational.Test.Matrix
  ( tests
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Test.Fixture
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

data Shape
  = Sparse
  | Skew
  | Dense
  | DeadEnd
  | Unrelated
  | OutputHeavy
  deriving (Bounded, Enum, Eq, Show)

tests :: TestTree
tests =
  testGroup
    "size and shape matrix"
    [ testGroup
      ("size " ++ show size)
      [ testGroup
          "two-axis"
          [testCase (show shape) $ twoAxisContract size shape | shape <- shapes]
      , testGroup
          "three-axis"
          [ testCase (show shape) $ threeAxisContract size shape
          | shape <- shapes
          ]
      ]
    | size <- [0, 10, 20, 40]
    ]
  where
    shapes = [minBound .. maxBound]

twoAxisContract :: Int -> Shape -> IO ()
twoAxisContract size shape = do
  let (graph, expected) = twoAxisScenario size shape
      index = buildRelationalIndex graph
      Evaluation rows work = runEnumerate index (qualificationPlan index)
      Evaluation found _ = runExists index (qualificationPlan index)
  length rows @?= expected
  found @?= (expected > 0)
  workCompleteNodeBindings work @?= expected
  workEdgeBucketProbes work @?= expected
  workExactOccurrenceReads work @?= expected
  workResultsEmitted work @?= expected
  assertDeadEndBound size shape work

threeAxisContract :: Int -> Shape -> IO ()
threeAxisContract size shape = do
  let (graph, expected) = threeAxisScenario size shape
      index = buildRelationalIndex graph
      Evaluation rows work = runEnumerate index (trianglePlan index)
      Evaluation found _ = runExists index (trianglePlan index)
  length rows @?= expected
  found @?= (expected > 0)
  workCompleteNodeBindings work @?= expected
  workEdgeBucketProbes work @?= expected * 3
  workExactOccurrenceReads work @?= expected * 3
  workResultsEmitted work @?= expected
  assertDeadEndBound size shape work

assertDeadEndBound :: Int -> Shape -> EvaluationWork -> IO ()
assertDeadEndBound size shape work
  | shape /= DeadEnd = pure ()
  | otherwise = do
    workCompleteNodeBindings work @?= 0
    workResultsEmitted work @?= 0
    assertBool
      "dead-end traversal exceeded its affine candidate bound"
      (workDomainValuesVisited work <= 2 * size + 1)

twoAxisScenario :: Int -> Shape -> (WellFormedGraph, Int)
twoAxisScenario size shape =
  case shape of
    Sparse -> pairwise size
    Skew ->
      let needs = names "n" size
       in ( graphFrom
              (contextNode "s" SStrategy : contextNodes SNeed needs)
              [relationEdge "s" qualifiesNeed need | need <- needs]
          , size)
    Dense -> denseTwo size size
    DeadEnd ->
      ( graphFrom
          (contextNodes SStrategy (names "s" size)
             ++ contextNodes SNeed (names "n" size))
          []
      , 0)
    Unrelated ->
      let (graph, expected) = pairwise size
       in ( graphFrom
              (graphNodes graph ++ contextNodes SNeed (names "unrelated" size))
              (graphEdges graph)
          , expected)
    OutputHeavy -> denseTwo size (2 * size)
  where
    pairwise count =
      let strategies = names "s" count
          needs = names "n" count
       in ( graphFrom
              (contextNodes SStrategy strategies ++ contextNodes SNeed needs)
              (zipRelations strategies qualifiesNeed needs)
          , count)
    denseTwo strategiesCount needsCount =
      let strategies = names "s" strategiesCount
          needs = names "n" needsCount
       in ( graphFrom
              (contextNodes SStrategy strategies ++ contextNodes SNeed needs)
              [ relationEdge strategy qualifiesNeed need
              | strategy <- strategies
              , need <- needs
              ]
          , strategiesCount * needsCount)

threeAxisScenario :: Int -> Shape -> (WellFormedGraph, Int)
threeAxisScenario size shape =
  case shape of
    Sparse -> paired size
    Skew ->
      let interventions = names "i" size
          needs = names "n" size
       in ( graphFrom
              (triangleContextNodes ["s"] interventions needs)
              ([ relationEdge "s" directsIntervention intervention
               | intervention <- interventions
               ]
                 ++ zipRelations interventions addressesNeed needs
                 ++ [relationEdge "s" qualifiesNeed need | need <- needs])
          , size)
    Dense -> denseThree size
    DeadEnd ->
      let interventions = names "i" size
          needs = names "n" size
          deadNeeds = names "dead" size
       in ( graphFrom
              (triangleContextNodes ["s"] interventions (needs ++ deadNeeds))
              ([ relationEdge "s" directsIntervention intervention
               | intervention <- interventions
               ]
                 ++ zipRelations interventions addressesNeed deadNeeds
                 ++ [relationEdge "s" qualifiesNeed need | need <- needs])
          , 0)
    Unrelated ->
      let (graph, expected) = paired size
       in ( graphFrom
              (graphNodes graph
                 ++ contextNodes SIntervention (names "unrelated" size))
              (graphEdges graph)
          , expected)
    OutputHeavy -> outputHeavyThree size
  where
    paired count =
      let strategies = names "s" count
          interventions = names "i" count
          needs = names "n" count
       in ( graphFrom
              (triangleContextNodes strategies interventions needs)
              (zipRelations strategies directsIntervention interventions
                 ++ zipRelations interventions addressesNeed needs
                 ++ zipRelations strategies qualifiesNeed needs)
          , count)
    denseThree count =
      let strategies = names "s" count
          interventions = names "i" count
          needs = names "n" count
       in ( graphFrom
              (triangleContextNodes strategies interventions needs)
              ([ relationEdge strategy directsIntervention intervention
               | strategy <- strategies
               , intervention <- interventions
               ]
                 ++ [ relationEdge intervention addressesNeed need
                    | intervention <- interventions
                    , need <- needs
                    ]
                 ++ [ relationEdge strategy qualifiesNeed need
                    | strategy <- strategies
                    , need <- needs
                    ])
          , count * count * count)
    outputHeavyThree count =
      let interventions = names "i" count
          needs = names "n" count
       in ( graphFrom
              (triangleContextNodes ["s"] interventions needs)
              ([ relationEdge "s" directsIntervention intervention
               | intervention <- interventions
               ]
                 ++ [ relationEdge intervention addressesNeed need
                    | intervention <- interventions
                    , need <- needs
                    ]
                 ++ [relationEdge "s" qualifiesNeed need | need <- needs])
          , count * count)

triangleContextNodes :: [Text] -> [Text] -> [Text] -> [SomeNode]
triangleContextNodes strategies interventions needs =
  contextNodes SStrategy strategies
    ++ contextNodes SIntervention interventions
    ++ contextNodes SNeed needs

contextNodes :: SContext context -> [Text] -> [SomeNode]
contextNodes context = map (`contextNode` context)

zipRelations :: [Text] -> Relation from to -> [Text] -> [SomeEdge]
zipRelations sources relation targets =
  zipWith
    (\source target -> relationEdge source relation target)
    sources
    targets

names :: Text -> Int -> [Text]
names prefix size =
  [prefix <> "-" <> Text.pack (show ordinal) | ordinal <- [1 .. size]]
