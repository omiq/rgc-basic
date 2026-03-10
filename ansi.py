# Source - https://stackoverflow.com/a/33206814
# Posted by Richard, modified by community. See post 'Timeline' for change history
# Retrieved 2026-03-10, License - CC BY-SA 4.0

#!/usr/bin/env python3

for i in range(30, 37 + 1):
    print("\033[%dm%d\t\t\033[%dm%d" % (i, i, i + 60, i + 60))

print("\\033[39m\\033[49m                 - Reset color")
print("\\033[2K                          - Clear Line")
print("\\033[<L>;<C>H or \\033[<L>;<C>f   - Put the cursor at line L and column C.")
print("\\033[<N>A                        - Move the cursor up N lines")
print("\\033[<N>B                        - Move the cursor down N lines")
print("\\033[<N>C                        - Move the cursor forward N columns")
print("\\033[<N>D                        - Move the cursor backward N columns\n")
print("\\033[2J                          - Clear the screen, move to (0,0)")
print("\\033[K                           - Erase to end of line")
print("\\033[s                           - Save cursor position")
print("\\033[u                           - Restore cursor position\n")
print("\\033[4m                          - Underline on")
print("\\033[24m                         - Underline off\n")
print("\\033[1m                          - Bold on")
print("\\033[21m                         - Bold off")
