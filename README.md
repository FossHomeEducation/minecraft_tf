# minecraft_tf
Terraform to build a simple Minecraft instance


# Terraform Prequistes 
Get AWS keys and place them in 
$HOME/.aws/credentials
(Windows:  %USERPROFILE%/.aws/credentials)

with the format

[default]  
aws_access_key_id = KEY_ID  
aws_secret_access_key = SECRET_KEY  


# Creating Server with Terraform

Follow the default terraform pattern

terraform init  
terraform plan  
terraform apply  

To generate an Ansible inventory for the new server, use:  
terraform output inventory > aws_inventory
