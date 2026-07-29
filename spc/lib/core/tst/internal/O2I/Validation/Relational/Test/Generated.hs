{-# LANGUAGE OverloadedStrings #-}

-- | Generated connected plans checked against independent naive oracles.
module O2I.Validation.Relational.Test.Generated
  ( tests
  ) where

import Data.List (sort, sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Eval
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Test.Fixture
import Test.Tasty (TestTree, testGroup)
import qualified Test.Tasty.QuickCheck as QC

data GraphSpec = GraphSpec
  { strategyCount :: Int
  , interventionCount :: Int
  , needCount :: Int
  , directsPairs :: [(Int, Int)]
  , addressesPairs :: [(Int, Int)]
  , qualifiesPairs :: [(Int, Int)]
  } deriving (Eq, Show)

tests :: TestTree
tests =
  testGroup
    "generated complete-registry oracle contracts"
    [ QC.testProperty
        "two-axis results agree with the naive oracle"
        (QC.withMaxSuccess 200 qualificationOracleProperty)
    , QC.testProperty
        "three-axis results agree with the naive oracle"
        (QC.withMaxSuccess 200 triangleOracleProperty)
    ]

qualificationOracleProperty :: QC.Property
qualificationOracleProperty =
  QC.forAll graphSpec $ \spec ->
    let index = buildRelationalIndex (materialize spec)
        actual =
          sort
            (map
               rowSignature
               (evaluationResult (runEnumerate index (qualificationPlan index))))
        expected = qualificationOracle spec
        exists = evaluationResult (runExists index (qualificationPlan index))
     in QC.counterexample (show spec)
          $ QC.conjoin
              [actual QC.=== expected, exists QC.=== not (null expected)]

triangleOracleProperty :: QC.Property
triangleOracleProperty =
  QC.forAll graphSpec $ \spec ->
    let index = buildRelationalIndex (materialize spec)
        actual =
          sort
            (map
               rowSignature
               (evaluationResult (runEnumerate index (trianglePlan index))))
        expected = triangleOracle spec
        exists = evaluationResult (runExists index (trianglePlan index))
     in QC.counterexample (show spec)
          $ QC.conjoin
              [actual QC.=== expected, exists QC.=== not (null expected)]

graphSpec :: QC.Gen GraphSpec
graphSpec = do
  strategies <- QC.chooseInt (0, 4)
  interventions <- QC.chooseInt (0, 4)
  needs <- QC.chooseInt (0, 4)
  directs <-
    QC.sublistOf
      [ (strategy, intervention)
      | strategy <- indices strategies
      , intervention <- indices interventions
      ]
  addresses <-
    QC.sublistOf
      [ (intervention, need)
      | intervention <- indices interventions
      , need <- indices needs
      ]
  qualifies <-
    QC.sublistOf
      [(strategy, need) | strategy <- indices strategies, need <- indices needs]
  pure
    GraphSpec
      { strategyCount = strategies
      , interventionCount = interventions
      , needCount = needs
      , directsPairs = directs
      , addressesPairs = addresses
      , qualifiesPairs = qualifies
      }

materialize :: GraphSpec -> WellFormedGraph
materialize spec =
  graphFrom
    ([ contextNode (strategyName strategy) SStrategy
     | strategy <- indices (strategyCount spec)
     ]
       ++ [ contextNode (interventionName intervention) SIntervention
          | intervention <- indices (interventionCount spec)
          ]
       ++ [contextNode (needName need) SNeed | need <- indices (needCount spec)])
    ([ relationEdge
       (strategyName strategy)
       directsIntervention
       (interventionName intervention)
     | (strategy, intervention) <- directsPairs spec
     ]
       ++ [ relationEdge
            (interventionName intervention)
            addressesNeed
            (needName need)
          | (intervention, need) <- addressesPairs spec
          ]
       ++ [ relationEdge (strategyName strategy) qualifiesNeed (needName need)
          | (strategy, need) <- qualifiesPairs spec
          ])

qualificationOracle ::
     GraphSpec -> [[(RawNodeId, RelationCode, RawNodeId, Int)]]
qualificationOracle spec =
  [ [ canonicalOccurrence
        spec
        (FixedRelation QualifiesNeedCode)
        (rawId (strategyName strategy))
        (rawId (needName need))
    ]
  | (strategy, need) <- qualifiesPairs spec
  ]

triangleOracle :: GraphSpec -> [[(RawNodeId, RelationCode, RawNodeId, Int)]]
triangleOracle spec =
  sort
    [ [ directsOccurrence strategy intervention
      , addressesOccurrence intervention need
      , qualifiesOccurrence strategy need
      ]
    | (strategy, intervention) <- directsPairs spec
    , (addressingIntervention, need) <- addressesPairs spec
    , addressingIntervention == intervention
    , (qualifyingStrategy, qualifiedNeed) <- qualifiesPairs spec
    , qualifyingStrategy == strategy
    , qualifiedNeed == need
    ]
  where
    directsOccurrence strategy intervention =
      canonicalOccurrence
        spec
        (FixedRelation DirectsInterventionCode)
        (rawId (strategyName strategy))
        (rawId (interventionName intervention))
    addressesOccurrence intervention need =
      canonicalOccurrence
        spec
        (FixedRelation AddressesNeedCode)
        (rawId (interventionName intervention))
        (rawId (needName need))
    qualifiesOccurrence strategy need =
      canonicalOccurrence
        spec
        (FixedRelation QualifiesNeedCode)
        (rawId (strategyName strategy))
        (rawId (needName need))

canonicalOccurrence ::
     GraphSpec
  -> RelationCode
  -> RawNodeId
  -> RawNodeId
  -> (RawNodeId, RelationCode, RawNodeId, Int)
canonicalOccurrence spec relation from to =
  case [ (rawFrom, code, rawTo, edgeOrdinal)
       | (edgeOrdinal, SomeEdge edge) <-
           zip [0 ..] (sortEdges (graphEdges (materialize spec)))
       , let rawFrom = unNodeId (edgeFrom edge)
       , let code = relationCode (relationSpec (edgeRelation edge))
       , let rawTo = unNodeId (edgeTo edge)
       , code == relation
       , rawFrom == from
       , rawTo == to
       ] of
    [occurrence] -> occurrence
    _ -> error "generated oracle expected one canonical occurrence"

sortEdges :: [SomeEdge] -> [SomeEdge]
sortEdges =
  sortOn
    (\(SomeEdge edge) ->
       ( relationCode (relationSpec (edgeRelation edge))
       , unNodeId (edgeFrom edge)
       , unNodeId (edgeTo edge)))

indices :: Int -> [Int]
indices count = [0 .. count - 1]

strategyName :: Int -> Text
strategyName = name "s"

interventionName :: Int -> Text
interventionName = name "i"

needName :: Int -> Text
needName = name "n"

name :: Text -> Int -> Text
name prefix ordinal = prefix <> "-" <> Text.pack (show ordinal)
