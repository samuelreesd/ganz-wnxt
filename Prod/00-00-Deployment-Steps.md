## Deployment Order for INT (m5.large which has 8Gib Memory)
01. Update /opt/webkinz-next/systems/user-server/machine-specifics.sh on image builder
      ### Set MAX_CONNECTIONS based on Instance type (m5.large)
      MAX_CONNECTIONS=200
02. Update /Users/samuelr/work/ganz/wnxt/Prod/16-1-Prod-Deploy-Step-Scale-In.sh (On Macbook Air)
      TARGET_VALUE=150.0
      SCALEIN_THRESHOLD=70
03. Execute /Users/samuelr/work/ganz/wnxt/Prod/16-1-Prod-Deploy-Step-Scale-In.sh


## Deployment Order for PROD (r5.large which has 16Gib Memory)
01. Update /opt/webkinz-next/systems/user-server/machine-specifics.sh on image builder
      ### Set MAX_CONNECTIONS based on Instance type (m5.large)
      MAX_CONNECTIONS=200
02. Update /Users/samuelr/work/ganz/wnxt/Prod/16-1-Prod-Deploy-Step-Scale-In.sh (On Macbook Air)
      TARGET_VALUE=150.0
      SCALEIN_THRESHOLD=70
03. Execute /Users/samuelr/work/ganz/wnxt/Prod/16-1-Prod-Deploy-Step-Scale-In.sh
