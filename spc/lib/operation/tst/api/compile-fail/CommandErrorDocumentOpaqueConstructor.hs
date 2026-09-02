module CommandErrorDocumentOpaqueConstructor where

import O2I.Operation.Command.Error.Machine

invalid :: value -> CommandErrorDocument
invalid = CommandErrorDocument
