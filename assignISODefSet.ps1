<#
    ####################### --- Assign ISO Policy initiative --- #######################
    Name: Assign ISO Policy initiative Script
    Create: 08/1/2021
    Company: XXXXXXX - Cloud Data Ops
    
    Description
    --  This script will check if the custom ISO Initiative is assigned at the desired 
        scope. It will either update the current assignment or create a new assignment.
    -- Ensure proper naming convention is used if assigning outside the EDP environment. 
        
    ******IMPORTANT INFORMATION******
    Script Configuration
    1. $subscriptionName - enter the desired subscription name for assignment scope.
        a. If management groups are being used - replace the $subscriptionName variable
           with the management scope. 
    2. $policyDefSetName - This variable should NOT change if you are deploying this 
       script for the enterprise data platform. Only change if you have a different def
       set name.  
    
    3. ** If local deployment ** 
       Ensure your directory when running the scripts is set to ....\EDP.Core.Platform
    ######################################################################################
#>

## -- User Variables enter below -- ##

Param(
    [string]$policyId,
    [string]$subscriptionName,
    [string]$policyDefSetName,
    [string]$policyParmFile
)

## -- End User Variables -- ##

## -- Script will set the desired subscription context for your assignment --  ##
Set-AzContext -Subscription $subscriptionName
$scopeId = (Get-AzSubscription -SubscriptionName $subscriptionName).Id
$assignmentName = $policyDefSetName + " - sub- " + $subscriptionName
$policyDefSet = Get-AzPolicySetDefinition -Name $policyDefSetName

$policyAssignment = Get-AzPolicyAssignment -Id "/subscriptions/$scopeId/providers/Microsoft.Authorization/policyAssignments/ISO27001-2013 Audit Only - sub- $subscriptionName" `
    -ErrorAction SilentlyContinue

## -- Get all the databricks resource groups to EXCLUDE in assignment -- ##
$databricksRGs = @()
$databricksRGs = Get-AzResourceGroup -Name "databricks-*"
$databricksRgId = @()
foreach ($rg in $databricksRGs) {
    $databricksRgId += $rg.ResourceId
}

# -- Policy Assignment Below-- # 
## -- Update the current ISO Assignment if databricks RG present. -- ##
## -- Add params to the Set-AzPolicyAssignment if desired -- ##
if ($policyAssignment -and $databricksRGs) {
    Write-Host "Updating the current assignment:" $assignmentName "databricks RG present."
    
    Set-AzPolicyAssignment -Name $assignmentName `
        -PolicyParameter $policyParmFile `
        -NotScope $databricksRgId 
}
## -- Create a new ISO Assignment if databricks RG present -- ##
elseif ($databricksRGs) {
    Write-Host "Creating a new:" $assignmentName "in subscription:" $subscriptionName "and databricks RG present."

    New-AzPolicyAssignment -Name $assignmentName -PolicySetDefinition $policyDefSet `
        -Scope "/subscriptions/$scopeId" -PolicyParameter $policyParmFile `
        -Description "Audit only ISO27001:2013 Policy Set for subscription: $subscriptionName " `
        -NotScope $databricksRgId `
        -EnforcementMode DoNotEnforce 
} 
## -- Create a new ISO Assignment if NO databricks RG present -- ##
elseif ($null -eq $databricksRGs) {
    Write-Host "New Policy assignment with no databricks RG"
    Write-Host `n"Creating a new:" $assignmentName "in subscription:" $subscriptionName "no databricks RG."

    New-AzPolicyAssignment -Name $assignmentName -PolicySetDefinition $policyDefSet `
        -Scope "/subscriptions/$scopeId" -PolicyParameter $policyParmFile `
        -Description "Audit only ISO27001:2013 Policy Set for subscription: $subscriptionName " `
        -EnforcementMode DoNotEnforce 
}
## -- Update ISO Assignment if NO databricks RG present -- ##
else {
    Write-Host "Updating the current assignment:" $assignmentName " present." "No databricks RG."
    
    Set-AzPolicyAssignment -Name $assignmentName `
        -PolicyParameter $policyParmFile `
     
}
