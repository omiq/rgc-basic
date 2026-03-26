# After renaming the GitHub repository

If you renamed the repo (e.g. **cbm-basic** → **rgc-basic**), verify the following outside this tree:

**Suggested GitHub description:** *Modern cross-platform BASIC Interpreter with classic syntax compatibility, written in C*

1. **Local git remote**  
   `git remote set-url origin https://github.com/OWNER/NEW-NAME.git`

2. **GitHub repo settings**  
   - Description (example): *Modern cross-platform BASIC Interpreter with classic syntax compatibility, written in C*  
   - Topics: `basic`, `interpreter`, `c`, `commodore`, `petscii`, `wasm`, `retro`, etc.

3. **Forks and CI**  
   Forks keep the old name until owners rename or re-fork. Scheduled workflows run on the new default branch.

4. **External links**  
   Update bookmarks, blog posts, and **`ide.retrogamecoders.com`** static paths if you changed URL slugs (see **`docs/ide-retrogamecoders-canvas-integration.md`**).

5. **npm / crates / other registries**  
   Unrelated to the GitHub rename unless you also publish under a new package name.

This repo’s docs and README assume **`https://github.com/omiq/rgc-basic`**. Change `omiq` if your org or username differs.
