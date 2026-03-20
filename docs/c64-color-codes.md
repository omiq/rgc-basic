## C64 Control Characters

| **Code** | | **Keys** | **Description** | **Token** | **VICE** |
| ----- | ----- | ----- | ----- | ----- | ----- |
| 147 |  | SHIFT + CLR/HOME | Clears screen | {clear} / {clr} | shift + home |
| 19 |  | CLR/HOME or CTRL + S | Place cursor in top left corner | {home} | home or Tab + S |
| 29 |  | CRSR ⇐ ⇒ | Cursor one step right | {cursor right}/{crsr right} | right |
| 157 |  | SHIFT + CRSR ⇐ ⇒ | Cursor one step to the left | {cursor left}/{crsr left} | left |
| 17 |  | CRSR ⇑ ⇓ or CTRL + Q | Cursor one position down | {cursor down}/{crsr down} | down or Tab + Q |
| 145 |  | SHIFT + CRSR ⇑ ⇓ | Cursor one position up | {cursor up}/{crsr up} | up |
| 144 |  | CTRL + 1 | Character color black | {blk} / {black} | tab + 1 |
| 5 |  | CTRL + 2 or CTRL + E | Character color white | {wht} / {white} | tab + 2 or Tab + E |
| 28 |  | CTRL + 3 | Character color red | {red} | tab + 3 |
| 159 |  | CTRL + 4 | Character color cyan | {cyn} / {cyan} | tab + 4 |
| 156 |  | CTRL + 5 | Character color purple | {pur} / {purple} | tab + 5 |
| 30 |  | CTRL + 6 | Character color green | {grn} / {green} | tab + 6 |
| 31 |  | CTRL + 7 | Character color blue | {blu} / {blue} | tab + 7 |
| 158 |  | CTRL + 8 | Character color yellow | {yel} / {yellow} | tab + 8 |
| 18 |  | CTRL + 9 or CTRL + R | Reverse ON | {rvs on} | Tab + 9 or Tab + R |
| 146 |  | CTRL + 0 | Reverse OFF | {rvs off} | Tab + 0 |
| 129 |  | C  + 1 | Character color orange | {orange} | CTRL + 1 |
| 149 |  | C= + 2 | Character color brown | {brown} | CTRL + 2 |
| 150 |  | C= + 3 | Character color pink | {pink} / {light-red} | CTRL + 3 |
| 151 |  | C= + 4 | Character color grey 1 / dark grey | {gray1} / {darkgrey} | CTRL + 4 |
| 152 |  | C= + 5 | Character color grey 2 | {grey} | CTRL + 5 |
| 153 |  | C= + 6 | Character color light green | {lightgreen} | CTRL + 6 |
| 154 |  | C= + 7 | Character color light blue | {lightblue} | CTRL + 7 |
| 155 |  | C= + 8 | Character color grey 3 / light grey | {grey3} / {lightgrey} | CTRL + 8 |
| 133 |  | F1 | To use for input with GET | {f1} | f1 |
| 134 |  | F3 | To use for input with GET | {f3} | f3 |
| 135 |  | F5 | To use for input with GET | {f5} | f5 |
| 136 |  | F7 | To use for input with GET | {f7} | f7 |
| 137 |  | SHIFT + F1 | To use for input with GET | {f2} | f2 or shift + f1 |
| 138 |  | SHIFT + F3 | To use for input with GET | {f4} | f4 or shift + f3 |
| 139 |  | SHIFT + F5 | To use for input with GET | {f6} | f6 or shift + f5 |
| 140 |  | SHIFT + F7 | To use for input with GET | {f8} | f8 or shift + f7 |
| 20 |  | INST/DEL or CTRL + T | Erases character left of cursor. | {del} | Backspace |
| 148 |  | SHIFT + INST/DEL | Move characters to the right to insert character. | {inst} | Shift + Backspace |
| 3 |  | RUN/STOP ***** or CTRL + C | Uset by GET query if RUN/STOP has been deactivated | {run/stop} | esc |
| 8 |  | CTRL + H | Deactivates case change SHIFT + C= | {<shift>+<c=> off} / {ctrl+h} | Tab + h |
| 9 |  | CTRL + I | Activates case change SHIFT + C= | {<shift>+<c=> on} / {ctrl+i} | Tab + i |
| 13 |  | RETURN or CTRL + M | Return to enter data (exists no control character) | {return} | enter / Tab + M |
| 14 |  | CTRL + N | Mixed case | {ctrl+n} | tab + n |
| 142 |  | None direct; Control character: Ctrl + 9 + SHIFT + N | Upper case + graphical characters | {ctrl+/} | Control character: tab + 9 + shift + n |
| 32 |  | SPACE | Empty character | {space} | space |
| 141 |  | SHIFT + RETURN Control character: Ctrl + 9 + SHIFT + M | New row | {shift return} | shift + enter Control character: tab + 9 + shift + m |

