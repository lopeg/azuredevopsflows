<#
.SYNOPSIS
  Creates child Tasks for new workItem (Bug or UserStory)
.DESCRIPTION
  Script runs in Azure Powershell function V1. Triggered by Azure ServiceBus Queue, which is connected to AzureDevops Servvice hooks.
.INPUTS
  $env: variables come from 'Manage application settings' of Azure Function
.NOTES
  Version:        1.0
  Author:         Yegor Lopatin
  Creation Date:  06/01/2020
  Purpose/Change: Initial script development
  
.EXAMPLE
  Used by Boards Contributors. 
#>

param(
     $ADOOrganisationName = ""
    ,$ADOTeamProjectName  = ""
)

$uri = "https://dev.azure.com/$ADOOrganisationName/$ADOTeamProjectName/_apis/wit/workitems/`$Task?api-version=5.1"

#$mySbMsg default variable in Azure Function ServiceBus queue trigger
$m = Get-Content $mySbMsg -Raw | ConvertFrom-Json

Write-Output "WorkItem ID: $($m.resource.id) : triggered function"

function Create-ChildTask ($taskName) {
    $requestBody = @()
    $requestBody = @(
        @{
             op = "add";
             path = “/fields/System.Title”;
             from = $null;
             value = “$taskName”
        },
        @{
             op = "add";
             path = "/fields/System.AssignedTo";
             from = $null;
             value = "$($m.resource.fields.'System.AssignedTo')"
        },
        @{
             op = "add";
             path = “/fields/System.AreaPath”;
             from = $null;
             value = "$($m.resource.fields.'System.AreaPath')"
        },
        @{
             op = "add";
             path = "/fields/System.IterationPath";
             from = $null;
             value = "$($m.resource.fields.'System.IterationPath')"
        },        
        @{
             op = "add";
             path = “/relations/-”;
             value = @{
                 rel = "System.LinkTypes.Hierarchy-Reverse";
                 url = "https://dev.azure.com/$ADOOrganisationName/$ADOTeamProjectName/_apis/wit/workItems/$($m.resource.id)"     
             }
        }
    )

    $jsonRequestBody = $requestBody | ConvertTo-Json -Depth 10

    Write-Output "WorkItem ID: $($m.resource.id) : creating child `"$taskName`""

    Invoke-WebRequest -Method POST `
                      -ContentType "application/json-patch+json" `
                      -Uri $uri `
                      -Headers @{Authorization = ("Basic {0}" -f $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $env:ADOUserName, $env:ADOUserPAT))))) } `
                      -Body $jsonRequestBody `
                      -UseBasicParsing
}

foreach ($taskName in $($env:ADOchildItemsTitles.split(";"))){
    Create-ChildTask -taskName "$taskName"
}
