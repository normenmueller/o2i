module CommandErrorOpaqueConstructor where

import O2I.Operation.Command.Error

invalid :: ArgumentFailure -> CommandError
invalid = CommandError
