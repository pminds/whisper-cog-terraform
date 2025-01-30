output "load_balancer_dns" {
  value = aws_lb.models_loadbalancer.dns_name
}

#output "api_url" {
#  value = "${aws_api_gateway_deployment.deployment.invoke_url}"
#}
#
#output "api_key" {
#  value = aws_api_gateway_api_key.api_key.value
#  sensitive = true
#}
