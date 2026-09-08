{-# LANGUAGE OverloadedStrings #-}

-- | Compile-only proof that the CLI's static Profile-rule selection needs
-- only its private public-Operation/AMX composition surface.
module PublicComposition
  ( selectedProfileRules
  ) where

import O2I.Cli.Options (CliError)
import O2I.Cli.Static (staticComposition, staticProfileRules)
import O2I.Operation.Discovery.Rule (RuleDiscoveryCompilation)

selectedProfileRules :: Either CliError RuleDiscoveryCompilation
selectedProfileRules =
  staticComposition >>= staticProfileRules "o2i.archimate-profile@0.3"
