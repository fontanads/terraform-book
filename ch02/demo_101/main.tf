provider "aws" {
    region = "eu-west-1"
}

resource "aws_instance" "example" {
    ami = "ami-0887c7673564b061c"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.my_instance_sec_group.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p 8080 &
                EOF

    user_data_replace_on_change = true  # because user_data typically runs only once during first boot


    tags = {
        Name = "terraform-example-ch02-101"
    }
}

resource "aws_security_group" "my_instance_sec_group" {
    name = "terraform-example-ch02-101"
    
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}