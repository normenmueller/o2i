{-# LANGUAGE TemplateHaskell #-}

-- | Compile-time assertions for the public Operation API.
module ApiContractTH
  ( assertAbstractTypes
  , assertOrdinaryFunctions
  ) where

import Control.Monad (unless)
import Language.Haskell.TH
  ( Con(..)
  , Dec(..)
  , Info(..)
  , Name
  , Q
  , lookupTypeName
  , lookupValueName
  , nameBase
  , reify
  )

assertAbstractTypes :: [String] -> Q [Dec]
assertAbstractTypes names = do
  inspections <-
    traverse
      (\name -> do
         typeName <- lookupTypeName name
         case typeName of
           Nothing -> pure (name, Nothing, [], [])
           Just value -> do
             information <- reify value
             let constructors = constructorNames information
             visible <-
               traverse
                 (lookupValueName . publicConstructorName name)
                 constructors
             pure (name, Just value, constructors, visible))
      names
  let missingTypes = [name | (name, Nothing, _, _) <- inspections]
      uninspectableTypes = [name | (name, Just _, [], _) <- inspections]
      visibleConstructors =
        [ (name, constructor)
        | (name, Just _, constructors, visible) <- inspections
        , (constructor, Just _) <- zip constructors visible
        ]
  unless
    (null missingTypes)
    (fail ("opaque API types are missing: " ++ show missingTypes))
  unless
    (null uninspectableTypes)
    (fail
       ("opaque API constructors could not be inspected: "
          ++ show uninspectableTypes))
  unless
    (null visibleConstructors)
    (fail
       ("opaque API constructors are visible: "
          ++ show
               [ (typeName, nameBase constructor)
               | (typeName, constructor) <- visibleConstructors
               ]))
  pure []

constructorNames :: Info -> [Name]
constructorNames information =
  case information of
    TyConI declaration ->
      case declaration of
        DataD _ _ _ _ constructors _ -> concatMap conNames constructors
        NewtypeD _ _ _ _ constructor _ -> conNames constructor
        _ -> []
    _ -> []

conNames :: Con -> [Name]
conNames constructor =
  case constructor of
    NormalC name _ -> [name]
    RecC name _ -> [name]
    InfixC _ name _ -> [name]
    ForallC _ _ value -> conNames value
    GadtC names _ _ -> names
    RecGadtC names _ _ -> names

publicConstructorName :: String -> Name -> String
publicConstructorName typeName constructor =
  publicQualifier typeName ++ nameBase constructor

publicQualifier :: String -> String
publicQualifier = reverse . dropWhile (/= '.') . reverse

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
