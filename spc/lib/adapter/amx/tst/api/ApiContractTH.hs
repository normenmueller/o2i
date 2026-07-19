{-# LANGUAGE TemplateHaskell #-}

-- | Compile-time assertions for the deliberately small AMX facade.
module ApiContractTH
  ( assertFacade
  ) where

import Control.Monad (unless)
import Language.Haskell.TH (Dec, Q, lookupTypeName, lookupValueName)

-- | Require the adapter value and reject visibility of internal artifacts.
assertFacade :: [String] -> Q [Dec]
assertFacade hiddenNames = do
  adapter <- lookupValueName "amxAdapter"
  unless (adapter /= Nothing) (fail "amxAdapter is not visible")
  visibleTypes <- traverse lookupTypeName hiddenNames
  visibleValues <- traverse lookupValueName hiddenNames
  unless
    (all (== Nothing) visibleTypes && all (== Nothing) visibleValues)
    (fail "AMX internal constructors leaked through the facade")
  pure []
