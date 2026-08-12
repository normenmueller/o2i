{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Discovery
  ( main
  , tests
  ) where

import Data.ByteString (ByteString)
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Set as Set
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile as Profile
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import qualified O2I.ArchiMate.Profile.Rule.Catalog as ProfileCatalog
import qualified O2I.Core.Rule.Catalog as CoreCatalog
import O2I.Operation.Acquisition (acquiredSourceIdentity)
import O2I.Operation.Acquisition.Internal (AcquiredSource(..))
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Discovery.Adapter
import O2I.Operation.Discovery.Profile
import O2I.Operation.Discovery.Rule
import O2I.Operation.Discovery.View
import O2I.Operation.Profile
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import qualified O2I.Operation.Rule.Catalog as OperationCatalog
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "static discovery"
    [ testCase "enumerates adapters canonically and exactly" adapterDiscovery
    , testCase "projects exact derived Profile rows" profileDiscovery
    , testCase
        "discovers complete authority-local rule inventories"
        ruleDiscovery
    , testCase
        "performs authority-local exact explanation lookup"
        exactExplanation
    , testCase
        "rejects an empty exact rule explanation request"
        emptyExplanationRequest
    , testCase "keeps View discovery Profile-neutral" viewDiscovery
    ]

adapterDiscovery :: Assertion
adapterDiscovery = do
  collection <- fixtureAdapters
  let discovery = discoverAdapters collection
      descriptors = NonEmpty.toList (discoveredAdapters discovery)
      identifiers = map descriptorIdText descriptors
  identifiers @?= ["amx", "zeta"]
  identifier <- requireAdapterId "amx"
  fmap descriptorIdText (lookupDiscoveredAdapter identifier discovery)
    @?= Just "amx"
  missing <- requireAdapterId "AMX"
  lookupDiscoveredAdapter missing discovery @?= Nothing
  foldAdapterDiscovery length discovery @?= 2

profileDiscovery :: Assertion
profileDiscovery = do
  inventory <- fixtureProfileInventory
  discovery <- requireProfileDiscovery (discoverProfiles inventory)
  let rows = NonEmpty.toList (discoveredProfiles discovery)
      references = map profileDiscoveryReference rows
  references @?= sort references
  mapM_ assertProfileRow rows
  map
    (\row -> lookupDiscoveredProfile (profileDiscoveryReference row) discovery)
    rows
    @?= map Just rows
  lookupDiscoveredProfile "O2I.ARCHIMATE-PROFILE@0.3" discovery @?= Nothing
  foldProfileDiscovery length discovery @?= length rows

ruleDiscovery :: Assertion
ruleDiscovery = do
  descriptor <- fixtureProfileDescriptor
  collection <- fixtureAdapters
  operation <- requireRuleDiscovery discoverOperationRules
  core <- requireRuleDiscovery discoverCoreRules
  profile <- requireRuleDiscovery (discoverProfileRules descriptor)
  adapters <- discoverFixtureAdapterRules collection
  let discoveries = [operation, core, profile] <> map snd adapters
  assertRuleInventory
    "Operation"
    (OperationCatalog.operationRuleCatalogSize
       OperationCatalog.operationRuleCatalog)
    operation
  assertRuleInventory
    "Core"
    (CoreCatalog.coreRuleCatalogSize CoreCatalog.coreRuleCatalog)
    core
  assertRuleInventory
    ("Profile:" <> Profile.profileDescriptorReference descriptor)
    (ProfileCatalog.selectedProfileRuleCatalogSize
       ProfileCatalog.selectedProfileRuleCatalog)
    profile
  mapM_ (uncurry assertAdapterRuleInventory) adapters
  let authorities = map (ruleAuthorityText . ruleDiscoveryAuthority) discoveries
  Set.size (Set.fromList authorities) @?= length authorities
  mapM_ (assertContractBinding . ruleDiscoveryAuthority) discoveries

exactExplanation :: Assertion
exactExplanation = do
  descriptor <- fixtureProfileDescriptor
  collection <- fixtureAdapters
  operation <- requireRuleDiscovery discoverOperationRules
  core <- requireRuleDiscovery discoverCoreRules
  profile <- requireRuleDiscovery (discoverProfileRules descriptor)
  adapters <- discoverFixtureAdapterRules collection
  mapM_ assertExactExplanation ([operation, core, profile] <> map snd adapters)

emptyExplanationRequest :: Assertion
emptyExplanationRequest = do
  discovery <- requireRuleDiscovery discoverOperationRules
  case explainDiscoveredRule "" discovery of
    Left defect -> foldRuleExplanationRequestDefect (pure ()) defect
    Right _ -> assertFailure "empty rule explanation request was accepted"

viewDiscovery :: Assertion
viewDiscovery = do
  collection <- fixtureAdapters
  identifier <- requireAdapterId "amx"
  acquired <- fixtureAcquiredSource
  let outcome = discoverAcquiredViews collection (Just identifier) acquired
  result <- requireViewDiscovery outcome
  map
    viewDiscoveryAuthorityText
    (NonEmpty.toList (viewDiscoveryAuthorities result))
    @?= ["Operation", "Adapter:amx"]
  descriptorIdText (viewDiscoveryAdapter result) @?= "amx"
  viewDiscoverySource result @?= acquiredSourceIdentity acquired
  map
    (Notation.canonicalOccurrenceOrdinal . Notation.viewDescriptorOccurrence)
    (viewDiscoveryViews result)
    @?= [1, 2]
  length (Notation.canonicalDocumentRecords (viewDiscoveryDocument result))
    @?= 3

assertProfileRow :: ProfileDiscoveryRow -> Assertion
assertProfileRow row = do
  profileDiscoveryReference row @?= profileDiscoveryIdentity row
    <> "@"
    <> profileDiscoveryToken row
  let adapters = NonEmpty.toList (profileDiscoveryAdapterIds row)
  adapters @?= sort adapters
  Set.size (Set.fromList adapters) @?= length adapters
  mapM_
    (assertBool "Profile discovery field is empty" . not . nullText)
    [ profileDiscoveryIdentity row
    , profileDiscoveryToken row
    , profileDiscoveryVersion row
    , profileDiscoveryNotation row
    , profileDiscoveryContractDigest row
    ]
  foldProfileDiscoveryRow
    (\identity token version notation adapterIds digest ->
       (identity, token, version, notation, adapterIds, digest))
    row
    @?= ( profileDiscoveryIdentity row
        , profileDiscoveryToken row
        , profileDiscoveryVersion row
        , profileDiscoveryNotation row
        , profileDiscoveryAdapterIds row
        , profileDiscoveryContractDigest row)

assertCompleteRule :: DiscoveredRule -> Assertion
assertCompleteRule rule = do
  mapM_
    (assertBool "discovered rule field is empty" . not . nullText)
    [ ruleAuthorityText (discoveredRuleAuthority rule)
    , discoveredRuleIdentity rule
    , discoveredRuleStage rule
    , discoveredRuleExpectation rule
    , discoveredRuleMeaning rule
    , discoveredRuleAction rule
    ]
  foldDiscoveredRule
    (\authority identity stage expectation meaning action ->
       (authority, identity, stage, expectation, meaning, action))
    rule
    @?= ( discoveredRuleAuthority rule
        , discoveredRuleIdentity rule
        , discoveredRuleStage rule
        , discoveredRuleExpectation rule
        , discoveredRuleMeaning rule
        , discoveredRuleAction rule)

assertRuleInventory :: Text -> Int -> RuleDiscovery -> Assertion
assertRuleInventory expectedAuthority expectedSize discovery = do
  let authority = ruleDiscoveryAuthority discovery
      rows = NonEmpty.toList (discoveredRules discovery)
      identities = map discoveredRuleIdentity rows
  ruleAuthorityText authority @?= expectedAuthority
  length rows @?= expectedSize
  identities @?= sort identities
  Set.size (Set.fromList identities) @?= length identities
  mapM_ (\row -> discoveredRuleAuthority row @?= authority) rows
  mapM_ assertCompleteRule rows
  foldRuleDiscovery
    (\foldedAuthority foldedRows ->
       (foldedAuthority, foldedRows) @?= (authority, discoveredRules discovery))
    discovery

assertAdapterRuleInventory ::
     CompiledAdapterContract -> RuleDiscovery -> Assertion
assertAdapterRuleInventory contract discovery = do
  let descriptor = adapterContractDescriptor contract
      rules = NonEmpty.toList (adapterContractRules contract)
      authority = ruleDiscoveryAuthority discovery
      binding = ruleAuthorityBinding authority
  assertRuleInventory
    ("Adapter:" <> descriptorIdText descriptor)
    (length rules)
    discovery
  ruleContractIdentity binding @?= descriptorIdText descriptor
  ruleContractVersion binding @?= adapterDescriptorVersion descriptor
  ruleContractDigest binding @?= Nothing
  mapM_
    (\rule ->
       requireExplanation
         (explainDiscoveredRule
            (adapterRuleIdText (adapterRuleId rule))
            discovery)
         >>= foldRuleExplanation
               (\authority' requested discovered -> do
                  authority' @?= authority
                  requested @?= adapterRuleIdText (adapterRuleId rule)
                  discoveredRuleStage discovered
                    @?= adapterRuleStageText (adapterRuleStage rule))
               (\_ _ -> assertFailure "known adapter rule was not explained"))
    rules

assertExactExplanation :: RuleDiscovery -> Assertion
assertExactExplanation discovery = do
  let rows = NonEmpty.toList (discoveredRules discovery)
      authority = ruleDiscoveryAuthority discovery
  mapM_
    (\rule ->
       requireExplanation
         (explainDiscoveredRule (discoveredRuleIdentity rule) discovery)
         >>= foldRuleExplanation
               (\authority' requested discovered ->
                  (authority', requested, discovered)
                    @?= (authority, discoveredRuleIdentity rule, rule))
               (\_ _ -> assertFailure "known rule was not explained"))
    rows
  case rows of
    [] -> assertFailure "rule discovery unexpectedly empty"
    first:_ -> do
      let requested = " " <> discoveredRuleIdentity first
      explanation <-
        requireExplanation (explainDiscoveredRule requested discovery)
      foldRuleExplanation
        (\_ _ _ -> assertFailure "unknown rule unexpectedly resolved")
        (\authority' requested' ->
           (authority', requested') @?= (authority, requested))
        explanation

assertContractBinding :: RuleAuthority -> Assertion
assertContractBinding authority =
  foldRuleAuthority
    assertDigestBinding
    assertDigestBinding
    (\_ -> assertDigestBinding)
    (\_ -> assertBinding)
    authority
  where
    assertBinding binding =
      foldRuleContractBinding
        (\identity version digest -> do
           mapM_
             (assertBool "folded contract field is empty" . not . nullText)
             [identity, version]
           maybe (pure ()) assertNonEmpty digest)
        binding
    assertDigestBinding binding = do
      assertBinding binding
      maybe
        (assertFailure "authority contract digest is missing")
        assertNonEmpty
        (ruleContractDigest binding)
    assertNonEmpty =
      assertBool "authority contract digest is empty" . not . nullText

fixtureAdapters :: IO AdapterCollection
fixtureAdapters = do
  amx <- fixtureAdapter "amx" True fixtureViewDraft
  zeta <- fixtureAdapter "zeta" False emptyDraft
  requireRight (compileAdapterCollection (zeta :| [amx]))

fixtureAdapter :: Text -> Bool -> Draft.ProfileDraft -> IO Adapter
fixtureAdapter identifier matches draft = do
  descriptorIdentifier <- requireAdapterId identifier
  descriptor <-
    requireRight
      (mkAdapterDescriptor descriptorIdentifier identifier "1.0" "archimate-3.2")
  recognitionDefinition <-
    requireRight
      (mkAdapterRuleDefinition
         (identifier <> ".recognition")
         "Recognize the notation exactly once."
         "Prevents ambiguous native format selection."
         "Correct the native source signature.")
  decodeDefinition <-
    requireRight
      (mkAdapterRuleDefinition
         (identifier <> ".decode")
         "Decode exactly once."
         "Preserves native evidence."
         "Correct the native source.")
  requireRight
    (compileAdapter
       descriptor
       ((\_ _ ->
           adapterBehavior
             (const
                (if matches
                   then recognitionMatch
                   else noRecognitionMatch))
             (const (decodedDraft draft)))
          <$> recognitionRule recognitionDefinition
          <*> decodeRule decodeDefinition))

requireExplanation ::
     Either RuleExplanationRequestDefect RuleExplanation -> IO RuleExplanation
requireExplanation result =
  case result of
    Left _ ->
      assertFailure "valid rule explanation request was rejected"
        >> fail "unreachable"
    Right explanation -> pure explanation

fixtureProfileInventory :: IO ProfileInventory
fixtureProfileInventory =
  foldProfileInventoryCompilation
    (\_ ->
       assertFailure "compiled Profile inventory was rejected"
         >> fail "unreachable")
    pure
    (compileProfileInventory Profile.compiledProfileInventory)

fixtureProfileDescriptor :: IO Profile.ProfileDescriptor
fixtureProfileDescriptor =
  case Profile.compiledProfileInventory of
    [] ->
      assertFailure "compiled Profile inventory is empty" >> fail "unreachable"
    first:_ -> pure first

fixtureAcquiredSource :: IO AcquiredSource
fixtureAcquiredSource = do
  reference <- requireRight (mkSourceReference "model")
  pure
    (AcquiredSource
       (sourceIdentityFromBytes ModelRole (sourceOrdinal 0) reference modelBytes)
       modelBytes)

fixtureViewDraft :: Draft.ProfileDraft
fixtureViewDraft = modelDraft [view "view-b" "B", view "view-a" "A"]

emptyDraft :: Draft.ProfileDraft
emptyDraft = modelDraft []

modelDraft :: [Draft.DraftMember Draft.ModelRootRole] -> Draft.ProfileDraft
modelDraft members =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [textScalar "model"])
       (location "model")
       members)

