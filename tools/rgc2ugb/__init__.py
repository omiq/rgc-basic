"""rgc-basic → ugBASIC source-to-source transpiler.

Reuses the linter's tokenizer + directives so the same source-walking
infrastructure backs both. The emitter consumes Statement tokens and
produces ugBASIC syntax line-by-line.

MVP scope: portable subset only — PRINT/INPUT/IF/FOR/WHILE/DO/DIM/
SCREEN 0+1/SPRITE LOAD+DRAW/CLS/COLOR/BACKGROUND/INKEY$/KEYDOWN/
SLEEP/VSYNC/REM/END. Anything else is passed through verbatim
(may or may not work on ugBASIC) or rejected with a clear error.
"""

from .emit import transpile
from .cli import main

__all__ = ["transpile", "main"]
