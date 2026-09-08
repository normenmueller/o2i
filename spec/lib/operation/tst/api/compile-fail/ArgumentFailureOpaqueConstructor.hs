{-# LANGUAGE OverloadedStrings #-}

module ArgumentFailureOpaqueConstructor where

import O2I.Operation.Command.Error

invalid :: ArgumentFailure
invalid = ArgumentFailure "cli.argument.input" "missing input"
