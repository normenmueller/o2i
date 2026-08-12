{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Authority-local static rule discovery and exact explanation lookup.
--
-- Each constructor materializes exactly one immutable authority inventory.
-- Rule identity and presentation text never select evaluator behavior.
module O2I.Operation.Discovery.Rule
  ( type RuleContractBinding
  , ruleContractIdentity
  , ruleContractVersion
  , ruleContractDigest
  , foldRuleContractBinding
  , type RuleAuthority
  , ruleAuthorityText
  , ruleAuthorityBinding
  , foldRuleAuthority
  , type DiscoveredRule
  , discoveredRuleAuthority
  , discoveredRuleIdentity
  , discoveredRuleStage
  , discoveredRuleExpectation
  , discoveredRuleMeaning
  , discoveredRuleAction
  , foldDiscoveredRule
  , type RuleDiscoveryDefect
  , foldRuleDiscoveryDefect
  , type RuleDiscoveryCompilation
  , foldRuleDiscoveryCompilation
  , discoverOperationRules
  , discoverCoreRules
  , discoverProfileRules
  , discoverAdapterRules
  , type RuleDiscovery
  , ruleDiscoveryAuthority
  , discoveredRules
  , type RuleExplanationRequestDefect
  , foldRuleExplanationRequestDefect
  , type RuleExplanation
  , explainDiscoveredRule
  , foldRuleExplanation
  , foldRuleDiscovery
  ) where

import Data.List (groupBy, sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.Ord (comparing)
import Data.Text (Text)
import qualified Data.Text as Text
import O2I.ArchiMate.Profile.Resolution
  ( ProfileDescriptor
  , foldProfileDescriptor
  , profileDescriptorContractDigest
  , profileDescriptorReference
  )
import qualified O2I.ArchiMate.Profile.Rule.Catalog as ProfileCatalog
import qualified O2I.ArchiMate.Profile.Rule.Explanation as ProfileRule
import O2I.Core.Contract
  ( coreContractIdentity
  , coreContractIdentityText
  , coreContractSha256
  , coreContractSha256Text
  , coreContractVersion
  , coreContractVersionText
  , coreRuleIdText
  )
import qualified O2I.Core.Rule.Catalog as Core
import O2I.Operation.Adapter
  ( AdapterDescriptor
  , AdapterId
  , AdapterRule
  , CompiledAdapterContract
  , adapterDescriptorId
  , adapterDescriptorVersion
  , adapterIdText
  , adapterRuleAction
  , adapterRuleExpectation
  , adapterRuleId
  , adapterRuleIdText
  , adapterRuleMeaning
  , adapterRuleStage
  , adapterRuleStageText
  , foldAdapterContract
  )
import O2I.Operation.Discovery.Rule.Internal
import qualified O2I.Operation.Rule.Catalog as Operation

-- | Exact authority-owned contract identity.
ruleContractIdentity :: RuleContractBinding -> Text
ruleContractIdentity (RuleContractBinding identity _ _) = identity

-- | Exact authority-owned contract version.
ruleContractVersion :: RuleContractBinding -> Text
ruleContractVersion (RuleContractBinding _ version _) = version

-- | Exact authority-owned contract digest when that authority exposes one.
ruleContractDigest :: RuleContractBinding -> Maybe Text
ruleContractDigest (RuleContractBinding _ _ digest) = digest

-- | Consume every exact contract-binding field.
foldRuleContractBinding ::
     (Text -> Text -> Maybe Text -> result) -> RuleContractBinding -> result
foldRuleContractBinding consume (RuleContractBinding identity version digest) =
  consume identity version digest

-- | Stable authority label for discovery output.
ruleAuthorityText :: RuleAuthority -> Text
ruleAuthorityText authority =
  case authority of
    OperationAuthority _ -> "Operation"
    CoreAuthority _ -> "Core"
    ProfileAuthority reference _ -> "Profile:" <> reference
    AdapterAuthority identifier _ -> "Adapter:" <> adapterIdText identifier

-- | Exact contract binding carried by one authority.
ruleAuthorityBinding :: RuleAuthority -> RuleContractBinding
ruleAuthorityBinding authority =
  case authority of
    OperationAuthority binding -> binding
    CoreAuthority binding -> binding
    ProfileAuthority _ binding -> binding
    AdapterAuthority _ binding -> binding

-- | Consume every closed static authority without exposing constructors.
foldRuleAuthority ::
     (RuleContractBinding -> result)
  -> (RuleContractBinding -> result)
  -> (Text -> RuleContractBinding -> result)
  -> (AdapterId -> RuleContractBinding -> result)
  -> RuleAuthority
  -> result
foldRuleAuthority operation core profile adapter authority =
  case authority of
    OperationAuthority binding -> operation binding
    CoreAuthority binding -> core binding
    ProfileAuthority reference binding -> profile reference binding
    AdapterAuthority identifier binding -> adapter identifier binding

discoveredRuleAuthority :: DiscoveredRule -> RuleAuthority
discoveredRuleAuthority (DiscoveredRule authority _ _ _ _ _) = authority

discoveredRuleIdentity :: DiscoveredRule -> Text
discoveredRuleIdentity (DiscoveredRule _ identity _ _ _ _) = identity

discoveredRuleStage :: DiscoveredRule -> Text
discoveredRuleStage (DiscoveredRule _ _ stage _ _ _) = stage

discoveredRuleExpectation :: DiscoveredRule -> Text
discoveredRuleExpectation (DiscoveredRule _ _ _ expectation _ _) = expectation

discoveredRuleMeaning :: DiscoveredRule -> Text
discoveredRuleMeaning (DiscoveredRule _ _ _ _ meaning _) = meaning

discoveredRuleAction :: DiscoveredRule -> Text
discoveredRuleAction (DiscoveredRule _ _ _ _ _ action) = action

-- | Consume one complete discovery row in canonical field order.
foldDiscoveredRule ::
     (RuleAuthority -> Text -> Text -> Text -> Text -> Text -> result)
  -> DiscoveredRule
  -> result
foldDiscoveredRule consume (DiscoveredRule authority identity stage expectation meaning action) =
  consume authority identity stage expectation meaning action

-- | Consume every authority-local rule-discovery defect.
foldRuleDiscoveryDefect ::
     (Text -> Text -> Text -> Text -> result)
  -> (Text -> Text -> result)
  -> RuleDiscoveryDefect
  -> result
foldRuleDiscoveryDefect profileMismatch duplicate defect =
  case defect of
    ProfileRuleCatalogMismatch expectedReference actualReference expectedDigest actualDigest ->
      profileMismatch
        expectedReference
        actualReference
        expectedDigest
        actualDigest
    DuplicateRuleIdentity authority identity -> duplicate authority identity

-- | Consume static defects or one complete authority inventory.
foldRuleDiscoveryCompilation ::
     (NonEmpty RuleDiscoveryDefect -> result)
  -> (RuleDiscovery -> result)
  -> RuleDiscoveryCompilation
  -> result
foldRuleDiscoveryCompilation failed compiled outcome =
  case outcome of
    RuleDiscoveryCompilationFailed defects -> failed defects
    RuleDiscoveryCompiled discovery -> compiled discovery

-- | Discover the complete Operation-owned bootstrap inventory without a model.
discoverOperationRules :: RuleDiscoveryCompilation
discoverOperationRules = compileDiscovery operationAuthority operationRows

-- | Discover the complete Core-owned inventory without a model.
discoverCoreRules :: RuleDiscoveryCompilation
discoverCoreRules = compileDiscovery coreAuthority coreRows

-- | Discover the Profile inventory for one exact immutable descriptor.
--
-- The descriptor must bind the authority-owned catalog by both canonical
-- reference and contract digest. No model marker is resolved here.
discoverProfileRules :: ProfileDescriptor -> RuleDiscoveryCompilation
discoverProfileRules descriptor
  | expectedReference /= actualReference || expectedDigest /= actualDigest =
    RuleDiscoveryCompilationFailed
      (ProfileRuleCatalogMismatch
         expectedReference
         actualReference
         expectedDigest
         actualDigest
         :| [])
  | otherwise = compileDiscovery authority (profileRows authority)
  where
    expectedReference = profileDescriptorReference descriptor
    expectedDigest = profileDescriptorContractDigest descriptor
    actualReference =
      ProfileCatalog.selectedProfileRuleCatalogProfileReference
        ProfileCatalog.selectedProfileRuleCatalog
    actualDigest =
      ProfileCatalog.selectedProfileRuleCatalogContractDigest
        ProfileCatalog.selectedProfileRuleCatalog
    authority = profileAuthority descriptor

-- | Discover one complete immutable Adapter-owned rule inventory.
--
-- The compiled contract exposes neither recognition nor decode behavior.
-- Its descriptor supplies exact authority identity and contract version; the
-- authority currently exposes no contract digest.
discoverAdapterRules :: CompiledAdapterContract -> RuleDiscoveryCompilation
discoverAdapterRules =
  foldAdapterContract $ \descriptor rules ->
    let authority = adapterAuthority descriptor
     in compileDiscovery authority (adapterRows authority rules)

-- | Exact authority selected for this discovery inventory.
ruleDiscoveryAuthority :: RuleDiscovery -> RuleAuthority
ruleDiscoveryAuthority (RuleDiscovery authority _ _) = authority

-- | Enumerate every rule in canonical exact-identity order.
discoveredRules :: RuleDiscovery -> NonEmpty DiscoveredRule
discoveredRules (RuleDiscovery _ rows _) = rows

-- | Consume every invalid exact Rule-explanation request.
foldRuleExplanationRequestDefect ::
     result -> RuleExplanationRequestDefect -> result
foldRuleExplanationRequestDefect empty defect =
  case defect of
    EmptyRuleExplanationRequest -> empty

-- | Explain one exact non-empty rule identity in @O(log R)@ without
-- normalization.
--
-- Lookup is explanation only and never dispatches evaluator behavior. A miss
-- remains an explicit result carrying the selected authority and exact request.
explainDiscoveredRule ::
     Text
  -> RuleDiscovery
  -> Either RuleExplanationRequestDefect RuleExplanation
explainDiscoveredRule identity (RuleDiscovery authority _ byIdentity) =
  if Text.null identity
    then Left EmptyRuleExplanationRequest
    else Right
           (case Map.lookup identity byIdentity of
              Just rule -> RuleExplanationFound authority identity rule
              Nothing -> RuleExplanationNotFound authority identity)

-- | Consume either a found rule or one exact unresolved explanation request.
foldRuleExplanation ::
     (RuleAuthority -> Text -> DiscoveredRule -> result)
  -> (RuleAuthority -> Text -> result)
  -> RuleExplanation
  -> result
foldRuleExplanation found notFound explanation =
  case explanation of
    RuleExplanationFound authority identity rule ->
      found authority identity rule
    RuleExplanationNotFound authority identity -> notFound authority identity

-- | Consume the chosen authority and its complete canonical inventory.
foldRuleDiscovery ::
     (RuleAuthority -> NonEmpty DiscoveredRule -> result)
  -> RuleDiscovery
  -> result
foldRuleDiscovery consume (RuleDiscovery authority rows _) =
  consume authority rows

compileDiscovery ::
     RuleAuthority -> NonEmpty DiscoveredRule -> RuleDiscoveryCompilation
compileDiscovery authority supplied =
  case NonEmpty.nonEmpty duplicateDefects of
    Just defects -> RuleDiscoveryCompilationFailed defects
    Nothing ->
      RuleDiscoveryCompiled
        (RuleDiscovery
           authority
           canonical
           (Map.fromList
              [ (discoveredRuleIdentity rule, rule)
              | rule <- NonEmpty.toList canonical
              ]))
  where
    canonical = NonEmpty.sortBy (comparing discoveredRuleIdentity) supplied
    duplicateDefects =
      map
        (DuplicateRuleIdentity (ruleAuthorityText authority))
        (duplicateValues
           (fmap discoveredRuleIdentity (NonEmpty.toList canonical)))

operationAuthority :: RuleAuthority
operationAuthority =
  OperationAuthority
    (RuleContractBinding
       (Operation.operationRuleCatalogContractIdentity catalog)
       (Operation.operationRuleCatalogContractVersion catalog)
       (Just (Operation.operationRuleCatalogContractDigest catalog)))
  where
    catalog = Operation.operationRuleCatalog

operationRows :: NonEmpty DiscoveredRule
operationRows = fmap materialize (Operation.operationRuleCatalogEntries catalog)
  where
    catalog = Operation.operationRuleCatalog
    materialize rule =
      DiscoveredRule
        operationAuthority
        (Operation.operationRuleIdText (Operation.operationRuleIdentity rule))
        (Operation.operationRuleStageText (Operation.operationRuleStage rule))
        (Operation.operationRuleExpectation rule)
        (Operation.operationRuleMeaning rule)
        (Operation.operationRuleAction rule)

coreAuthority :: RuleAuthority
coreAuthority =
  CoreAuthority
    (RuleContractBinding
       (coreContractIdentityText coreContractIdentity)
       (coreContractVersionText coreContractVersion)
       (Just (coreContractSha256Text coreContractSha256)))

coreRows :: NonEmpty DiscoveredRule
coreRows = fmap materialize (Core.coreRuleCatalogEntries Core.coreRuleCatalog)
  where
    materialize rule =
      DiscoveredRule
        coreAuthority
        (coreRuleIdText (Core.coreRuleIdentity rule))
        (Core.coreRuleStageText (Core.coreRuleStage rule))
        (Core.coreRuleExpectation rule)
        (Core.coreRuleMeaning rule)
        (Core.coreRuleAction rule)

profileAuthority :: ProfileDescriptor -> RuleAuthority
profileAuthority descriptor = foldProfileDescriptor materialize descriptor
  where
    materialize identity token version _ _ digest =
      ProfileAuthority
        (identity <> "@" <> token)
        (RuleContractBinding identity version (Just digest))

profileRows :: RuleAuthority -> NonEmpty DiscoveredRule
profileRows authority =
  fmap
    materialize
    (ProfileCatalog.selectedProfileRuleCatalogEntries
       ProfileCatalog.selectedProfileRuleCatalog)
  where
    materialize rule =
      DiscoveredRule
        authority
        (ProfileRule.profileRuleIdText (ProfileRule.profileRuleId rule))
        (ProfileRule.profileRuleStageText (ProfileRule.profileRuleStage rule))
        (ProfileRule.profileRuleExpectation rule)
        (ProfileRule.profileRuleMeaning rule)
        (ProfileRule.profileRuleAction rule)

adapterAuthority :: AdapterDescriptor -> RuleAuthority
adapterAuthority descriptor =
  AdapterAuthority
    identifier
    (RuleContractBinding
       (adapterIdText identifier)
       (adapterDescriptorVersion descriptor)
       Nothing)
  where
    identifier = adapterDescriptorId descriptor

adapterRows :: RuleAuthority -> NonEmpty AdapterRule -> NonEmpty DiscoveredRule
adapterRows authority = fmap materialize
  where
    materialize rule =
      DiscoveredRule
        authority
        (adapterRuleIdText (adapterRuleId rule))
        (adapterRuleStageText (adapterRuleStage rule))
        (adapterRuleExpectation rule)
        (adapterRuleMeaning rule)
        (adapterRuleAction rule)

duplicateValues :: Ord value => [value] -> [value]
duplicateValues = mapMaybe repeated . groupBy (==) . sort
  where
    repeated (first:_:_) = Just first
    repeated _ = Nothing
