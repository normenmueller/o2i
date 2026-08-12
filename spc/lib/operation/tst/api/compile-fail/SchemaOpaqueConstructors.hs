{-# LANGUAGE OverloadedStrings #-}

module SchemaOpaqueConstructors where

import O2I.Operation.Schema

invalidVariant :: SchemaVariant
invalidVariant = SchemaVariant "completed"
