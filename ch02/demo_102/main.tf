provider "aws" {
    region = "eu-west-1"
}


variable "server_port" {
    description = "The port the server will use for HTTP requests."
    type = number
    default = 8080
  
}

output "alb_dns_name" {
    value = aws_lb.lb-example.dns_name
    description = "The domain name of the load balancer."
}

resource "aws_launch_configuration" "lc-example" {
    image_id = "ami-0887c7673564b061c"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.my_instance_sec_group.id]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
                EOF

    lifecycle {
      create_before_destroy = true
    }
  

}

resource "aws_security_group" "my_instance_sec_group" {
    name = "terraform-example-ch02-101"
    
    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter {
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}


resource "aws_autoscaling_group" "as-example" {
    launch_configuration = aws_launch_configuration.lc-example.name
    vpc_zone_identifier = data.aws_subnets.default.ids

    target_group_arns = [aws_lb_target_group.tg-example.arn]
    health_check_type = "ELB"

    min_size = 2
    max_size = 10
    tag {
        key = "Name"
        value = "terraform-example-ch02-102-asg"
        propagate_at_launch = true
    }

    
}


resource "aws_lb" "lb-example" {
    name = "terraform-example-ch02-102-lb"
    load_balancer_type = "application"
    subnets = data.aws_subnets.default.ids
    security_groups = [aws_security_group.alb-sec-grp.id]
}

resource "aws_lb_listener" "http-listener" {
    load_balancer_arn = aws_lb.lb-example.arn
    port = 80
    protocol = "HTTP"
    # by default, return a simple 404 page
    default_action {
        type = "fixed-response"
        fixed_response {
            status_code = 404
            message_body = "404 Not Found"
            content_type = "text/plain"
        }
    }
}

resource "aws_security_group" "alb-sec-grp" {
    name = "terraform-example-ch02-102-alb-sec-grp"
    # allow inbound HTTP requests
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow all outbound requests
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_lb_target_group" "tg-example" {
    name = "terraform-example-ch02-102-tg"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id
    
    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener_rule" "asg-listener-rule" {
    listener_arn = aws_lb_listener.http-listener.arn
    priority = 100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.tg-example.arn
    }
}