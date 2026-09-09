{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.View
  ( tests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.ArchiMate.Profile.Notation
  ( canonicalOccurrenceOrdinal
  , canonicalViewOccurrence
  , withCanonicalDocument
  )
import O2I.Core.Identity (ModelIdentity, modelIdentity)
import O2I.Operation.View
import O2I.Operation.View.Internal (ViewSelectionWork(..), selectViewWithWork)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

tests :: TestTree
tests =
  testGroup
    "View selection"
    [ testCase "selects one View by exact native name" selectExactName
    , testCase "selects one View by exact model identity" selectExactIdentity
    , testCase "reports an unknown exact name or identity" reportUnknown
    , testCase "reports duplicate View names" reportAmbiguousName
    , testCase
        "decides identity cardinality before native family"
        reportAmbiguousIdentity
    , testCase "reports one non-View identity" reportWrongFamily
    , testCase
        "indexes adversarial identity candidates without a Cartesian scan"
        indexIdentityCandidates
    ]

selectExactName :: IO ()
selectExactName =
  withCanonicalDocument selectionDraft $ \document -> do
    ordinal <- selectedOrdinal (selectView document (viewByName "Primary"))
    ordinal @?= 2

selectExactIdentity :: IO ()
selectExactIdentity =
  withCanonicalDocument selectionDraft $ \document -> do
    ordinal <-
      selectedOrdinal
        (selectView document (viewByIdentity (identity "view-primary")))
    ordinal @?= 2

reportUnknown :: IO ()
reportUnknown =
  withCanonicalDocument selectionDraft $ \document -> do
    failureTag (selectView document (viewByName "Absent")) @?= Unknown
    failureTag (selectView document (viewByIdentity (identity "absent")))
      @?= Unknown

reportAmbiguousName :: IO ()
reportAmbiguousName =
  withCanonicalDocument duplicateNameDraft $ \document ->
    failureTag (selectView document (viewByName "Repeated")) @?= AmbiguousName 2

reportAmbiguousIdentity :: IO ()
reportAmbiguousIdentity =
  withCanonicalDocument duplicateIdentityDraft $ \document ->
    failureTag (selectView document (viewByIdentity (identity "shared")))
      @?= AmbiguousIdentity 2

reportWrongFamily :: IO ()
reportWrongFamily =
  withCanonicalDocument selectionDraft $ \document ->
    failureTag (selectView document (viewByIdentity (identity "element")))
      @?= WrongFamily

indexIdentityCandidates :: IO ()
indexIdentityCandidates = do
  let size = 400
      draft =
        modelDraft
          (fmap (element . indexed "element") [1 .. size]
             <> fmap
                  (\index -> view (indexed "view" index) (indexed "name" index))
                  [1 .. size])
  withCanonicalDocument draft $ \document -> do
    let selected = viewByIdentity (identity (indexed "view" size))
        (outcome, work) = selectViewWithWork document selected
    ordinal <- selectedOrdinal outcome
    ordinal @?= toInteger (size * 2)
    work @?= ViewSelectionWork size (size * 2 + 1) (size * 2 + 1)

indexed :: Text -> Int -> Text
indexed prefix index = prefix <> "-" <> Text.pack (show index)

data FailureTag
  = Unknown
  | AmbiguousName Int
  | AmbiguousIdentity Int
  | WrongFamily
  | UnexpectedSelection
  deriving (Eq, Show)

failureTag :: ViewSelection document -> FailureTag
failureTag =
  foldViewSelection
    (foldViewSelectionFailure
       (const Unknown)
       (\_ candidates -> AmbiguousName (NonEmpty.length candidates))
       (\_ candidates -> AmbiguousIdentity (NonEmpty.length candidates))
       (\_ _ -> WrongFamily))
    (const UnexpectedSelection)

selectedOrdinal :: ViewSelection document -> IO Integer
selectedOrdinal =
  foldViewSelection
    (const (assertFailure "expected one selected View" >> fail "unreachable"))
    (pure
       . toInteger
       . canonicalOccurrenceOrdinal
       . canonicalViewOccurrence
       . selectedViewDescriptor)

selectionDraft :: Draft.ProfileDraft
selectionDraft =
  modelDraft
    [ element "element"
    , view "view-primary" "Primary"
    , view "view-secondary" "Secondary"
    ]

duplicateNameDraft :: Draft.ProfileDraft
duplicateNameDraft =
  modelDraft [view "view-one" "Repeated", view "view-two" "Repeated"]

duplicateIdentityDraft :: Draft.ProfileDraft
duplicateIdentityDraft =
  modelDraft [element "shared", view "shared" "Only View"]

modelDraft :: [Draft.DraftMember Draft.ModelRootRole] -> Draft.ProfileDraft
modelDraft members =
  Draft.profileDraft
    (Draft.modelRootDraft
       (Draft.draftIdentity [textScalar "model"])
       (location "model")
       members)

element :: Text -> Draft.DraftMember Draft.ModelRootRole
element identifier =
  Draft.childRecordMember
    (Draft.elementDraft
       (Draft.draftIdentity [textScalar identifier])
       (location identifier)
       [])

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

identity :: Text -> ModelIdentity
identity value =
  case modelIdentity value of
    Left _ -> error "static fixture contains an invalid model identity"
    Right result -> result

textScalar :: Text -> Draft.DraftScalar
textScalar value = Draft.draftTextScalar value (location "scalar")

location :: Text -> Draft.DraftLocation
location subject =
  Draft.draftLocation
    (Draft.draftSourcePath
       (Draft.draftPathStep (Draft.draftNativeName Nothing subject) 0)
       [])
    Nothing
