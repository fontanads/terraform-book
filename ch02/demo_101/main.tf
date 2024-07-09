provider "aws" {
    region = "eu-west-1"
}

resource "aws_instance" "example" {
    ami = "ami-0887c7673564b061c"
    instance_type = "t2.micro"

    tags = {
        Name = "terraform-example-ch02-101"
    }
}

