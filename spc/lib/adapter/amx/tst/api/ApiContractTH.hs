{-# LANGUAGE TemplateHaskell #-}

-- | Compile-time assertions for the deliberately small AMX facade.
module ApiContractTH
  ( assertFacade
  , assertNoInstances
  ) where

import Control.Monad (unless)
import Language.Haskell.TH
  ( Dec
  , Name
  , Q
  , Type(ConT)
  , lookupTypeName
  , lookupValueName
  , reifyInstances
  )

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

-- | Reject public structural instances for one deliberately opaque type.
assertNoInstances :: Name -> [Name] -> Q [Dec]
assertNoInstances valueType classes = do
  instances <-
    concat
      <$> traverse
            (\className -> reifyInstances className [ConT valueType])
            classes
  unless
    (null instances)
    (fail "opaque AMX defect exposes structural instances")
  pure []
