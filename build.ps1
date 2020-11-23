﻿# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

[CmdLetBinding()]
<#
    .SYNOPSIS
        Automation script for running build operations from the command line.

    .DESCRIPTION
        Provides automation of the following tasks:

        * Clean: runs the MSBuild `clean` task
        * Build: runs the MSBuild `build` task with several implicit steps
          (clean, restore, inject version information).
        * UnitTest: executes NUnit tests in projects named `*.UnitTests`, which
          do not connect to a database.
        * IntegrationTest: executes NUnit tests in projects named `*.Test`,
          which connect to a database. Includes drop and deploy operations for
          installing fresh test databases.
        * BuildAndTest: executes the Build, UnitTest, and IntegrationTest
          commands.
        * Package: builds pre-release and release NuGet packages fro the Admin
          App web application.
        * Push: uploads a NuGet package to the NuGet feed.

    .EXAMPLE
        .\build.ps1 build -BuildConfiguration release -Version "2.0.0" -BuildCounter 45

        Overrides the default build configuration (debug) to build in release
        mode with assembly version 2.0.0.45.

    .EXAMPLE
        .\build.ps1 unittest

        Output: test results displayed in the console and saved to XML files.

    .EXAMPLE
        .\build.ps1 integrationtest

        Output: test results displayed in the console and saved to XML files.

    .EXAMPLE
        .\build.ps1 package -Version "2.0.0" -BuildCounter 45

        Output: two NuGet packages, with version 2.0.0 and 2.0.0-pre0045.

    .EXAMPLE
        .\build.ps1 push -NuGetApiKey $env:nuget_key
#>
param(
    # Command to execute, defaults to "Build". Options are: Clean, Build,
    # UnitTest / UnitTests, IntegrationTest / IntegrationTests, Package, Push.
    [string]
    [ValidateSet("Clean", "Build", "UnitTest", "IntegrationTest", "Package", "Push",
        "BuildAndTest", "UnitTests", "IntegrationTests")]
    $Command = "Build",

    # Assembly and package version number. The current package number is
    # configured in the build automation tool and passed to this script.
    [string]
    $Version = "0.1.0",

    # Build counter from the automation tool. The .NET assembly version will be
    # composed from <$Version>.<$BuildCounter> (i.e. "0.1.0.1" with the default
    # values). When creating a NuGet package, a pre-release will be created with
    # version <$Version>-pre<$BuildCounter padded to 4 digits> (i.e.
    # "0.1.0-pre0001" with the default values).
    [string]
    $BuildCounter = "1",

    # .NET project build configuration, defaults to "Debug". Options are: Debug, Release.
    [string]
    [ValidateSet("Debug", "Release")]
    $BuildConfiguration = "Debug",

    # Ed-Fi's official NuGet package feed for package download and distribution.
    [string]
    $EdFiNuGetFeed = "https://www.myget.org/F/ed-fi/api/v3/index.json",

    # API key for accessing the feed above. Only required with with the Push
    # command.
    [string]
    $NuGetApiKey,

    # Full path of a package file to push to the NuGet feed. Optional, only
    # applies with the Push command. If not set, then the script looks for a
    # NuGet package corresponding to the provided $Version and $BuildCounter.
    [string]
    $PackageFile
)


$solutionRoot = "$PSScriptRoot/Application"

if ("Release" -eq $BuildConfiguration) {
    $configuration = "Release"
    $testConfiguration = "Release"
} else {
    $configuration = "Debug"
    $testConfiguration = "Debug"
}

$supportedApiVersions = @(
    @{
        OdsPackageName = "EdFi.RestApi.Databases.EFA"
        OdsVersion = "3.4.0"
        Prerelease = $false
    },
    @{
        OdsPackageName = "EdFi.Suite3.RestApi.Databases"
        OdsVersion = "5.0.0"
        Prerelease = $false
    }
)
$maintainers = "Ed-Fi Alliance, LLC and contributors"

Import-Module -Name "$PSScriptRoot/eng/build-helpers.psm1" -Force
Import-Module -Name "$PSScriptRoot/eng/package-manager.psm1" -Force
Import-Module -Name "$PSScriptRoot/eng/database-manager.psm1" -Force
function Clean {
    Invoke-Execute { dotnet clean $solutionRoot -c $configuration --nologo -v minimal }
}
function InitializeNuGet {
    Invoke-Execute { $script:nugetExe = Install-NugetCli }
}

function Restore {
    Invoke-Execute { dotnet restore $solutionRoot --configfile $solutionRoot/NuGet.Config }
}

function AssemblyInfo {
    Invoke-Execute {
        $assembly_version = "$Version.$BuildCounter"

        $copyright = Get-Copyright 2017 $maintainers

        $projects = @(Get-ChildItem -Path Application -Recurse -Filter *.csproj)

        foreach ($project in $projects) {
            $project_name = [System.IO.Path]::GetFileNameWithoutExtension($project)

            $assembly_info_path = "$($project.DirectoryName)\Properties\AssemblyInfo.cs"

            if (Test-Path $assembly_info_path) {
                Invoke-RegenerateFile $assembly_info_path @"
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: ComVisible(false)]
[assembly: AssemblyProduct("$product")]
[assembly: AssemblyTitle("$project_name")]
[assembly: AssemblyVersion("$assembly_version")]
[assembly: AssemblyFileVersion("$assembly_version")]
[assembly: AssemblyInformationalVersion("$Version")]
[assembly: AssemblyCopyright("$copyright")]
[assembly: AssemblyCompany("$maintainers")]
[assembly: AssemblyConfiguration("$configuration")]
"@
            }
        }
    }
}

