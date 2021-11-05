#/bin/bash

#### Constants

ORG=<org-link>
PROJECT=<project-link>
REPOTOKEN=<ADO-repo-token>

#### END Constants

az repos show --r $1 --organization $ORG --project $PROJECT

## -- Start the group section -- ##
## -- If group is present grab token... IF group does not exist - create new and grab token -- ##
groupname="'$2'"
echo $groupname
grouptoken=$(az devops security group list --project $PROJECT --output tsv --organization $ORG --query "graphGroups[?displayName==$groupname].{descriptor:descriptor}") || true

groupnaming="$2"
echo $groupnaming

if [ -z "$grouptoken" ] 
then
    echo "ADO Group not present. Creating...."
    az devops security group create --name "$groupnaming" --description 'Update Description' --project $PROJECT --organization $ORG
    echo "New group created... Update the description"
    grouptoken=$(az devops security group list --project $PROJECT --output tsv --organization $ORG --query "graphGroups[?displayName==$groupname].{descriptor:descriptor}")
    echo "New Group:" 
    echo $grouptoken 
else
    echo "Group already exists..." 
    echo $grouptoken

fi

## -- Start the repository section -- ##
## -- If repo is present grab token... IF repo does not exist - exit script -- ##
tokens=()

if [[ "$1" == *"*"* ]] 
then 
    echo "Apply to all repos containing: $1 as the prefix."
    ro=$1
    repoprefix=${ro::-1}
    repoprefix="'$repoprefix'"
    repolist=$(az repos list --organization $ORG --project $PROJECT --query "[? contains(name, "$repoprefix")].name" --output tsv)
    for val in $repolist
    do       
        echo "Get Token for: $val ...."
        token=$(az repos show --repository $val --organization $ORG --project $PROJECT --query id --output tsv)
        echo $token
        tokens+=( "$token" )
    done
    echo ${tokens[*]}

else
    echo "Single Repo"
    
    ## - Get the token for the given repository - ##
    token=$(az repos show --repository $1 --organization $ORG --project $PROJECT --query id --output tsv)
    echo "Token for repo: $1 : $token"
    tokens+=( "$token" )
fi

echo ${tokens[*]}

for val in "${tokens[@]}"
do
    ## - If its a valid repo continue --- Break if NOT - ##
    if [ -z "$val" ]
    then
        echo "Azure DevOps Repository: $1 is invalid...."
        echo "Please enter a valid Repository name."
        exit "Can't continue" 
    else
        echo "Repository is valid... Continue..." 
               
        ## assign group permissions to each repo  ##

        echo $3
        if [ "$3" == "Developer" ]
        then
            echo "Assign Developer Permissions to the following repo" $val "and group" $2
            az devops security permission update --token repoV2/$REPOTOKEN/$val --id 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87 --subject $grouptoken --organization $ORG --allow-bit 16502
        elif [ "$3" == "PRApprover" ]
        then 
            echo "Assign PRApprover Permissions to the following repo" $val "and group" $2
            az devops security permission update --token repoV2/$REPOTOKEN/$val --id 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87 --subject $grouptoken --organization $ORG --allow-bit 30838

        else
            echo "Please Choose Developer or PRApprover... Excess permissions will need approval from manager."
        fi
    fi
done
