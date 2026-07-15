{-# LANGUAGE GADTs #-}
{-# LANGUAGE TemplateHaskell #-}

module Main
  ( main
  ) where

import Control.Monad (unless)
import Language.Haskell.TH
  ( Info(VarI)
  , lookupTypeName
  , lookupValueName
  , nameBase
  , reify
  )
import O2I.Language

$(do
    specType <- lookupTypeName "InterpretationSpec"
    someType <- lookupTypeName "SomeInterpretation"
    specConstructor <- lookupValueName "InterpretationSpec"
    someConstructor <- lookupValueName "SomeInterpretation"
    case (specType, someType, specConstructor, someConstructor) of
      (Just _, Just _, Nothing, Nothing) -> pure []
      _ -> fail "interpretation metadata types must be public and abstract")

$(do
    let projections =
          [ 'interpretationCode
          , 'interpretationContext
          , 'interpretationPrimitive
          , 'interpretationWitness
          ]
        isNotOrdinaryFunction (_, VarI _ _ Nothing) = False
        isNotOrdinaryFunction _ = True
    projectionInfo <-
      traverse (\name -> fmap ((,) name) (reify name)) projections
    case filter isNotOrdinaryFunction projectionInfo of
      [] -> pure []
      invalid ->
        fail
          ("interpretation projections must not be record selectors: "
             ++ show (map (nameBase . fst) invalid)))

main :: IO ()
main = do
  let spec = interpretationSpec PrincipleInEthos
  assert
    "interpretation code projection"
    (interpretationCode spec == PrincipleInEthosCode)
  assert
    "interpretation Context projection"
    (contextValue (interpretationContext spec) == Ethos)
  assert
    "interpretation Primitive projection"
    (primitiveValue (interpretationPrimitive spec) == Principle)
  case interpretationWitness spec of
    PrincipleInEthos -> pure ()
  assert
    "complete interpretation registry"
    (map interpretationCodeOf allInterpretations == [minBound .. maxBound])
  case lookupInterpretation Ethos Principle of
    Just interpretation ->
      assert
        "interpretation lookup identity"
        (interpretationIdentity interpretation == (Ethos, Principle))
    Nothing -> fail "canonical interpretation was not found"

assert :: String -> Bool -> IO ()
assert message condition = unless condition (fail message)
