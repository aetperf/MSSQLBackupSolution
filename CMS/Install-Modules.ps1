Install-Module Logging
Install-Module dbatools

import-module dbatools
import-module Logging

Set-DbatoolsInsecureConnection -Scope SystemDefault