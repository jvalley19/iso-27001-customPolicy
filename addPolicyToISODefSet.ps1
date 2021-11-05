<#
    #################### --- Add New Azure Policy Definitions to the ISO Initiative--- ####################
    Name: Add New Policy Definitions to ISO DefSet Script
    Create: 07/19/2021
    Company: XXXXX - Cloud Data Ops
    
    Description
    --  This script will check for any new policies under the "Custompolicies" dir. 
        If the policy init file does not have the ID for new policies it will add a
        JSON object in the script.
    --  ** Enhancement ** will be to add the parameters associated with the new policies
        
    ******IMPORTANT INFORMATION******

    Script Configuration
    1. $guidPolicy will be set in the "customPolicyDeploymentScript.ps1" script
        a. If utilizing DevOps Pipeline variable is set automatically 
        b. If local deployment variable will be set if you utilize the same PS session
    
    #######################################################################################################
#>

Param(
    [String]$guidPolicy,
    [String]$policyFilePath,
    [String]$parameterFilePath
    
)

## -- GuidPolicy variable == Custom policy Ids from the previous step -- ##
$guidPolicy = $guidPolicy.Split(" ")
Write-Host "Current policies to add:" $guidPolicy
$policyFile = Get-ChildItem -Path $policyFilePath -Verbose
$parameterFile = Get-ChildItem -Path $parameterFilePath -Verbose

# - Get the content of the ISO auditPolicy template - #
$content = Get-Content $policyFile | ConvertFrom-Json -Verbose
$paramContent = Get-Content $parameterFile | ConvertFrom-Json 

# - Get the Ids of all Policies in the ISO Audit Policy Initiative - #
$array1 = $content.policyDefinitionId
$newArray=@()
foreach ($id in $array1){
    $newId = $id.Split('/')[-1]
    $newArray +=$newId
}
$removeFromArray = @()
$newArray | ForEach-Object {
    if ($guidPolicy -contains $_) {
        Write-Host "The new policy [$_] is already present in the initiative."
        $removeFromArray += $_

    }
}

# - If there are any new policies from the previous step ALREADY in the file we don't need to add them - #
$newPolicyIdArray = @($guidPolicy | Where-Object {$removeFromArray -notcontains $_})

if ($newPolicyIdArray){ 
# - For each new policy we want to add to our ISO Inititative - #
foreach ($id in $newPolicyIdArray) {
    Write-Output "`tAdding new Policy Definition: $Id to the ISO Initiative."
    $policy = Get-AzPolicyDefinition -Name $id
    # Get the parameters and create a new parameter JSON object #
    $parameters = $policy.Properties.Parameters
    $ht = @{}
    $parameters.psobject.Properties | foreach {$ht[$_.Name] = $_.value}
    $parameterObject = @{}
    $parameterFinal = @{}
    foreach ($item in $ht.Keys) {
        Write-Host "This is" $item
        $value = "value"
        $list = New-Object System.Collections.ArrayList
        $list.Add("[parameters('$($item)')]")
        $parameterObject.Add($value, "$list")
        $parameterFinal.Add($item, $parameterObject)
        $parameterObject = @{}

    }
    $parameterFinal2 = @{}
    foreach ($item2 in $ht.Values) {
        Write-Host "This is" $item2.defaultValue
        $nameParam = $item2.metadata.displayName
        $newParamValue = $item2.defaultValue
        $param = @{"value"=$newParamValue}
        $parameterFinal2.Add($nameParam, $param)
    }

    if ($policy.Properties.PolicyType -eq "BuiltIn") {
        Write-Host "`nThis policy is built in and should be added with 'providers' scope."
        $groupName = New-Object System.Collections.ArrayList
        # - New Data Object for each policy - #
        $data = [ordered]@{"policyDefinitionReferenceId"=$policy.Properties.DisplayName; `
        "policyDefinitionId"="/providers/Microsoft.Authorization/policyDefinitions/$id"; "parameters"=@{}; "groupNames"=$groupName}

        $content += $data

    }
    else {
        Write-Host "`nThis policy is Custom and should be added with 'subscription' scope."
        $groupName = New-Object System.Collections.ArrayList
        # - New Data Object for each policy - #
        $data = [ordered]@{"policyDefinitionReferenceId"=$policy.Properties.DisplayName; `
        "policyDefinitionId"="/subscriptions/$subscription/providers/Microsoft.Authorization/policyDefinitions/$id"; "parameters"=@{}; "groupNames"=$groupName}

        $content += $data
 
    }
   
    # - New parameter object for the assignment file ***FUTURE ENHANCEMENT***- #
    # $paramContent | Add-Member -NotePropertyMembers $parameterFinal2
}
# - Covert the new policy file back to the correct folder - #
$finalContent = $content | ConvertTo-Json -Depth 10 | Set-Content $policyFile
Write-Output "`n`tAll new Policies have been added successfully."

# - Convert the parameter content to the file ***FUTURE ENHANCEMENT***- #
#$paramContent | ConvertTo-Json -Depth 10 | Set-Content $parameterFile
#Write-Host "`n`tAll new parameters are set to the default value."

}
else {
    Write-Host "`n`tAll policies are already added to the ISO Policy JSON File. Please continue"
}
