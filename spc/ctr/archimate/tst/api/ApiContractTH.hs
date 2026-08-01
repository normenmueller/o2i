{-# LANGUAGE TemplateHaskell #-}

-- | Compile-time assertions for the public ArchiMate profile API.
module ApiContractTH
  ( assertAbstractTypes
  , assertOrdinaryFunctions
  ) where

import Control.Monad (unless)
import Language.Haskell.TH
  ( Dec
  , Info(VarI)
  , Name
  , Q
  , lookupTypeName
  , lookupValueName
  , nameBase
  , reify
  )

-- | Require each type name to be visible without a value constructor.
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

-- | Require public projections to be functions rather than record selectors.
assertOrdinaryFunctions :: [Name] -> Q [Dec]
assertOrdinaryFunctions names = do
  information <- traverse (\name -> fmap ((,) name) (reify name)) names
  let isNotOrdinaryFunction (_, VarI _ _ Nothing) = False
      isNotOrdinaryFunction _ = True
      invalid = filter isNotOrdinaryFunction information
  unless
    (null invalid)
    (fail
       ("public projections must not be record selectors: "
          ++ show (map (nameBase . fst) invalid)))
  pure []
