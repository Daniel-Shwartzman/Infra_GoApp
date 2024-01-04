data "aws_security_group" "_All_Open" {
    name = "_All_Open"
}


data "aws_key_pair" "jump10" {
  key_name   = "jump10"
}


resource "aws_instance" "Go-App" {
  ami           = "ami-00b8917ae86a424c9"
  instance_type = "t2.micro"

  user_data = file("../scripts/user_data.sh")
  key_name = data.aws_key_pair.jump10.key_name

  tags = {
    Name = var.instance_name
  }

    vpc_security_group_ids = [data.aws_security_group._All_Open.id]  
}