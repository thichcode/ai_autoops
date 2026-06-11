#!/usr/bin/env pwsh
param([string]$Env="prod")
cd (Split-Path -Parent $MyInvocation.MyCommand.Path)
& .\pipeline.ps1 -Action backup -Env $Env
