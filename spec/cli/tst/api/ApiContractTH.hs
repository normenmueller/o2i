{-# LANGUAGE TemplateHaskell #-}

module ApiContractTH
  ( assertFacadeContract
  ) where

import Control.Monad (unless, when)
import Data.Maybe (isJust)
import Language.Haskell.TH

assertFacadeContract :: Q Exp
assertFacadeContract = do
  facade <- lookupValueName "O2I.Cli.runCli"
  unless (isJust facade) (fail "O2I.Cli must expose runCli")
  hiddenOptions <- lookupTypeName "O2I.Cli.CliOptions"
  hiddenRenderer <- lookupValueName "O2I.Cli.renderHumanReport"
  when (isJust hiddenOptions) (fail "O2I.Cli must hide CLI option types")
  when (isJust hiddenRenderer) (fail "O2I.Cli must hide output internals")
  [|pure ()|]
