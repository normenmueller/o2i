{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.View
  ( tests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.ArchiMate.Profile.Draft as Draft
import O2I.ArchiMate.Profile.Notation
  ( CanonicalDocument
  , buildCanonicalDocument
  , canonicalOccurrenceOrdinal
  , viewDescriptorOccurrence
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
selectExactName = do
  ordinal <-
    selectedOrdinal (selectView selectionDocument (viewByName "Primary"))
  ordinal @?= 2

selectExactIdentity :: IO ()
selectExactIdentity = do
  ordinal <-
    selectedOrdinal
      (selectView selectionDocument (viewByIdentity (identity "view-primary")))
  ordinal @?= 2

reportUnknown :: IO ()
reportUnknown = do
  failureTag (selectView selectionDocument (viewByName "Absent")) @?= Unknown
  failureTag (selectView selectionDocument (viewByIdentity (identity "absent")))
    @?= Unknown

reportAmbiguousName :: IO ()
reportAmbiguousName =
  failureTag (selectView duplicateNameDocument (viewByName "Repeated"))
    @?= AmbiguousName 2

reportAmbiguousIdentity :: IO ()
reportAmbiguousIdentity =
  failureTag
    (selectView duplicateIdentityDocument (viewByIdentity (identity "shared")))
    @?= AmbiguousIdentity 2

reportWrongFamily :: IO ()
reportWrongFamily =
  failureTag
    (selectView selectionDocument (viewByIdentity (identity "element")))
    @?= WrongFamily

indexIdentityCandidates :: IO ()
indexIdentityCandidates = do
  let size = 400
      document =
        buildCanonicalDocument
          (modelDraft
             (fmap (element . indexed "element") [1 .. size]
                <> fmap
                     (\index ->
                        view (indexed "view" index) (indexed "name" index))
                     [1 .. size]))
      selected = viewByIdentity (identity (indexed "view" size))
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

failureTag :: ViewSelection -> FailureTag
failureTag =
  foldViewSelection
    (foldViewSelectionFailure
       (const Unknown)
       (\_ candidates -> AmbiguousName (NonEmpty.length candidates))
       (\_ candidates -> AmbiguousIdentity (NonEmpty.length candidates))
       (\_ _ -> WrongFamily))
    (const UnexpectedSelection)

selectedOrdinal :: ViewSelection -> IO Integer
selectedOrdinal =
  foldViewSelection
    (const (assertFailure "expected one selected View" >> fail "unreachable"))
    (pure
       . toInteger
       . canonicalOccurrenceOrdinal
       . viewDescriptorOccurrence
       . selectedViewDescriptor)

selectionDocument :: CanonicalDocument
selectionDocument =
  buildCanonicalDocument
    (modelDraft
       [ element "element"
       , view "view-primary" "Primary"
       , view "view-secondary" "Secondary"
       ])

duplicateNameDocument :: CanonicalDocument
duplicateNameDocument =
  buildCanonicalDocument
    (modelDraft [view "view-one" "Repeated", view "view-two" "Repeated"])

duplicateIdentityDocument :: CanonicalDocument
duplicateIdentityDocument =
  buildCanonicalDocument
    (modelDraft [element "shared", view "shared" "Only View"])

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
