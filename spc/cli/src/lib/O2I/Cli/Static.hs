{-# LANGUAGE OverloadedStrings #-}

-- | Closed composition root for the executable's immutable contracts.
module O2I.Cli.Static
  ( StaticComposition
  , staticComposition
  , staticAdapters
  , staticProfiles
  , lookupStaticAdapterContract
  , staticProfileRules
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Adapter.AMX (amxAdapter)
import O2I.Cli.Options (CliError(..))
import O2I.Operation.Adapter
  ( AdapterCollection
  , AdapterId
  , CompiledAdapterContract
  , lookupAdapterContract
  )
import O2I.Operation.Adapter.Authoring (compileAdapterCollection)
import O2I.Operation.Discovery.Rule
  ( RuleDiscoveryCompilation
  , discoverProfileRules
  , foldRuleAuthority
  , foldRuleDiscoveryCompilation
  , ruleDiscoveryAuthority
  )
import O2I.Operation.Profile
  ( ProfileInventory
  , compiledProfileInventory
  , foldProfileInventoryCompilation
  , profileInventoryDescriptors
  )

-- | Validated static Adapter and Profile collections shared by all commands.
data StaticComposition = StaticComposition
  { staticAdapters :: AdapterCollection
  , staticProfiles :: ProfileInventory
  }

-- | Compile every admitted static contribution before processing model input.
staticComposition :: Either CliError StaticComposition
staticComposition = do
  adapter <-
    mapLeft
      (const (internal "The compiled AMX adapter definition is invalid."))
      amxAdapter
  adapters <-
    mapLeft
      (const (internal "The static adapter collection is invalid."))
      (compileAdapterCollection (adapter NonEmpty.:| []))
  profiles <-
    foldProfileInventoryCompilation
      (const (Left (internal "The static Profile inventory is invalid.")))
      Right
      compiledProfileInventory
  pure (StaticComposition adapters profiles)

-- | Resolve one exact compiled Adapter contract without executing it.
lookupStaticAdapterContract ::
     AdapterId -> StaticComposition -> Maybe CompiledAdapterContract
lookupStaticAdapterContract identifier =
  lookupAdapterContract identifier . staticAdapters

-- | Select the rule inventory of one exact Profile reference without exposing
-- the Profile package's descriptor type at the executable boundary.
staticProfileRules ::
     Text -> StaticComposition -> Either CliError RuleDiscoveryCompilation
staticProfileRules reference composition = do
  classified <- traverse classify compilations
  case [compilation | (compilation, True) <- classified] of
    [selected] -> Right selected
    [] -> Left (CliError "cli.argument.profile-ref" "Unknown Profile reference.")
    _ -> Left (internal "The static Profile rule authorities are ambiguous.")
  where
    compilations =
      NonEmpty.toList
        (fmap
           discoverProfileRules
           (profileInventoryDescriptors (staticProfiles composition)))
    classify compilation =
      foldRuleDiscoveryCompilation
        (const
           (Left
              (internal "A static Profile rule inventory is invalid.")))
        (\discovery ->
           Right
             ( compilation
             , foldRuleAuthority
                 (const False)
                 (const False)
                 (\candidate _ -> candidate == reference)
                 (\_ _ -> False)
                 (ruleDiscoveryAuthority discovery)
             ))
        compilation

internal :: Text -> CliError
internal = CliError "cli.internal.static-composition"

mapLeft :: (left -> mapped) -> Either left value -> Either mapped value
mapLeft transform outcome =
  case outcome of
    Left failure -> Left (transform failure)
    Right value -> Right value
