{-# LANGUAGE OverloadedStrings #-}

module O2I.Operation.Test.Provenance
  ( tests
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import Numeric.Natural (Natural)
import O2I.Operation.Provenance
import O2I.Operation.Provenance.Internal (sourceIdentityFromBytes)
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit

tests :: TestTree
tests =
  testGroup
    "provenance"
    [ testCase "source roles are closed" sourceRoleClosureTest
    , testCase "source references reject invalid values" referenceTest
    , testCase "source identity hashes exact bytes" sourceIdentityTest
    , testCase
        "supplemental provenance is canonical by ordinal"
        canonicalSupplementalProvenanceTest
    , testCase "empty supplemental provenance is valid" emptyProvenanceTest
    , testCase "model sources are rejected as supplemental" modelRejectedTest
    , testCase "duplicate ordinals are rejected" duplicateOrdinalTest
    ]

sourceRoleClosureTest :: Assertion
sourceRoleClosureTest =
  [minBound .. maxBound]
    @?= [ModelRole, SupplementalRole, ReadinessRole, AssessmentRole]

referenceTest :: Assertion
referenceTest = do
  mkSourceReference "" @?= Left EmptySourceReference
  mkSourceReference "bad\NULreference" @?= Left SourceReferenceContainsNul
  fmap sourceReferenceText (mkSourceReference "input.json")
    @?= Right "input.json"

sourceIdentityTest :: Assertion
sourceIdentityTest = do
  let identity = supplementalIdentity 0 "abc"
  sourceIdentityRole identity @?= SupplementalRole
  sourceOrdinalValue (sourceIdentityOrdinal identity) @?= 0
  sourceReferenceText (sourceIdentityReference identity) @?= "supplemental"
  sourceSha256Text (sourceIdentitySha256 identity)
    @?= "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  foldSourceIdentity
    (\role ordinal sourceReference digest ->
       ( role
       , sourceOrdinalValue ordinal
       , sourceReferenceText sourceReference
       , sourceSha256Text digest))
    identity
    @?= ( SupplementalRole
        , 0
        , "supplemental"
        , "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

canonicalSupplementalProvenanceTest :: Assertion
canonicalSupplementalProvenanceTest = do
  let first = supplementalIdentity 0 "first"
      second = readinessIdentity 1 "second"
      third = assessmentIdentity 2 "third"
  provenance <- requireRight (mkSupplementalProvenance [third, first, second])
  supplementalProvenanceSources provenance @?= [first, second, third]
  foldSupplementalProvenance length provenance @?= 3

emptyProvenanceTest :: Assertion
emptyProvenanceTest = do
  provenance <- requireRight (mkSupplementalProvenance [])
  supplementalProvenanceSources provenance @?= []

modelRejectedTest :: Assertion
modelRejectedTest = do
  let identity =
        sourceIdentityFromBytes
          ModelRole
          (sourceOrdinal 0)
          modelReference
          "model"
  defects <- requireLeft (mkSupplementalProvenance [identity])
  case NonEmpty.toList defects of
    [defect] ->
      foldSupplementalProvenanceDefect
        (\actual -> actual @?= identity)
        (\_ _ -> assertFailure "reported duplicate instead of model role")
        defect
    _ -> assertFailure "expected exactly one model-role defect"

duplicateOrdinalTest :: Assertion
duplicateOrdinalTest = do
  let first = supplementalIdentity 4 "first"
      second = readinessIdentity 4 "second"
  defects <- requireLeft (mkSupplementalProvenance [second, first])
  case NonEmpty.toList defects of
    [defect] ->
      foldSupplementalProvenanceDefect
        (const (assertFailure "reported model role instead of duplicate"))
        (\ordinal identities -> do
           sourceOrdinalValue ordinal @?= 4
           NonEmpty.toList identities @?= [first, second])
        defect
    _ -> assertFailure "expected exactly one duplicate-ordinal defect"

supplementalIdentity :: Natural -> ByteString -> SourceIdentity
supplementalIdentity ordinal =
  sourceIdentityFromBytes
    SupplementalRole
    (sourceOrdinal ordinal)
    supplementalReference

readinessIdentity :: Natural -> ByteString -> SourceIdentity
readinessIdentity ordinal =
  sourceIdentityFromBytes
    ReadinessRole
    (sourceOrdinal ordinal)
    readinessReference

assessmentIdentity :: Natural -> ByteString -> SourceIdentity
assessmentIdentity ordinal =
  sourceIdentityFromBytes
    AssessmentRole
    (sourceOrdinal ordinal)
    assessmentReference

modelReference :: SourceReference
modelReference = reference "model"

supplementalReference :: SourceReference
supplementalReference = reference "supplemental"

readinessReference :: SourceReference
readinessReference = reference "readiness"

assessmentReference :: SourceReference
assessmentReference = reference "assessment"

reference :: Text -> SourceReference
reference value =
  case mkSourceReference value of
    Right source -> source
    Left _ -> error "static non-empty source reference rejected"

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value

requireLeft :: Show value => Either failure value -> IO failure
requireLeft result =
  case result of
    Left failure -> pure failure
    Right value -> assertFailure (show value) >> fail "unreachable"
