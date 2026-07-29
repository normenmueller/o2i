module RelationalDisconnectedPlan where

import O2I.Validation.Relational.Types

invalidDisconnectedPlan :: CompiledPlan row
invalidDisconnectedPlan = CompiledPlan undefined undefined undefined