function Compile {
    Invoke-Execute {
        dotnet build $solutionRoot -c $configuration --nologo --no-restore

        $outputPath = "$solutionRoot/EdFi.Ods.AdminApp.Web/publish"
        $project = "$solutionRoot/EdFi.Ods.AdminApp.Web/"
        dotnet publish $project -c $configuration /p:EnvironmentName=OnPremisesRelease -o $outputPath --no-build
    }
}

function InitializeNUnit {
    Invoke-Execute { $script:nunitExe = Install-NUnitConsole }
}

function RunTests {
    param (
        # File search filter
        [string]
        $Filter
    )

    $testAssemblyPath = "$solutionRoot/$Filter/bin/$testConfiguration/"
    $testAssemblies = Get-ChildItem -Path $testAssemblyPath -Filter "$Filter.dll" -Recurse

    if ($testAssemblies.Length -eq 0) {
        Write-Host "no test assemblies found in $testAssemblyPath"
    }

    $testAssemblies | ForEach-Object {
        Write-Host "Executing: dotnet test $($_)"
        Invoke-Execute { dotnet test $_ }
    }
}

function UnitTests {
    Invoke-Execute { RunTests -Filter "*.UnitTests" }
}

function ResetTestDatabases {
    param (
        [string]
        $OdsPackageName,

        [string]
        $OdsVersion,

        [switch]
        $Prerelease
    )

    Invoke-Execute {
        $arguments = @{
            RestApiPackageVersion = $OdsVersion
            RestApiPackageName = $OdsPackageName
            UseIntegratedSecurity = $true
            RestApiPackagePrerelease = $Prerelease
            NuGetFeed = $EdFiNuGetFeed
        }

        Invoke-PrepareDatabasesForTesting @arguments
    }
}

function IntegrationTests {
    Invoke-Execute { RunTests -Filter "*.Tests" }
}

function RunNuGetPack {
    param (
        [string]
        $PackageVersion
    )

    $nugetSpecPath = "$solutionRoot/EdFi.Ods.AdminApp.Web/publish/EdFi.Ods.AdminApp.Web.nuspec"

    $arguments = @(
        "pack",  $nugetSpecPath,
        "-OutputDirectory", "$PSScriptRoot",
        "-Version", "$PackageVersion",
        "-Properties", "Configuration=$configuration",
        "-NoPackageAnalysis"
    )
    Write-Host "$nugetExe $arguments" -ForegroundColor Magenta
    &$script:nugetExe @arguments
}

function GetPackagePreleaseVersion {
    return "$Version-pre$($BuildCounter.PadLeft(4,'0'))"
}

function BuildPackage {
    RunNuGetPack -PackageVersion $Version
    RunNuGetPack -PackageVersion $(GetPackagePreleaseVersion)   
}

function PushPackage {
    if (-not $NuGetApiKey) {
        throw "Cannot push a NuGet package without providing an API key in the `NuGetApiKey` argument."
    }

    if (-not $PackageFile) {
        $PackageFile = "$PSScriptRoot/EdFi.Ods.AdminApp.Web.$(GetPackagePreleaseVersion).nupkg"
    }

    $arguments = @{
        PackageFile = $PackageFile
        NuGetApiKey = $NuGetApiKey
        NuGetFeed = $EdFiNuGetFeed
    }

    Invoke-Execute { Push-Package @arguments }
}

function Invoke-Build {
    Write-Host "Building Version $Version" -ForegroundColor Cyan

    Invoke-Step { InitializeNuGet }
    Invoke-Step { Clean }
    Invoke-Step { Restore }
    Invoke-Step { AssemblyInfo }
    Invoke-Step { Compile }
}

function Invoke-Clean {
    Invoke-Step { Clean }
}

function Invoke-UnitTests {
    Invoke-Step { InitializeNUnit }
    Invoke-Step { UnitTests }
}

function Invoke-IntegrationTests {
    Invoke-Step { InitializeNuGet }
    Invoke-Step { InitializeNUnit }

    $supportedApiVersions | ForEach-Object {
        Write-Host "Running Integration Tests for ODS Version" $_.OdsVersion -ForegroundColor Cyan

        Invoke-Step {
            $arguments = @{
                OdsVersion = $_.OdsVersion
                OdsPackageName = $_.OdsPackageName
                Prerelease = $_.Prerelease
            }
            ResetTestDatabases @arguments
        }
        Invoke-Step {
            IntegrationTests
        }
    }
}

function Invoke-BuildPackage {
    Invoke-Step { InitializeNuGet }
    Invoke-Step { BuildPackage }
}

function Invoke-PushPackage {
    Invoke-Step { InitializeNuGet }
    Invoke-Step { PushPackage }
}

Invoke-Main {
    dotnet --info

    switch ($Command) {
        Clean { Invoke-Clean }
        Build { Invoke-Build }
        UnitTest { Invoke-UnitTests }
        UnitTests { Invoke-UnitTests }
        IntegrationTest { Invoke-IntegrationTests }
        IntegrationTests { Invoke-IntegrationTests }
        BuildAndTest {
            Invoke-Build
            Invoke-UnitTests
            Invoke-IntegrationTests
        }
        Package { Invoke-BuildPackage }
        Push { Invoke-PushPackage }      
        default { throw "Command '$Command' is not recognized" }
    }
}
