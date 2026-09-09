{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Profile
  ( main
  , tests
  ) where

import Data.ByteString (ByteString)
import qualified Data.ByteString as ByteString
import Data.List (sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified O2I.ArchiMate.Profile as Profile
import qualified O2I.ArchiMate.Profile.Draft as Draft
import qualified O2I.ArchiMate.Profile.Notation as Notation
import O2I.Operation.Adapter
  ( SelectedAdapter
  , adapterDescriptorId
  , adapterIdText
  , foldAdapterSelection
  , selectAdapter
  )
import O2I.Operation.Adapter.Authoring
  ( adapterBehavior
  , compileAdapterCollection
  , decodeRule
  , decodedDraft
  , mkAdapterDescriptor
  , mkAdapterId
  , noRecognitionMatch
  )
import O2I.Operation.Profile
import O2I.Operation.Rule.Catalog
  ( OperationRule
  , operationRuleIdText
  , operationRuleIdentity
  )
import O2I.Operation.Test.AdapterSupport
  ( compileCompleteAdapter
  , nativeRuleSpec
  , resolveNativeRule
  )
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "profile bootstrap and compatibility"
    [ testCase
        "resolves all seven branches with exact precedence"
        resolutionCases
    , testCase
        "rejects duplicate descriptor identity/token pairs"
        duplicateInventory
    , testCase
        "enumerates the closed inventory deterministically"
        deterministicInventory
    , testCase "checks adapter admission before notation" compatibilityCases
    ]

resolutionCases :: IO ()
resolutionCases = do
  inventory <- requireInventory Profile.compiledProfileInventory
  assertResolution inventory [] Missing
  assertResolution
    inventory
    [profileProperty [textScalar "bad"], profileProperty []]
    PropertyMultiplicity
  assertResolution
    inventory
    [ profileProperty
        [ Draft.draftBooleanScalar True (location "boolean")
        , textScalar (compiledReference inventory)
        ]
    ]
    ValueMultiplicity
  assertResolution
    inventory
    [profileProperty [Draft.draftBooleanScalar True (location "boolean")]]
    ValueKind
  assertResolution
    inventory
    [profileProperty [textScalar "not-a-reference"]]
    Grammar
  assertResolution
    inventory
    [profileProperty [textScalar "unknown.profile@1.2"]]
    Unknown
  assertResolution
    inventory
    [profileProperty [textScalar (compiledReference inventory)]]
    Resolved

duplicateInventory :: IO ()
duplicateInventory =
  case Profile.compiledProfileInventory of
    [] -> assertFailure "the compiled Profile inventory must be non-empty"
    descriptor:_ ->
      foldProfileInventoryCompilation
        (\defects -> do
           NonEmpty.length defects @?= 1
           let tags = fmap inventoryDefectTag (NonEmpty.toList defects)
           tags @?= ["bootstrap.profile-inventory.identity-token-uniqueness"])
        (const (assertFailure "a duplicate Profile key was accepted"))
        (compileProfileInventory [descriptor, descriptor])

deterministicInventory :: IO ()
deterministicInventory = do
  first <- requireInventory Profile.compiledProfileInventory
  second <- requireInventory (reverse Profile.compiledProfileInventory)
  let firstReferences = inventoryReferences first
      secondReferences = inventoryReferences second
  firstReferences @?= sort firstReferences
  secondReferences @?= firstReferences

compatibilityCases :: IO ()
compatibilityCases = do
  inventory <- requireInventory Profile.compiledProfileInventory
  profile <- requireResolved inventory
  unadmitted <- requireSelectedAdapter "other" "other" "other-notation"
  wrongNotation <- requireSelectedAdapter "amx" "amx" "other-notation"
  compatible <- requireSelectedAdapter "amx" "amx" "archimate-3.2"
  compatibilityTag (checkProfileCompatibility profile unadmitted)
    @?= ("bootstrap.profile-adapter.adapter-id", "other")
  compatibilityTag (checkProfileCompatibility profile wrongNotation)
    @?= ("bootstrap.profile-adapter.notation", "amx")
  compatibilityTag (checkProfileCompatibility profile compatible)
    @?= ("compatible", "amx")

data ResolutionTag
  = Missing
  | PropertyMultiplicity
  | ValueMultiplicity
  | ValueKind
  | Grammar
  | Unknown
  | Resolved
  deriving (Eq, Show)

assertResolution ::
     ProfileInventory
  -> [Draft.DraftMember Draft.ModelRootRole]
  -> ResolutionTag
  -> IO ()
assertResolution inventory members expected = do
  evidence <- requireMarkerEvidence (modelDraft members)
  let (actual, rule) = resolutionTag (resolveProfile inventory evidence)
  actual @?= expected
  rule @?= expectedRule expected

resolutionTag :: ProfileResolution -> (ResolutionTag, Maybe Text)
resolutionTag =
  foldProfileResolution
    (\rule _ -> (Missing, Just (ruleIdentity rule)))
    (\rule _ _ -> (PropertyMultiplicity, Just (ruleIdentity rule)))
    (\rule _ _ _ -> (ValueMultiplicity, Just (ruleIdentity rule)))
    (\rule _ _ _ -> (ValueKind, Just (ruleIdentity rule)))
    (\rule _ _ -> (Grammar, Just (ruleIdentity rule)))
    (\rule _ _ -> (Unknown, Just (ruleIdentity rule)))
    (const (Resolved, Nothing))

expectedRule :: ResolutionTag -> Maybe Text
expectedRule tag =
  case tag of
    Missing -> Just "bootstrap.profile-reference.missing"
    PropertyMultiplicity ->
      Just "bootstrap.profile-reference.property-multiplicity"
    ValueMultiplicity -> Just "bootstrap.profile-reference.value-multiplicity"
    ValueKind -> Just "bootstrap.profile-reference.value-kind"
    Grammar -> Just "bootstrap.profile-reference.grammar"
    Unknown -> Just "bootstrap.profile-reference.unknown"
    Resolved -> Nothing

inventoryDefectTag :: ProfileInventoryDefect -> Text
inventoryDefectTag =
  foldProfileInventoryDefect "empty" (\rule _ -> ruleIdentity rule)

compatibilityTag :: ProfileCompatibility -> (Text, Text)
compatibilityTag =
  foldProfileCompatibility
    (\rule _ descriptor _ ->
       (ruleIdentity rule, adapterIdText (adapterDescriptorId descriptor)))
    (\rule _ descriptor _ _ ->
       (ruleIdentity rule, adapterIdText (adapterDescriptorId descriptor)))
    (\_ descriptor _ ->
       ("compatible", adapterIdText (adapterDescriptorId descriptor)))

requireInventory :: [Profile.ProfileDescriptor] -> IO ProfileInventory
requireInventory descriptors =
  case foldProfileInventoryCompilation
         Left
         Right
         (compileProfileInventory descriptors) of
    Left defects ->
      assertFailure
        ("expected a valid Profile inventory, got "
           <> show (NonEmpty.length defects))
        >> requireInventory descriptors
    Right inventory -> pure inventory

requireMarkerEvidence :: Draft.ProfileDraft -> IO ProfileMarkerEvidence
requireMarkerEvidence draft =
  Notation.withCanonicalDocument draft $ \document ->
    case foldProfileMarkerEvidenceOutcome
           (Left . length)
           Right
           (prepareProfileMarkerEvidence
              (Notation.assessMarkerEvidence document)) of
      Left rejected ->
        assertFailure
          ("expected accepted marker evidence, got " <> show rejected)
          >> requireMarkerEvidence draft
      Right evidence -> pure evidence

requireResolved :: ProfileInventory -> IO ResolvedProfile
requireResolved inventory = do
  evidence <-
    requireMarkerEvidence
      (modelDraft [profileProperty [textScalar (compiledReference inventory)]])
  case foldProfileResolution
         (\_ _ -> Left "missing")
         (\_ _ _ -> Left "property multiplicity")
         (\_ _ _ _ -> Left "value multiplicity")
         (\_ _ _ _ -> Left "value kind")
         (\_ _ _ -> Left "grammar")
         (\_ _ _ -> Left "unknown")
         Right
         (resolveProfile inventory evidence) of
    Left failure ->
      assertFailure ("expected resolved Profile, got " <> failure)
        >> requireResolved inventory
    Right profile -> pure profile

requireSelectedAdapter :: Text -> Text -> Text -> IO SelectedAdapter
requireSelectedAdapter identifier name notation =
  case mkAdapterId identifier of
    Left _ -> assertFailure "invalid test adapter identifier" >> retry
    Right adapterIdentifier ->
      case mkAdapterDescriptor adapterIdentifier name "1" notation of
        Left _ -> assertFailure "invalid test adapter descriptor" >> retry
        Right descriptor -> do
          definition <- nativeRuleSpec "test.rule"
          compiledAdapter <-
            compileCompleteAdapter descriptor [definition] $ \rules -> do
              _ <- resolveNativeRule rules definition decodeRule
              pure
                (adapterBehavior
                   (const noRecognitionMatch)
                   (const (decodedDraft (modelDraft []))))
          case compileAdapterCollection (compiledAdapter :| []) of
            Left _ -> assertFailure "invalid test adapter collection" >> retry
            Right collection ->
              case foldAdapterSelection
                     Left
                     Right
                     (selectAdapter
                        collection
                        (Just adapterIdentifier)
                        emptyBytes) of
                Left _ -> assertFailure "test adapter was not selected" >> retry
                Right selected -> pure selected
  where
    retry = requireSelectedAdapter identifier name notation

emptyBytes :: ByteString
emptyBytes = ByteString.empty

compiledReference :: ProfileInventory -> Text
compiledReference =
  Profile.profileDescriptorReference
    . NonEmpty.head
    . profileInventoryDescriptors

inventoryReferences :: ProfileInventory -> [Text]
inventoryReferences =
  fmap Profile.profileDescriptorReference
    . NonEmpty.toList
    . profileInventoryDescriptors

ruleIdentity :: OperationRule -> Text
ruleIdentity = operationRuleIdText . operationRuleIdentity

modelDraft :: [Draft.DraftMember Draft.ModelRootRole] -> Draft.ProfileDraft
modelDraft members =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [textScalar "model"])
       (location "model")
       members)

profileProperty :: [Draft.DraftScalar] -> Draft.DraftMember ownerRole
profileProperty values =
  Draft.propertyMember
    (Draft.draftProperty
       (Draft.directPropertyKey [textScalar "o2i.profile"])
       values
       (location "profile-property")
       [])

textScalar :: Text -> Draft.DraftScalar
textScalar value = Draft.draftTextScalar value (location "scalar")

location :: Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing
