# install-rstudio-daily.sh

This repository hosts a Bash script to install the latest RStudio daily
desktop build for OSX/macOS and Ubuntu(amd64). It previously lived as a
[GitHub Gist](https://gist.github.com/aronatkins/ac3934e08d2961285bef).

To get started, download the latest version of this script, ensure that it is
marked executable, and run it!

```bash
curl -O https://raw.githubusercontent.com/aronatkins/install-rstudio-daily/main/install-rstudio-daily.sh
chmod +x ./install-rstudio-daily.sh
./install-rstudio-daily.sh
```

## Prerequisite

Requires [`jq`](https://stedolan.github.io/jq/).

## RStudio Dailies

The RStudio daily builds are available at <https://dailies.rstudio.com>.

* JSON file enumerating the dailies for all platforms: <https://dailies.rstudio.com/rstudio/latest/index.json>
* JSON file enumerating the stable releases: <https://www.rstudio.com/wp-content/downloads.json>