view :: Text -> Text -> Draft.DraftMember Draft.ModelRootRole
view identifier name =
  Draft.childRecordMember
    (Draft.viewDraft
       (Draft.draftIdentity [textScalar identifier])
       (location identifier)
       [ Draft.nameFieldMember
           [textScalar name]
           (location (identifier <> "-name"))
       ])

textScalar :: Text -> Draft.DraftScalar
textScalar value = Draft.draftTextScalar value (location "scalar")

location :: Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing

descriptorIdText :: AdapterDescriptor -> Text
descriptorIdText = adapterIdText . adapterDescriptorId

nullText :: Text -> Bool
nullText = (== "")

modelBytes :: ByteString
modelBytes = "model"

requireAdapterId :: Text -> IO AdapterId
requireAdapterId identifier = requireRight (mkAdapterId identifier)

requireProfileDiscovery :: ProfileDiscoveryCompilation -> IO ProfileDiscovery
requireProfileDiscovery =
  foldProfileDiscoveryCompilation
    (\_ ->
       assertFailure "Profile discovery definition failed" >> fail "unreachable")
    pure

requireRuleDiscovery :: RuleDiscoveryCompilation -> IO RuleDiscovery
requireRuleDiscovery =
  foldRuleDiscoveryCompilation
    (\_ ->
       assertFailure "rule discovery definition failed" >> fail "unreachable")
    pure

discoverFixtureAdapterRules ::
     AdapterCollection -> IO [(CompiledAdapterContract, RuleDiscovery)]
discoverFixtureAdapterRules collection =
  mapM discover (NonEmpty.toList (adapterCollectionContracts collection))
  where
    discover contract = do
      discovery <- requireRuleDiscovery (discoverAdapterRules contract)
      pure (contract, discovery)

requireViewDiscovery :: ViewDiscovery -> IO ViewDiscoveryResult
requireViewDiscovery =
  foldViewDiscovery
    (const (assertFailure "View discovery failed" >> fail "unreachable"))
    pure

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
