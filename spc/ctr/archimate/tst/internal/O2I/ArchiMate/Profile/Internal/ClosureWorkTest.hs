module O2I.ArchiMate.Profile.Internal.ClosureWorkTest
  ( closureWorkTests
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified O2I.ArchiMate.Profile.Conformance.Source as ContractFixture
import O2I.ArchiMate.Profile.Internal.Closure
import O2I.ArchiMate.Profile.Internal.Draft (ProfileDraft)
import qualified O2I.ArchiMate.Profile.Internal.Fixture as Fixture
import O2I.ArchiMate.Profile.Internal.Generated
import O2I.ArchiMate.Profile.Internal.Index (buildProfileIndex, indexModelRoots)
import O2I.ArchiMate.Profile.Internal.Notation
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertBool, testCase)

closureWorkTests :: TestTree
closureWorkTests =
  testGroup
    "Closure work"
    [ testCase "accounts for every queued item and generated rule check" $ do
        let (state, displayed) = evaluatedProduct ContractFixture.validDraft
            work = productClosureWork state
            factCount =
              Set.size (productGraphFacts state)
                + Set.size (productQualificationFacts state)
            activationCount =
              Set.size (productGraphActivations state)
                + Set.size (productQualificationActivations state)
            directRecordCount =
              Set.size
                (indexModelRoots (closedViewIndexValue closed)
                   `Set.union` Set.fromList
                                 (map displayedSubjectOccurrenceValue displayed))
            closed = fst (measureDraft ContractFixture.validDraft)
        closureWorkDequeuedItems work @?= activationCount + factCount
        closureWorkActivationRuleChecks work @?= length generatedActivationRules
          * (directRecordCount + factCount)
        closureWorkClosureRuleChecks work @?= length generatedClosureRules
          * factCount
    , testCase "is deterministic under source-order permutation" $ do
        snd (measureDraft ContractFixture.validDraft)
          @?= snd (measureDraft ContractFixture.validDraftPermuted)
    , testCase "ignores arbitrarily large unrelated model inventory" $ do
        let baseline =
              snd (measureDraft (Fixture.graphDraftWithUnrelatedElements 0))
            adversarial =
              snd (measureDraft (Fixture.graphDraftWithUnrelatedElements 1000))
        adversarial @?= baseline
    , testCase "records positive addressed work for a non-empty View" $ do
        let work = snd (measureDraft ContractFixture.validDraft)
        assertBool
          "expected at least one visited addressed-index candidate"
          (closureWorkVisitedIndexCandidates work > 0)
    , testCase "keeps closeView as the work-discarding projection" $ do
        let selected = selectedView ContractFixture.validDraft
            direct = closeView selected
            (measured, _) = closeViewWithWork selected
        closedViewGraphOccurrencesValue direct
          @?= closedViewGraphOccurrencesValue measured
        closedViewQualificationOccurrencesValue direct
          @?= closedViewQualificationOccurrencesValue measured
        closedViewUniverseValue direct @?= closedViewUniverseValue measured
    , testCase "measures predicate scans at the exact stopping point" $ do
        assertMeasured 1 True (measuredIndexAny even ([2, 3, 5] :: [Int]))
        assertMeasured 3 True (measuredIndexAny even ([1, 3, 4, 6] :: [Int]))
        assertMeasured 3 False (measuredIndexAny even ([1, 3, 5] :: [Int]))
    , testCase "measures every candidate required to establish uniqueness" $ do
        assertMeasured 0 Nothing (measuredUniqueIndexCandidate ([] :: [Int]))
        assertMeasured 1 (Just 1) (measuredUniqueIndexCandidate ([1] :: [Int]))
        assertMeasured
          2
          Nothing
          (measuredUniqueIndexCandidate ([1, 2] :: [Int]))
    , testCase "measures every candidate in a collect-all traversal" $ do
        assertMeasured
          3
          [2, 4, 6]
          (measuredIndexCandidatesWith
             (\value -> [value * 2])
             ([1, 2, 3] :: [Int]))
    , testCase "counts addressed map hits without charging misses" $ do
        let values = Map.singleton (1 :: Int) "one"
        assertMeasured 1 (Just "one") (measuredMapLookup 1 values)
        assertMeasured 0 Nothing (measuredMapLookup 2 values)
    , testCase "counts both self-loop buckets and emits one relationship" $ do
        let selected = selectedView Fixture.graphDraftWithSelfLoop
            profileIndex =
              buildProfileIndex (viewDescriptorDocumentValue selected)
            displayed =
              singleDisplayed
                (displayedOccurrences
                   profileIndex
                   (viewDescriptorOccurrenceValue selected))
            measured =
              measuredIncidentRelationships
                profileIndex
                (displayedSubjectOccurrenceValue displayed)
        visitedCandidates measured @?= 2
        length (measuredValue measured) @?= 1
    ]

assertMeasured ::
     (Eq value, Show value) => Int -> value -> Measured value -> IO ()
assertMeasured expectedWork expectedValue measured = do
  visitedCandidates measured @?= expectedWork
  measuredValue measured @?= expectedValue

visitedCandidates :: Measured value -> Int
visitedCandidates = workDeltaVisitedIndexCandidates . measuredWork

singleDisplayed :: [DisplayedOccurrence] -> DisplayedOccurrence
singleDisplayed displayed =
  case displayed of
    [occurrence] -> occurrence
    occurrences ->
      error
        ("expected exactly one displayed occurrence, got "
           <> show (length occurrences))

measureDraft :: ProfileDraft -> (ClosedView, ClosureWork)
measureDraft = closeViewWithWork . selectedView

evaluatedProduct :: ProfileDraft -> (ProductState, [DisplayedOccurrence])
evaluatedProduct draft = (evaluateProduct profileIndex displayed, displayed)
  where
    selected = selectedView draft
    profileIndex = buildProfileIndex (viewDescriptorDocumentValue selected)
    displayed =
      displayedOccurrences profileIndex (viewDescriptorOccurrenceValue selected)

selectedView :: ProfileDraft -> ViewDescriptor
selectedView draft =
  case viewInventoryValue (buildCanonicalDocument draft) of
    [selected] -> selected
    views -> error ("expected exactly one View, got " <> show (length views))
