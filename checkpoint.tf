##########################################
############# Management #################
##########################################
# Deploy CP Management cloudformation template - sk130372
# Run a user-data script to configure the manager with rules 
# and CME setup including the VPN mesh 
#
#To run the script the Management needs to be configured with specific rules
#
#mgmt_cli -r true set access-rule layer Network rule-number 1 action "Accept" track "Log" 
#mgmt_cli -r true add access-layer name "Inline" 
#mgmt_cli -r true set access-rule layer Inline rule-number 1 action "Accept" track "Log" 
#mgmt_cli -r true add access-rule layer Network position 1 name "${var.vpn_community_name} VPN Traffic Rule" vpn.directional.1.from ${var.vpn_community_name} vpn.directional.1.to ${var.vpn_community_name} vpn.directional.2.from ${var.vpn_community_name} vpn.directional.2.to External_clear action "Apply Layer" inline-layer "Inline"
#mgmt_cli -r true add nat-rule package standard position bottom install-on "Policy Targets" original-source All_Internet translated-source All_Internet method hide 
#
#The Management needs to run the CME as per sk157492 and Cloud Management Extension (CME) guide
#
# https://sc1.checkpoint.com/documents/IaaS/WebAdminGuides/EN/CP_CME/Content/Topics-Cloud_Management_Extension_CME/Overview.htm
#
# tgw_menu configuration
#
#Configuration summary:
#----------------------
#AWS Account Controller:
#  Name: aws-tgw
#  Access Key: ***************
#  Secret Key: ********
#  Region: ap-southeast-2
#Security Management Server:
#  Name: aws-tgw
#Configuration Templates:
#  Name:tgw-outbound-template
#    Check Point VPN community: tgw-community
#    One time password (SIC): ********
#    Policy name: Standard
#    Security Gateway version: R80.40
#    Software Blades:
#      Application Control
#      IPS
#      URL Filtering
#      Anti-Bot
#      Anti-Virus
#  Name:tgw-inbound-template
#    One time password (SIC): ********
#    Policy name: Standard
#    Security Gateway version: R80.40
#    Software Blades:
#      Application Control
#      IPS
#      URL Filtering
#      Anti-Bot
#      Anti-Virus
#
#
#
#
##########################################
########### Outbound ASG  ################
##########################################
# East West and Egress traffic
# Deploy CP TGW cloudformation template
resource "aws_cloudformation_stack" "checkpoint_tgw_cloudformation_stack" {
  name = "${var.project_name}-Outbound-ASG"

  parameters = {
    VpcCidr                                  = var.outbound_cidr_vpc
    AvailabilityZones                        = join(", ", data.aws_availability_zones.azs.names)
    NumberOfAZs                              = length(data.aws_availability_zones.azs.names)
    PublicSubnetCidrA                        = cidrsubnet(var.outbound_cidr_vpc, 8, 0)
    PublicSubnetCidrB                        = cidrsubnet(var.outbound_cidr_vpc, 8, 64)
    PublicSubnetCidrC                        = cidrsubnet(var.outbound_cidr_vpc, 8, 128)
    PublicSubnetCidrD                        = cidrsubnet(var.outbound_cidr_vpc, 8, 196)
    ManagementDeploy                         = "No"
    KeyPairName                              = var.key_name
    GatewaysAddresses                        = var.outbound_cidr_vpc
    GatewayManagement                        = "Locally managed"
    GatewaysInstanceType                     = var.outbound_asg_server_size
    GatewaysMinSize                          = "1"
    GatewaysMaxSize                          = "2"
    GatewaysBlades                           = "On"
    GatewaysLicense                          = "${var.cpversion}-BYOL"
    GatewaysPasswordHash                     = var.password_hash
    GatewaysSIC                              = var.sic_key
    ControlGatewayOverPrivateOrPublicAddress = "public"
    ManagementServer                         = var.template_management_server_name
    ConfigurationTemplate                    = var.outbound_configuration_template_name
    Name                                     = "${var.project_name}-CheckPoint-TGW"
    Shell                                    = "/bin/bash"
  }

  template_url       = "https://s3.amazonaws.com/CloudFormationTemplate/checkpoint-tgw-asg-master.yaml"
  capabilities       = ["CAPABILITY_IAM"]
  disable_rollback   = true
  timeout_in_minutes = 50
}
##########################################
########### Inbound ASG  #################
##########################################
# Northbound hub
# Deploy CP ASG cloudformation template
resource "aws_cloudformation_stack" "checkpoint_inbound_asg_cloudformation_stack" {
  name = "${var.project_name}-Inbound-ASG"

  parameters = {
    VPC                                      = aws_vpc.inbound_vpc.id
    Subnets                                  = join(",", aws_subnet.inbound_subnet.*.id)
    ControlGatewayOverPrivateOrPublicAddress = "public"
    MinSize                                  = 1
    MaxSize                                  = 2
    ManagementServer                         = var.template_management_server_name
    ConfigurationTemplate                    = var.inbound_configuration_template_name
    Name                                     = "${var.project_name}-CheckPoint-Inbound-ASG"
    InstanceType                             = var.inbound_asg_server_size
    TargetGroups                             = "${aws_lb_target_group.external_lb_target_group.arn},${aws_lb_target_group.external_lb2_target_group.arn},${aws_lb_target_group.external_lb_tg_app1.arn},${aws_lb_target_group.external_lb_tg_app2.arn}"
    KeyName                                  = var.key_name
    PasswordHash                             = var.password_hash
    SICKey                                   = var.sic_key
    License                                  = "${var.cpversion}-BYOL"
    Shell                                    = "/bin/bash"
  }

  template_url       = "https://s3.amazonaws.com/CloudFormationTemplate/autoscale.json"
  capabilities       = ["CAPABILITY_IAM"]
  disable_rollback   = true
  timeout_in_minutes = 50
}
