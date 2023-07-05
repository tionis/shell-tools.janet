# ToDo
- [ ] rework fzf:* commands to be implemented in janet and use jeff as sole fzf wrapper if at all possible
- [ ] rework commands
    - [ ] fix problem with jpm's declare-executable's tree-shaking cleaning of functions (they are removed from the env as they are not activly referenced and thus are not there when the main commands func runs)
