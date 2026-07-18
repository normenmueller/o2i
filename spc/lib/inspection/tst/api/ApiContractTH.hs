{-# LANGUAGE TemplateHaskell #-}

-- | Compile-time assertions for the public Inspection API.
module ApiContractTH
  ( assertAbstractTypes
  ) where

import Control.Monad (unless)
import Language.Haskell.TH (Dec, Q, lookupTypeName, lookupValueName)

-- | Require every type name to be visible without its value constructor.
assertAbstractTypes :: [String] -> Q [Dec]
assertAbstractTypes names = do
  visibility <-
    traverse
      (\name -> do
         typeName <- lookupTypeName name
         valueName <- lookupValueName name
         pure (name, typeName, valueName))
      names
  let missingTypes = [name | (name, Nothing, _) <- visibility]
      visibleConstructors = [name | (name, _, Just _) <- visibility]
  unless
    (null missingTypes)
    (fail ("opaque API types are missing: " ++ show missingTypes))
  unless
    (null visibleConstructors)
    (fail ("opaque API constructors are visible: " ++ show visibleConstructors))
  pure []
