<#
    #################### --- Custom Policy Definition Script--- ####################
    Name: Custom Policy Deployment Script
    Create: xx/15/2021
    Company: XXXXX - Cloud Data Ops

    Description
    --  This script will check for all custom policies under the "customPolicies"
        directory. If a new policy is found it will deploy the policy at the 
        subscription scope. 
    --  This script will also assign a unqiue ID to the policy for referencing in
        the ISO initiative. 

    ******IMPORTANT INFORMATION******
    Script Configuration
    1. Set the desired subscription name for the $subscriptionName variable
    
    --  Ensure the custom policy definitions are under the /iso27001/CustomPolicies 
        directory* - These files must be in JSON format. 
        Ex. "storageBlobDiagPolicy.json"
    
    ###########################################################################
#>

Param(
    [String]$Workfolder,
    [String]$Path
)

## -- Check to see if custom policies are deployed to the subscription -- ##
$guidPolicy = @()

$files = Get-ChildItem -Path $Path -Filter *.json -Verbose
Write-Host "The following custom policy files were found:" + `n$files

foreach($file in $files) {
    Write-Host $file
    $content = Get-Content $file | ConvertFrom-Json -Verbose

    # -- Built in Azure Policies -- #
    if ($content.properties.policyType -eq 'BuiltIn' ) {
        $policyName = $content.name
        
        # Check if the policy exists #
        $policy = Get-AzPolicyDefinition -Name $policyName -ErrorAction:SilentlyContinue
        if($policy){Write-Output "`tThe Builtin policy: $policyName already exists."}
        else{
            $metadata = $content.Properties.metadata | ConvertTo-Json
            New-AzPolicyDefinition -Name $policyName -Metadata $metadata `
                -Policy $file
            
            Write-Output "`n`tThe new Azure Builtin Policy has been created successfully."
        }
    }
    # Code block relates to custom policies - check if there is a name... If not add a UID #
    else {
        $policyName = $content.name
        if($policyName){Write-Output "`tThe Custom Policy Name Identifier: $policyName already exists."}
        else {
            Write-Output "`tCreating a new guid for the custom policy."
            $guid = (New-Guid).Guid
            $content | Add-Member -Type NoteProperty -Name 'name' -Value $guid -Force
            $content | ConvertTo-Json -Depth 10 | Set-Content $file 
            
            Write-Output "`n`tNew GUID was added to the custom policy: $guid"
        }
        # Check if the policy exists #
        $content = Get-Content $file | ConvertFrom-Json
        $policyName = $content.name
        $policy = Get-AzPolicyDefinition -Name $policyName -ErrorAction:SilentlyContinue
        if($policy){Write-Output "`tThe Custom policy: $policyName already exists."}
        else{
            $metadata = $content.Properties.metadata | ConvertTo-Json
            New-AzPolicyDefinition -Name $policyName -Metadata $metadata `
                -Policy $file
            Write-Output "`n`tThe new Azure Custom Policy has been created successfully."

        }    
    }
    $guidPolicy += $policyName
}
