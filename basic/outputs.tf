output "example" {
  value = "${data.template_file.example.rendered}"
}

output "example2" {
  value = "${data.template_file.example2.rendered}"
}