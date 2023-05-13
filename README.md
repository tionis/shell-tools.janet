# My Shell-tools
## External Dependecies (besides janet/jpm)
- [ctpv](https://github.com/NikitaIvanovV/ctpv)(only for some fzf previews)
    - [chafa](https://github.com/hpjansson/chafa)
    - ueberzug
- [vis](https://github.com/martanne/vis)(for some clipboard integrations)
- [fzf](https://github.com/junegunn/fzf) (for multiple shell script and optional support in jeff)
- GNU core utils (for shell scripts)
- bc (for ffm) (to be replaced in future iteration)

## Project Structure
### bin
Contains a few simple shell scripts. I aim to keep them compatible with windows git bash and busybox based systems/shells.

### shell
Janet shell utilities as library

### shell/cli
Utitilies using shell libraries, backaged as CLI apps
