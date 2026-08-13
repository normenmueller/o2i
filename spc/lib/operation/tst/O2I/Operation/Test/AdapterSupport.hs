{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module O2I.Operation.Test.AdapterSupport
  ( compileCompleteAdapter
  , nativeRuleSpec
  , resolveNativeRule
  ) where

import Data.Bifunctor (first)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.ArchiMate.Profile.Notation
  ( allArchiMateNotationIssueKinds
  , archiMateNotationIssueKindToken
  )
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import Test.Tasty.HUnit (assertFailure)

compileCompleteAdapter ::
     AdapterDescriptor
  -> [AdapterRuleSpec]
  -> (forall scope. AdapterRules scope -> Either
                                            (NonEmpty AdapterCompilationDefect)
                                            (AdapterBehavior scope))
  -> IO Adapter
compileCompleteAdapter descriptor nativeSpecs define = do
  notation <-
    traverse
      (\kind ->
         archiMateNotationRule kind
           <$> requireRight
                 (mkAdapterRuleSpec
                    ("test.notation." <> archiMateNotationIssueKindToken kind)
                    notationRuleStage
                    "expectation"
                    "meaning"
                    "action"))
      (NonEmpty.toList allArchiMateNotationIssueKinds)
  case map nativeAdapterRule nativeSpecs <> notation of
    firstBinding:rest ->
      requireRight (compileAdapter descriptor (firstBinding :| rest) define)
    [] ->
      assertFailure "closed notation inventory is empty" >> fail "unreachable"

nativeRuleSpec :: Text -> IO AdapterRuleSpec
nativeRuleSpec identifier =
  requireRight
    (mkAdapterRuleSpec
       identifier
       preparationRuleStage
       "expectation"
       "meaning"
       "action")

resolveNativeRule ::
     AdapterRules scope
  -> AdapterRuleSpec
  -> (NativeAdapterRule scope -> rule)
  -> Either (NonEmpty AdapterCompilationDefect) rule
resolveNativeRule rules spec restrict =
  first
    pure
    (restrict <$> lookupNativeAdapterRule rules (adapterRuleSpecId spec))

requireRight :: Show failure => Either failure value -> IO value
requireRight result =
  case result of
    Left failure -> assertFailure (show failure) >> fail "unreachable"
    Right value -> pure value
