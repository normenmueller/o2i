{-# LANGUAGE TemplateHaskell #-}

-- | Compile-time assertions for the public Inspection API.
module ApiContractTH
  ( assertAbstractTypes
  , assertExactArgumentConstructors
  , assertHiddenTypes
  , assertHiddenValues
  , assertOrdinaryFunctions
  ) where

import Control.Monad (unless)
import Data.Foldable (traverse_)
import Language.Haskell.TH
  ( Con(..)
  , Dec(..)
  , Info(..)
  , Name
  , Q
  , Type(..)
  , lookupTypeName
  , lookupValueName
  , nameBase
  , reify
  )

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

-- | Require implementation-only functions to be absent from the client scope.
assertHiddenValues :: [String] -> Q [Dec]
assertHiddenValues names = do
  visible <- traverse lookupValueName names
  unless
    (all (== Nothing) visible)
    (fail ("internal values are visible: " ++ show names))
  pure []

-- | Require implementation-only types to be absent from the client scope.
assertHiddenTypes :: [String] -> Q [Dec]
assertHiddenTypes names = do
  visible <- traverse lookupTypeName names
  unless
    (all (== Nothing) visible)
    (fail ("internal types are visible: " ++ show names))
  pure []

-- | Require projections to be ordinary functions, preventing record updates.
assertOrdinaryFunctions :: [Name] -> Q [Dec]
assertOrdinaryFunctions names = do
  information <- traverse (\name -> fmap ((,) name) (reify name)) names
  let isRecordSelector (_, VarI _ _ (Just _)) = True
      isRecordSelector _ = False
      invalid = filter isRecordSelector information
  unless
    (null invalid)
    (fail
       ("public projections are record selectors: "
          ++ show (map (nameBase . fst) invalid)))
  pure []

-- | Require each function's first argument type to have exactly the named
-- constructors, in declaration order.
assertExactArgumentConstructors :: [(Name, [String])] -> Q [Dec]
assertExactArgumentConstructors contracts = do
  traverse_ assertContract contracts
  pure []
  where
    assertContract (functionName, expected) = do
      functionInfo <- reify functionName
      argumentName <-
        case functionInfo of
          VarI _ functionType _ -> firstArgumentName functionName functionType
          _ -> fail (nameBase functionName ++ " is not a function")
      argumentInfo <- reify argumentName
      actual <-
        case argumentInfo of
          TyConI (DataD _ _ _ _ constructors _) ->
            pure (concatMap constructorNames constructors)
          TyConI (NewtypeD _ _ _ _ constructor _) ->
            pure (constructorNames constructor)
          _ -> fail (nameBase argumentName ++ " is not a data type")
      unless
        (actual == expected)
        (fail
           (nameBase argumentName
              ++ " constructors changed; expected "
              ++ show expected
              ++ ", found "
              ++ show actual))

firstArgumentName :: Name -> Type -> Q Name
firstArgumentName functionName functionType =
  case stripType functionType of
    AppT (AppT ArrowT argumentType) _ ->
      case typeConstructorName argumentType of
        Just argumentName -> pure argumentName
        Nothing -> failUnsupported
    _ -> failUnsupported
  where
    failUnsupported = fail ("unsupported type for " ++ nameBase functionName)

typeConstructorName :: Type -> Maybe Name
typeConstructorName valueType =
  case stripType valueType of
    ConT name -> Just name
    AppT constructor _ -> typeConstructorName constructor
    _ -> Nothing

stripType :: Type -> Type
stripType valueType =
  case valueType of
    ForallT _ _ inner -> stripType inner
    SigT inner _ -> stripType inner
    ParensT inner -> stripType inner
    _ -> valueType

constructorNames :: Con -> [String]
constructorNames constructor =
  case constructor of
    NormalC name _ -> [nameBase name]
    RecC name _ -> [nameBase name]
    InfixC _ name _ -> [nameBase name]
    ForallC _ _ inner -> constructorNames inner
    GadtC names _ _ -> map nameBase names
    RecGadtC names _ _ -> map nameBase names