Some characters in the table above do not perform any action, but are still listed:

- The characters of the Function Keys can be interpreted as freely programmable control characters.
- SPACE character is used as the fill character in insert mode.

## C64 ASCII Conversion Table
```
- ! = 33
- " = 34
- # = 35
- $ = 36
- % = 37
- & = 38
- ' = 39
- ( = 40
- ) = 41
- * = 42
- + = 43
- , = 44
- - = 45
- . = 46
- / = 47

- : = 58
- ; = 59
- < = 60
- = = 61
- > = 62
- ? = 63
- @ = 64

- [ = 91
- £ = 92
- ] = 93

- "arrow up" = 94
- "arrow left" = 95

- F-keys F1 to F8 = 133 to 140

- <RETURN> (Enter) = 13
- <SPACE> (empty key) = 32 or 160 (safety space)
- <SHIFT>+<RETURN> (Enter) = 141

- <CRSR DOWN> (cursor down) = 17
- <CRSR RIGHT> (cursor right) = 29
- <CRSR UP> (cursor up) = 145
- <CRSR LEFT> (cursor left) = 157

- Lowercase and Uppercase character set = 14
- Uppercase and PETSCII symbols = 142

- <RVS ON>, Reverse On = 18
- <RVS OFF>, Reverse Off = 146

- <HOME> (cursor to the position left, up) = 19
- <CLR HOME> (clear screen) = 147
- <INST DEL> (Insertmode on) = 20
- <INST DEL> (Insertmode off) = 148

- <WHT>, White = 5
- <RED>, Red = 28
- <GRN>, Green = 30
- <BLU>, Blue = 31
- <BLK>, Black = 144
- <PUR>, Purple = 156
- <YEL>, Yellow = 158
- <CYN>, Cyan = 159
- <orange> = 129
- <brown> = 149
- <lt.red>, light red = 150
- <grey 1>, dark-grey = 152
- <grey 2> = 151
- <lt.green>, light green = 153
- <lt.blue>, light blue, = 154
- <grey 3>, light grey = 155

- The other chars are special characters other than:

Codes 192-233 = Codes 96-127

Codes 224-254 = Codes 160-190

- "Pi" = 126 and 255
```

### Accepted {codes} in this IDE/tokenizer

The tokenizer accepts the following brace substitutions (case-insensitive), including PETCAT/TOK64 and 64er aliases:

- Colors (full): `{black}`, `{white}`, `{red}`, `{cyan}`, `{purple}`, `{green}`, `{blue}`, `{yellow}`, `{orange}`, `{brown}`, `{pink}` (aka `{light-red}`)
- Colors (abbrev): `{blk}`, `{wht}`, `{cyn}`, `{pur}`, `{grn}`, `{blu}`, `{yel}`
- Greys: `{gray1}`/`{darkgrey}`/`{darkgray}`, `{grey}`/`{gray2}`, `{gray3}`/`{lightgrey}`/`{lightgray}`
- Light colors: `{light green}`, `{light blue}`, `{lightgrey}`/`{light gray}`
- Screen/control: `{clear}`/`{clr}`, `{home}`, `{del}`/`{delete}`, `{ins}`/`{inst}`/`{insert}`, `{space}`, `{return}`, `{shift return}`
- Reverse video: `{rvs on}`/`{reverse on}`/`{rvson}`, `{rvs off}`/`{reverse off}`/`{rvsoff}`
- Cursor: `{up}`, `{down}`, `{left}`, `{right}`, and `{cursor up/down/left/right}` or `{crsr up/down/left/right}`
- Function keys: `{f1}` … `{f8}`
- Symbol: `{pi}`

Notes:
- Numeric forms inside braces are also supported, e.g. `{147}`, `{$93}`, `{0x93}`, `{%10010011}`.
- All tokens are case-insensitive: `{Red}`, `{RED}`, and `{red}` are equivalent.



