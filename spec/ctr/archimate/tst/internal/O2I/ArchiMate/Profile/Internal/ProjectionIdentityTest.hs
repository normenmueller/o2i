{-# LANGUAGE OverloadedStrings #-}

module O2I.ArchiMate.Profile.Internal.ProjectionIdentityTest
  ( projectionIdentityTests
  ) where

import qualified O2I.ArchiMate.Profile.Conformance.Source as Fixture
import O2I.ArchiMate.Profile.Internal.Closure (closeView)
import O2I.ArchiMate.Profile.Internal.Draft (ProfileDraft)
import O2I.ArchiMate.Profile.Internal.Notation
import O2I.ArchiMate.Profile.Internal.Projection
import O2I.Core.Identity
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), assertFailure, testCase)

projectionIdentityTests :: TestTree
projectionIdentityTests =
  testGroup
    "Projection selected-View identity"
    [ testCase
        "carries the resolved View identity into the real Core scope boundary"
        selectedViewIdentityIntegration
    ]

selectedViewIdentityIntegration :: IO ()
selectedViewIdentityIntegration =
  case projectClosedProfile (closeView selectedView) of
    ProfileContractFailed failures ->
      assertFailure ("unexpected contract failure: " <> show failures)
    ProfileRejected defects ->
      assertFailure ("unexpected Profile rejection: " <> show defects)
    ProfileAccepted projection ->
      case viewDescriptorIdentityValue selectedView of
        IdentityResolved _ expectedIdentity -> do
          modelOccurrenceModelIdentity (profileSelectedViewValue projection)
            @?= expectedIdentity
          modelOccurrenceIdentity (profileSelectedViewValue projection)
            @?= expectRight
                  (canonicalOccurrenceIdentityValue
                     (viewDescriptorOccurrenceValue selectedView))
          case buildModelIdentityIndex
                 (profileModelIdentityOccurrencesValue projection) of
            Left defects ->
              assertFailure
                ("unexpected identity-index defects: " <> show defects)
            Right index ->
              case withSelectedViewScope
                     index
                     (profileSelectedViewValue projection)
                     (profileSelectedOccurrencesValue projection)
                     (const ()) of
                Left defects ->
                  assertFailure
                    ("unexpected selected-scope defects: " <> show defects)
                Right () -> pure ()
        outcome ->
          assertFailure
            ("selected View identity was not resolved: " <> show outcome)
  where
    selectedView = singleView Fixture.validDraft

singleView :: ProfileDraft -> ViewDescriptor
singleView draft =
  case viewInventoryValue (buildCanonicalDocument draft) of
    [view] -> view
    views -> error ("expected exactly one View, got " <> show (length views))

expectRight :: Show problem => Either problem value -> value
expectRight result =
  case result of
    Left problem -> error ("invalid integration fixture: " <> show problem)
    Right value -> value
