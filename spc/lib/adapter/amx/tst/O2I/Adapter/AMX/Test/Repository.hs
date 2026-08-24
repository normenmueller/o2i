{-# LANGUAGE OverloadedStrings #-}

module O2I.Adapter.AMX.Test.Repository
  ( repositoryTests
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I.Adapter.AMX.Repository
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit ((@?=), testCase)

repositoryTests :: TestTree
repositoryTests =
  testGroup
    "repository Candidate View contract"
    [ testCase "requires every focused Candidate View exactly once" $ do
        let required = NonEmpty.toList allCandidateViews
        validateCandidateViewCoverage required @?= Right ()
        validateCandidateViewCoverage (drop 1 required)
          @?= Left (Contextualization NonEmpty.:| [])
        validateCandidateViewCoverage (required <> [NeedQualificationProposal])
          @?= Left (NeedQualificationProposal NonEmpty.:| [])
    , testCase "includes the qualification proposal execution surface"
        $ candidateViewName NeedQualificationProposal
            @?= "O2I Syntax - Need Qualification Proposal"
    ]
