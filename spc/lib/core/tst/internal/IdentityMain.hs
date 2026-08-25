{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Focused laws for the profile-neutral identity and selected-View boundary.
module Main where

import Control.Monad (forM_)
import Data.List (isInfixOf)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Array as TextArray
import qualified Data.Text.Internal as TextInternal
import Data.Word (Word8)
import O2I.Core.Contract
import O2I.Core.Identity
import O2I.Core.Identity.Internal
  ( IdentityResolution(..)
  , SelectedIdentityKind(..)
  , resolveIdentity
  , scopedOccurrenceIdentity
  , selectedViewScopeDefectIndexedModelIdentity
  , selectedViewScopeDefectSuppliedModelIdentity
  , selectedViewScopeGraphIdentity
  )
import Test.Tasty
import Test.Tasty.HUnit

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "profile-neutral identity boundary"
    [ testCase
        "identity decoders preserve exact valid text and reject invalid text"
        identityDecoderContract
    , testCase
        "identity decoders enforce Unicode scalar boundaries"
        identityScalarBoundaryContract
    , testCase
        "duplicate occurrence identities are rejected canonically"
        duplicateOccurrenceContract
    , testCase
        "duplicate model identities remain ambiguous occurrences"
        ambiguousModelIdentityContract
    , testCase
        "selected-View membership defects accumulate canonically"
        selectedViewMembershipContract
    , testCase
        "selected-View subject is indexed exactly before scope construction"
        selectedViewSubjectContract
    , testCase
        "resolution obeys the exact precedence"
        resolutionPrecedenceContract
    , testCase
        "out-of-View resolution neither classifies nor leaks a kind"
        outOfViewNonLeakContract
    , testCase
        "resolved occurrences retain their nominal View scope"
        resolvedScopeContract
    ]

identityDecoderContract :: Assertion
identityDecoderContract = do
  fmap modelIdentityText (modelIdentity " Mixed Case ") @?= Right " Mixed Case "
  assertBool
    "canonically equivalent Unicode sequences remain distinct"
    (modelIdentity "\x00e9" /= modelIdentity "e\x0301")
  assertBool "case remains significant" (modelIdentity "A" /= modelIdentity "a")
  modelIdentity "" @?= Left EmptyModelIdentity
  modelIdentity "model\NULidentity" @?= Left ModelIdentityContainsU0000
  fmap occurrenceIdentityText (occurrenceIdentity " occurrence ")
    @?= Right " occurrence "
  occurrenceIdentity "" @?= Left EmptyOccurrenceIdentity
  occurrenceIdentity "occurrence\NULidentity"
    @?= Left OccurrenceIdentityContainsU0000

identityScalarBoundaryContract :: Assertion
identityScalarBoundaryContract = do
  mapM_ assertScalarAccepted ['\xd7ff', '\xe000', '\x10ffff']
  assertSurrogateRejected
    (unsafeUtf8Text [0xed, 0xa0, 0x80])
    ModelIdentityContainsSurrogate
    OccurrenceIdentityContainsSurrogate
  assertSurrogateRejected
    (unsafeUtf8Text [0xed, 0xbf, 0xbf])
    ModelIdentityContainsSurrogate
    OccurrenceIdentityContainsSurrogate

assertScalarAccepted :: Char -> Assertion
assertScalarAccepted scalar = do
  let value = Text.singleton scalar
  fmap modelIdentityText (modelIdentity value) @?= Right value
  fmap occurrenceIdentityText (occurrenceIdentity value) @?= Right value

assertSurrogateRejected ::
     Text -> ModelIdentityDefect -> OccurrenceIdentityDefect -> Assertion
assertSurrogateRejected value modelDefect occurrenceDefect = do
  modelIdentity value @?= Left modelDefect
  occurrenceIdentity value @?= Left occurrenceDefect

-- Test-only construction of a Text value containing UTF-8-encoded surrogate
-- bytes. Public Text constructors replace these code points before the Core
-- boundary can inspect them.
unsafeUtf8Text :: [Word8] -> Text
unsafeUtf8Text bytes =
  TextInternal.Text
    (TextArray.run $ do
       mutable <- TextArray.new (length bytes)
       forM_ (zip [0 ..] bytes) $ \(index, byte) ->
         TextArray.unsafeWrite mutable index byte
       pure mutable)
    0
    (length bytes)

duplicateOccurrenceContract :: Assertion
duplicateOccurrenceContract =
  case buildModelIdentityIndex
         [ occurrence "occurrence-b" "model-b"
         , occurrence "occurrence-a" "model-z"
         , occurrence "occurrence-a" "model-a"
         ] of
    Left defects -> do
      map identityIndexDefectOccurrence (NonEmpty.toList defects)
        @?= [occurrenceId "occurrence-a"]
      identityIndexDefectModelIdentities (NonEmpty.head defects)
        @?= modelId "model-a"
        NonEmpty.:| [modelId "model-z"]
    Right _ -> assertFailure "duplicate occurrence identity was accepted"

ambiguousModelIdentityContract :: Assertion
ambiguousModelIdentityContract =
  withIndex
    [occurrence "occurrence-b" "shared", occurrence "occurrence-a" "shared"] $ \index ->
    withScope index [occurrenceId "occurrence-a"] $ \scope ->
      case resolveIdentity scope uncalled firstElement (modelId "shared") of
        AmbiguousModelIdentity identifier occurrences -> do
          identifier @?= modelId "shared"
          occurrences
            @?= occurrenceId "occurrence-a"
            NonEmpty.:| [occurrenceId "occurrence-b"]
        result -> assertFailure ("unexpected resolution: " ++ show result)

selectedViewMembershipContract :: Assertion
selectedViewMembershipContract =
  withIndex [occurrence "known" "model"] $ \index ->
    case withSelectedViewScope
           index
           selectedViewSubject
           [occurrenceId "missing", occurrenceId "known", occurrenceId "known"]
           (const ()) of
      Left defects ->
        map defectIdentity (NonEmpty.toList defects)
          @?= [ (DuplicateSelectedViewOccurrence, occurrenceId "known", 2)
              , (UnknownSelectedViewOccurrence, occurrenceId "missing", 1)
              ]
      Right () -> assertFailure "invalid selected-View membership was accepted"
  where
    defectIdentity defect =
      ( selectedViewScopeDefectKind defect
      , selectedViewScopeDefectOccurrence defect
      , selectedViewScopeDefectCardinality defect)

selectedViewSubjectContract :: Assertion
selectedViewSubjectContract =
  withIndex [] $ \index -> do
    case withSelectedViewScope
           index
           (occurrence "unknown-view" "unknown-identity")
           []
           (const ()) of
      Left (defect NonEmpty.:| []) ->
        defectIdentity defect
          @?= ( UnknownSelectedViewSubjectOccurrence
              , occurrenceId "unknown-view"
              , Nothing
              , Nothing)
      other ->
        assertFailure ("unexpected unknown-subject result: " ++ show other)
    case withSelectedViewScope
           index
           (occurrence "selected-view" "replacement-identity")
           []
           (const ()) of
      Left (defect NonEmpty.:| []) -> do
        defectIdentity defect
          @?= ( SelectedViewSubjectIdentityMismatch
              , occurrenceId "selected-view"
              , Just (modelId "selected-view-identity")
              , Just (modelId "replacement-identity"))
        assertBool
          "public defect rendering leaked a replaceable model identity"
          (not
             ("selected-view-identity" `isInfixOf` show defect
                || "replacement-identity" `isInfixOf` show defect))
      other -> assertFailure ("unexpected mismatch result: " ++ show other)
    case withSelectedViewScope index selectedViewSubject [] inspectIdentity of
      Left defects ->
        assertFailure ("valid subject was rejected: " ++ show defects)
      Right identityValue -> identityValue @?= modelId "selected-view-identity"
  where
    defectIdentity defect =
      ( selectedViewScopeDefectKind defect
      , selectedViewScopeDefectOccurrence defect
      , selectedViewScopeDefectIndexedModelIdentity defect
      , selectedViewScopeDefectSuppliedModelIdentity defect)
    inspectIdentity scope = selectedViewScopeGraphIdentity scope

resolutionPrecedenceContract :: Assertion
resolutionPrecedenceContract =
  withIndex
    [ occurrence "ambiguous-b" "ambiguous"
    , occurrence "ambiguous-a" "ambiguous"
    , occurrence "outside" "outside"
    , occurrence "selected" "selected"
    ] $ \index ->
    withScope index [occurrenceId "selected"] $ \scope -> do
      case resolveIdentity scope uncalled firstElement (modelId "unknown") of
        UnknownModelIdentity identifier -> identifier @?= modelId "unknown"
        result -> assertFailure ("unexpected unknown result: " ++ show result)
      case resolveIdentity scope uncalled firstElement (modelId "ambiguous") of
        AmbiguousModelIdentity _ _ -> pure ()
        result -> assertFailure ("unexpected ambiguous result: " ++ show result)
      case resolveIdentity scope uncalled firstElement (modelId "outside") of
        ModelIdentityOutOfSelectedView identifier actualOccurrenceId -> do
          identifier @?= modelId "outside"
          actualOccurrenceId @?= occurrenceId "outside"
        result ->
          assertFailure ("unexpected out-of-View result: " ++ show result)
      case resolveIdentity
             scope
             (const secondElement)
             firstElement
             (modelId "selected") of
        WrongSelectedIdentityKind scoped expected actual -> do
          scopedOccurrenceIdentity scoped @?= occurrenceId "selected"
          expected @?= firstElement
          actual @?= secondElement
        result ->
          assertFailure ("unexpected wrong-kind result: " ++ show result)
      case resolveIdentity
             scope
             (const firstElement)
             firstFamily
             (modelId "selected") of
        WrongSelectedIdentityKind _ expected actual -> do
          expected @?= firstFamily
          actual @?= firstElement
        result ->
          assertFailure ("unexpected wrong-family result: " ++ show result)
      case resolveIdentity
             scope
             (const firstElement)
             firstElement
             (modelId "selected") of
        ResolvedIdentity scoped actual -> do
          scopedOccurrenceIdentity scoped @?= occurrenceId "selected"
          actual @?= firstElement
        result -> assertFailure ("unexpected resolved result: " ++ show result)

outOfViewNonLeakContract :: Assertion
outOfViewNonLeakContract =
  withIndex [occurrence "outside" "subject"] $ \index ->
    withScope index [] $ \scope ->
      case resolveIdentity scope uncalled firstElement (modelId "subject") of
        ModelIdentityOutOfSelectedView identifier actualOccurrenceId -> do
          identifier @?= modelId "subject"
          actualOccurrenceId @?= occurrenceId "outside"
        result ->
          assertFailure ("unexpected out-of-View result: " ++ show result)

resolvedScopeContract :: Assertion
resolvedScopeContract =
  withIndex [occurrence "selected" "subject"] $ \index ->
    withScope index [occurrenceId "selected"] $ \scope ->
      case resolveIdentity
             scope
             (const firstElement)
             firstElement
             (modelId "subject") of
        ResolvedIdentity scoped _ ->
          scopedOccurrenceIdentity scoped @?= occurrenceId "selected"
        result -> assertFailure ("unexpected resolved result: " ++ show result)

occurrence :: Text -> Text -> ModelOccurrence
occurrence occurrenceText modelText =
  modelOccurrence (occurrenceId occurrenceText) (modelId modelText)

modelId :: Text -> ModelIdentity
modelId value =
  case modelIdentity value of
    Left defect -> error ("invalid model-identity fixture: " ++ show defect)
    Right identifier -> identifier

occurrenceId :: Text -> OccurrenceIdentity
occurrenceId value =
  case occurrenceIdentity value of
    Left defect ->
      error ("invalid occurrence-identity fixture: " ++ show defect)
    Right identifier -> identifier

withIndex :: [ModelOccurrence] -> (ModelIdentityIndex -> Assertion) -> Assertion
withIndex occurrences action =
  case buildModelIdentityIndex (selectedViewSubject : occurrences) of
    Left defects -> assertFailure ("invalid identity fixture: " ++ show defects)
    Right index -> action index

withScope ::
     ModelIdentityIndex
  -> [OccurrenceIdentity]
  -> (forall scope. SelectedViewScope scope -> Assertion)
  -> Assertion
withScope index identities action =
  case withSelectedViewScope index selectedViewSubject identities action of
    Left defects -> assertFailure ("invalid View fixture: " ++ show defects)
    Right assertion -> assertion

selectedViewSubject :: ModelOccurrence
selectedViewSubject = occurrence "selected-view" "selected-view-identity"

firstElement :: SelectedIdentityKind
firstElement = SelectedCarrier (NonEmpty.head coreQualifiedEndpointIds)

secondElement :: SelectedIdentityKind
secondElement =
  case NonEmpty.tail coreQualifiedEndpointIds of
    value:_ -> SelectedCarrier value
    [] -> firstElement

firstFamily :: SelectedIdentityKind
firstFamily =
  SelectedStructuredProposition
    (NonEmpty.head coreStructuredPropositionFamilyIds)

uncalled :: value -> result
uncalled _ = error "classification must not run before selected-View membership"
